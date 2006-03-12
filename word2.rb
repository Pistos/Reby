# Word Extreme

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

# The classic word unscramble game, but enhanced.

# By Pistos
# irc.freenode.net#mathetes

# !word
# !wordsetup
# !wordscore [number of scores to list]

require 'word-ar-defs'

class WordX
    
    VERSION = '2.0.0'
    LAST_MODIFIED = 'March 12, 2006'
    MIN_GAMES_PLAYED_TO_SHOW_SCORE = 0
    DEFAULT_INITIAL_POINT_VALUE = 100
    
    def initialize
        # Change these as you please.
        @say_answer = true
        @MAX_WINS = 4
        @DEFAULT_NUM_ROUNDS = 3
        @TOO_MANY_ROUNDS = 50
        @TOO_MANY_SCORES = 5
        # see also #DEFAULT_WIN_CRITERION
        # End of configuration variables.

        @SCORE_TOTAL_POINTS = 0
        @SCORE_OFFICIAL_POINTS = 1
        @SCORE_TOTAL_WINS = 2
        @SCORE_OFFICIAL_WINS = 3
        @SCORE_OFFICIAL_ROUNDS_PLAYED = 4
        @SCORE_GAMES_WON = 5
        @SCORE_GAMES_PLAYED = 6
        @SCORE_GAMES_TIED = 7
        
        @SHOW_ALL_SCORES = 30

        @channel = nil
        @word = nil
        @game = nil
        @last_winner = nil
        @consecutive_wins = 0
        @ignored_player = nil
        @current_word_index = 0

        @game_parameters = Hash.new
        @game_parameters[ :state ] = :state_none

        @WINBY_POINTS = 0
        @WINBY_WINS = 1
        @WINBYSTR = [ "points", "wins" ]
        @DEFAULT_WIN_CRITERION = @WINBY_POINTS
        
        @num_syllables = Hash.new
        @part_of_speech = Hash.new
        @etymology = Hash.new
        @definition = Hash.new

        @GAME_BINDS = {
            "rounds" => "setup_numRounds",
            "join" => "setup_addPlayer",
            "start" => "startGame",
            "abort" => "setup_abort",
            "players" => "setup_listPlayers",
            "leave" => "setup_removePlayer"
        }

        ActiveRecord::Base.establish_connection(
            :adapter  => "postgresql",
            :host     => "localhost",
            :username => "word",
            :password => "word",
            :database => "word"
        )
        
    end

    # Sends a line to the game channel.
    def put( text, destination = @channel.name )
        $reby.putserv "PRIVMSG #{destination} :#{text}"
    end

    def sendNotice( text, destination = @channel.name )
        $reby.putserv "NOTICE #{destination} :#{text}"
    end

    def oneRound( nick, userhost, handle, channel, text )
        return if @game_parameters[ :state ] != :state_going and game_going?

        @channel = Channel.find_or_create_by_name( channel )
        @game = Game.create( {
            :word_id => @channel.current_word,
        } )
        killTimers
        @def_shown = false
        @initial_point_value = DEFAULT_INITIAL_POINT_VALUE
        @already_guessed = false
        
        # Is a GameSet just starting?
        if @game_parameters[ :state ] == :state_going
            @initial_point_value += (@players.length - 2) * 15
            @game.players = @players
        end
        @point_value = @initial_point_value
        
        @word = Word.find( @channel.current_word )

        # Mix up the letters

        indices = Array.new
        0.upto( @word.word.length ) do |index|
            indices.push index
        end
        mixed_word = ""
        0.upto( @word.word.length ) do
            index = indices.delete_at( rand( indices.length ) )
            mixed_word += @word.word[ index..index ]
        end

        $reby.bind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        
        # Set the timers to reveal the clues

        $reby.utimer( 90, "nobodyGotIt", "$wordx" )
        $reby.utimer( 15, "clue1", "$wordx" )
        $reby.utimer( 20, "clue2", "$wordx" )
        $reby.utimer( 25, "clue3", "$wordx" )
        $reby.utimer( 40, "clue4", "$wordx" )
        $reby.utimer( 55, "clue5", "$wordx" )
        
        put "Unscramble ... #{mixed_word}"
    end

    def printScore( nick, userhost, handle, channel, text )
        put( "Scores:", channel )
        Game.find(
            :all,
            :include => [ :players ],
            :select => [ 'players.nick', 'sum( games.points_awarded ) AS points' ],
            :conditions => 'games.winner = players.id',
            :group => :nick
        ).each do |player|
            put( "#{player.nick}: #{player.points}", channel )
        end
        put( "---", channel )
        Game.find(
            :all,
            :conditions => [ 'winner IS NOT NULL' ],
            :select => 'winner, sum( points_awarded ) AS points',
            :group => :winner
        ).each do |player|
            put( "#{player.winner}: #{player.points}", channel )
        end
        put( "Done.", channel )
    end
    
    def printRating( nick, userhost, handle, channel, text )
        player = Player.find_by_nick( nick )
        if player != nil
            put "#{player.nick}: Your battle rating is: #{player.rating}", channel
        else
            put "#{nick}: You're not a !word warrior!  Play a !wordbattle.", channel
        end
    end
    
    def killTimers
        $reby.utimers.each do |utimer|
            case utimer[ 1 ]
                when /nobodyGotIt|clue\d/
                    $reby.killutimer( utimer[ 2 ] )
            end
        end
    end

    def correctGuess( nick, userhost, handle, channel, text )
        return if @already_guessed
        
        player = Player.find_by_nick( nick )
        return if player.nil?
        
        if ( @game_parameters[ :state ] != :state_going ) and ( player == @ignored_player )
            put( "You've already won #{player.consecutive_wins} times in a row!  Give some other people a chance.", player.nick )
            return
        end
        if ( @game_parameters[ :state ] == :state_going ) and ( not @players.include?( player ) )
            sendNotice( "Since you did not join this game, your guesses are not counted.", player.nick )
            return
        end

        @already_guessed = true

        killTimers

        $reby.unbind( "pub", "-", @word.word, "correctGuess", "$wordx" )

        put "#{player.nick} got it ... #{@word.word} ... for #{@point_value} points."
        
        @game.end_time = Time.now
        @game.winner = player.id
        @game.points_awarded = @point_value

        if player == @last_winner
            player.consecutive_wins += 1
            put "#{player.consecutive_wins} wins in a row!"
            if ( @game_parameters[ :state ] != :state_going ) and ( player.consecutive_wins >= @MAX_WINS )
                @ignored_player = player
                put "#{player.nick}'s guesses will be ignored in the next non-game round."
            end
        else
            player.consecutive_wins = 1
            @ignored_player = nil
        end

        @last_winner = player

        if not @def_shown
            showDefinition
        end

        # Record score.
        
        player.save
        @game.save
        @channel.current_word += 1
        @channel.save
        
        if not nextRound
            @channel = nil
        end
    end

    def nobodyGotIt
        put "No one solved it in time.  The word was #{@word.word}."
        $reby.unbind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        
        @game.end_time = Time.now
        @game.save
        @channel.current_word += 1
        @channel.save
        
        if not nextRound
            @channel = nil
        end
    end

    # Returns true iff doing another round.
    def nextRound
        retval = false
        if @game_parameters[ :state ] == :state_going
            if @game_parameters[ :current_round ] < @game_parameters[ :num_rounds ]
                @game_parameters[ :current_round ] += 1
                oneRound( nil, nil, nil, @channel.name, nil )
                retval = true
            else
                # No more rounds in the game.  GAME OVER.

                put "Game over."

                @game_parameters[ :state ] = :state_none
            end
        end
        return retval
    end

    def clue1
        @point_value = (@initial_point_value * 0.95).to_i
        put "Part of speech: #{ @word.pos }"
    end
    def clue2
        @point_value = (@initial_point_value * 0.90).to_i
        put "Etymology: #{ @word.etymology }"
    end
    def clue3
        @point_value = (@initial_point_value * 0.85).to_i
        put "Number of syllables: #{ @word.num_syllables }"
    end
    def clue4
        @point_value = (@initial_point_value * 0.70).to_i
        put "Starts with: #{ @word.word[ 0..0 ] }"
    end
    def clue5
        @point_value = (@initial_point_value * 0.30).to_i
        showDefinition
    end

    def showDefinition( word = @word )
        put "Definition: #{ @word.definition }"
        @def_shown = true
    end

    def game_going?
        retval = false
        if @game_parameters[ :state ] == :state_setup
            put "A game is currently being setup."
            retval = true
        elsif @game_parameters[ :state ] == :state_going
            put "A game is currently underway in #{@channel.name}."
            retval = true
        elsif @channel != nil
            put "A round is in progress in #{@channel.name}."
            retval = true
        end
        return retval
    end

    def setupGame( nick, userhost, handle, channel, text )
        return if game_going?

        @game_parameters[ :state ] = :state_setup
        @channel = Channel.find_or_create_by_name( channel )
        player = Player.find_or_create_by_nick( nick )
        
        put "Defaults: Rounds: #{@DEFAULT_NUM_ROUNDS}"
        put "Commands: rounds <number>; join; leave; players; abort; start"
        @game_parameters[ :num_rounds ] = @DEFAULT_NUM_ROUNDS
        @game_parameters[ :starter ] = player
        @game_parameters[ :win_criterion ] = @DEFAULT_WIN_CRITERION
        @players = Array.new
        setup_addPlayer( nick, userhost, handle, channel, text )

        @GAME_BINDS.each do |command, method|
            $reby.bind( "pub", "-", command, method, "$wordx" )
        end
    end

    def setup_addPlayer( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        player = Player.find_or_create_by_nick( nick )
        @players << player
        put "#{player.nick} has joined the game."
    end

    def setup_numRounds( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        num_rounds = text.to_i
        if num_rounds < 1
            put "Usage: rounds <positive integer>"
            return
        elsif num_rounds >= @TOO_MANY_ROUNDS
            put "Usage: rounds <some reasonable positive integer>"
            return
        end
        @game_parameters[ :num_rounds ] = num_rounds
        put "Number of rounds set to #{@game_parameters[ :num_rounds ]}."
    end

    def setup_removePlayer( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        player = Player.find_or_create_by_nick( nick )
        if player == @game_parameters[ :starter ]
            sendNotice( "You can't leave the game, you started it.  Try the abort command.", player.nick )
            return
        end
        @players.delete player
        put "#{nick} has withdrawn from the game."
    end

    def setup_listPlayers( nick, userhost, handle, channel, text )
        str = "Players: "
        str << ( @players.collect { |p| p.nick } ).join( ', ' )
        put str
    end

    def isStarter?( player )
        return(
            player == @game_parameters[ :starter ] or
            not $reby.onchan( @game_parameters[ :starter ].nick )
        )
    end

    def unbindSetupBinds
        @GAME_BINDS.each do |command, method|
            $reby.unbind( "pub", "-", command, method, "$wordx" )
        end
    end

    def setup_abort( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        if not isStarter?( Player.find_or_create_by_nick( nick ) )
            put "Only the person who invoked the battle can abort it."
            return
        end

        unbindSetupBinds
        @game_parameters[ :state ] = :state_none
        put "Game aborted."
        @channel = nil
    end

    def startGame( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        if not isStarter?( Player.find_or_create_by_nick( nick ) )
            put "Only the person who invoked the battled can start it."
            return
        end
        if @players.length < 2
            put "At least two players need to be in the game."
            return
        end

        unbindSetupBinds

        @game_parameters[ :current_round ] = 1
        @channel = nil
        @game_parameters[ :state ] = :state_going
        oneRound( nick, userhost, handle, channel, text )
    end
end

$wordx = WordX.new

$reby.bind( "pub", "-", "!word", "oneRound", "$wordx" )
$reby.bind( "pub", "-", "!wordscore", "printScore", "$wordx" )
$reby.bind( "pub", "-", "!wordbattle", "setupGame", "$wordx" )
$reby.bind( "pub", "-", "!wordrating", "printRating", "$wordx" )