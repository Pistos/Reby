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

class Array
    def rank_and_score( player )
        rank = nil
        score = nil
        
        each_with_index do |pair, index|
            if pair[ 0 ] == player
                rank = index + 1
                score = pair[ 1 ]
                break
            end
        end
        
        return rank, score
    end
end

class WordX
    
    VERSION = '2.0.0'
    LAST_MODIFIED = 'March 13, 2006'
    MIN_GAMES_PLAYED_TO_SHOW_SCORE = 0
    DEFAULT_INITIAL_POINT_VALUE = 100
    MAX_SCORES_TO_SHOW = 10
    INCLUDE_PLAYERS_WITH_NO_GAMES = true
    
    def initialize
        # Change these as you please.
        @say_answer = true
        @MAX_WINS = 4
        @DEFAULT_NUM_ROUNDS = 3
        @TOO_MANY_ROUNDS = 50
        # End of configuration variables.

        @channel = nil
        @word = nil
        @game = nil
        @last_winner = nil
        @consecutive_wins = 0
        @ignored_player = nil

        @game_parameters = Hash.new
        @game_parameters[ :state ] = :state_none

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
        return if nick != nil and game_going?

        @channel = Channel.find_or_create_by_name( channel )
        if @game_parameters[ :state ] == :state_starting
            @initial_ranking = ranking
            @initial_titles = Hash.new
            @players.each do |player|
                @initial_titles[ player ] = player.title
            end
            @game_parameters[ :state ] = :state_going
        end
        @word = Word.random

        @game = Game.create( {
            :word_id => @word.id
        } )
        killTimers
        @def_shown = false
        @initial_point_value = DEFAULT_INITIAL_POINT_VALUE
        @already_guessed = false
        
        if @game_parameters[ :state ] == :state_going
            @initial_point_value += (@players.length - 2) * 15
            @game.players = @players
        end
        @point_value = @initial_point_value
        
        # Mix up the letters

        mixed_word = @word.mixed
        while mixed_word == @word.word
            mixed_word = @word.mixed
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
        games = Game.find_by_sql [
            " \
                select games.winner, sum( points_awarded ) AS points \
                from games \
                where \
                    not exists ( \
                        select 1 from games_players where game_id = games.id limit 1 \
                    ) and winner is not null \
                group by winner \
                order by sum( points_awarded ) desc"
        ]
        
        num_to_show, start_rank, end_rank = printing_parameters( text )
        
        num_shown = 0
        index = 0
        games.each do |game|
            index += 1
            next if index < start_rank
            
            player = Player.find( game.winner )
            put( "%2d. %-20s %5d" % [ index, player.nick, game.points ], channel )
            
            num_shown += 1
            break if num_shown >= num_to_show
        end
    end
    
    def printRating( nick, userhost, handle, channel, text )
        if not text.empty?
            player = Player.find_by_nick( text )
            if player.nil?
                put "'#{text}' is not a player.", channel
                return
            end
        else
            player = Player.find_by_nick( nick )
        end
        
        if player != nil
            rank = 'unranked'
            ranking.each_with_index do |pair, index|
                if pair[ 0 ] == player
                    rank = index + 1
                    break
                end
            end
            put "#{player.nick}, #{player.title} - Battle rating: #{player.rating} (Rank: ##{rank}) (#{player.games_played} games)", channel
        else
            put "#{nick}: You're not a !word warrior!  Play a !wordbattle.", channel
        end
    end
    
    # Returns an array of [Player,rating] subarrays.
    def ranking( include_players_with_no_games = false )
        ratings = Hash.new
        Player.find( :all ).each do |player|
            if player.games_played > 0 or include_players_with_no_games
                ratings[ player ] = player.rating
            end
        end
        
        return ratings.sort { |a,b| b[ 1 ] <=> a[ 1 ] }
    end
    
    def printing_parameters( text )
        num_to_show = 5
        start_rank = 1
        case text
            when /^\d+$/
                num_to_show = text.to_i
            when /^(\d+)\s*-\s*(\d+)/
                start_rank = $1.to_i
                end_rank = $2.to_i
                num_to_show = end_rank - start_rank + 1
        end
        if num_to_show > MAX_SCORES_TO_SHOW
            num_to_show = MAX_SCORES_TO_SHOW
        end
        
        return num_to_show, start_rank, end_rank
    end
    
    def printRanking( nick, userhost, handle, channel, text )
        if text =~ /^[^\d -]+$/
            printRating( nick, userhost, handle, channel, text )
            return
        end
        num_to_show, start_rank, end_rank = printing_parameters( text )
        
        num_shown = 0
        index = 0
        r = ranking
        r.each do |player, rating|
            index += 1
            next if index < start_rank
            
            put( "%2d. %-32s %5d" % [ index, "#{player.nick}, #{player.title}", rating ], channel )
            num_shown += 1
            break if num_shown >= num_to_show
        end
        
        put "(#{num_shown} of #{r.size} players shown)" , channel
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
        
        is_going = ( @game_parameters[ :state ] == :state_going )
        
        winner = Player.find_or_create_by_nick( nick )
        return if winner.nil?
        
        if not is_going and ( winner == @ignored_player )
            put( "You've already won #{winner.consecutive_wins} times in a row!  Give some other people a chance.", winner.nick )
            return
        end
        if is_going and ( not @players.include?( winner ) )
            sendNotice( "Since you did not join this game, your guesses are not counted.", winner.nick )
            return
        end

        @already_guessed = true

        killTimers
        $reby.unbind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        
        @game.end_time = Time.now
        @game.winner = winner.id
        
        if is_going
            # Modify award based on comparison of ratings.
            loser_rating = 0
            loser = nil
            @players.each do |player|
                next if player == winner
                player_rating = player.rating
                if player_rating > loser_rating
                    loser_rating = player_rating
                    loser = player
                end
            end
            @point_value *= ( loser_rating.to_f / winner.rating.to_f )
            @point_value = @point_value.to_i
        end

        put "#{winner.nick} got it ... #{@word.word} ... for #{@point_value} points."
        
        @game.points_awarded = @point_value

        if winner == @last_winner
            winner.consecutive_wins += 1
            put "#{winner.consecutive_wins} wins in a row!"
            if ( @game_parameters[ :state ] != :state_going ) and ( winner.consecutive_wins >= @MAX_WINS )
                @ignored_player = winner
                put "#{winner.nick}'s guesses will be ignored in the next non-game round."
            end
        else
            winner.consecutive_wins = 1
            @ignored_player = nil
        end

        @last_winner = winner

        if not @def_shown
            showDefinition
        end

        # Record score.
        
        winner.save
        @game.save
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
                
                @game_parameters[ :state ] = :state_none

                report = ''
                @final_ranking = ranking
                @final_titles = Hash.new
                @players.each do |player|
                    @final_titles[ player ] = player.title
                end
                @game.players.each do |player|
                    initial_rank, initial_score = @initial_ranking.rank_and_score( player )
                    final_rank, final_score     = @final_ranking.rank_and_score( player )
                    initial_title = @initial_titles[ player ]
                    final_title = @final_titles[ player ]
                    if initial_score != nil and final_score > initial_score
                        report << "  #{player.nick} gained #{final_score - initial_score} points"
                        if initial_title != final_title
                            report << " and advanced from #{initial_title} to #{final_title}!"
                        end
                        if initial_rank != nil and final_rank < initial_rank
                            report << " and rose from ##{initial_rank} to ##{final_rank}!"
                        else
                            $reby.log "#{player.nick} init: #{initial_rank} final: #{final_rank}"
                            report << '.'
                        end
                    elsif initial_score != nil and final_score < initial_score
                        report << "  #{player.nick} lost #{initial_score - final_score} points"
                        if initial_title != final_title
                            report << " and got demoted from #{initial_title} to #{final_title}!"
                        end
                        if initial_rank != nil and final_rank > initial_rank
                            report << " and fell from ##{initial_rank} to ##{final_rank}!"
                        else
                            $reby.log "#{player.nick} init: #{initial_rank} final: #{final_rank}"
                            report << '.'
                        end
                    end
                end
                
                put "Game over.#{report}"

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
            put "A battle is currently being setup in #{@channel.name}."
            retval = true
        elsif @game_parameters[ :state ] == :state_going
            put "A battle is currently underway in #{@channel.name}."
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
        @players = Array.new
        setup_addPlayer( nick, userhost, handle, channel, text )

        @GAME_BINDS.each do |command, method|
            $reby.bind( "pub", "-", command, method, "$wordx" )
        end
        
        $reby.utimer( 180, "setup_timeoutGame", "$wordx" )
    end

    def setup_addPlayer( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        player = Player.find_or_create_by_nick( nick )
        if not @players.include? player
            @players << player
            put "#{player.nick} has joined the game."
        else
            put "#{player.nick}: You're already in the game!"
        end
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
        if not( @players.delete player )
            put "#{nick} has withdrawn from the game."
        else
            put "#{nick}: You cannot leave what you have not joined."
        end
    end

    def setup_listPlayers( nick, userhost, handle, channel, text )
        str = "Players: "
        str << ( @players.collect { |p| p.nick } ).join( ', ' )
        put str
    end

    def unbindSetupBinds
        @GAME_BINDS.each do |command, method|
            $reby.unbind( "pub", "-", command, method, "$wordx" )
        end
    end
    
    def setup_timeoutGame
        doAbort
    end
    
    def setup_abort( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        if (
            Player.find_or_create_by_nick( nick ) != @game_parameters[ :starter ] and
            $reby.onchan( @game_parameters[ :starter ].nick )
        )
            put "Only the person who invoked the battle can abort it."
            return
        end

        doAbort
    end
    
    def killTimeoutTimer
        $reby.utimers.each do |utimer|
            case utimer[ 1 ]
                when /setup_timeoutGame/
                    $reby.killutimer( utimer[ 2 ] )
            end
        end
    end
    
    def doAbort
        unbindSetupBinds
        killTimeoutTimer
        @game_parameters[ :state ] = :state_none
        put "Game aborted."
        @channel = nil
    end

    def startGame( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        if Player.find_or_create_by_nick( nick ) != @game_parameters[ :starter ]
            put "Only the person who invoked the battle can start it."
            return
        end
        if @players.length < 2
            put "At least two players need to be in the game."
            return
        end

        unbindSetupBinds
        killTimeoutTimer

        @game_parameters[ :current_round ] = 1
        @channel = nil
        @game_parameters[ :state ] = :state_starting
        oneRound( nick, userhost, handle, channel, text )
    end
end

$wordx = WordX.new

$reby.bind( "pub", "-", "!word", "oneRound", "$wordx" )
$reby.bind( "pub", "-", "!wordbattle", "setupGame", "$wordx" )
$reby.bind( "pub", "-", "!wordscore", "printScore", "$wordx" )
$reby.bind( "pub", "-", "!wordrating", "printRating", "$wordx" )
$reby.bind( "pub", "-", "!wordrank", "printRanking", "$wordx" )
$reby.bind( "pub", "-", "!wordranking", "printRanking", "$wordx" )

