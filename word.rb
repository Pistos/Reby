# Word Extreme

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

# The classic word unscramble game, but enhanced.

# By Pistos
# irc.freenode.net#geobot

# Score file format:
# The first line is an index into the word list (the current word).
# The records are space-separated:
#       Nickname
#       Total Points
#       Official Points
#       Total Wins
#       Official Wins
#       Official number of rounds played
#       Games Won
#       Games Played
#       Games Tied
#
# Where official points are the points scored during official game play,
# which is setup with !wordsetup
#
# !word
# !wordsetup
# !wordscore [number of scores to list]

class WordX
    
    MIN_GAMES_PLAYED_TO_SHOW_SCORE = 0
    
    def initialize
        # Change these as you please.
        @WORDS_FILE = "wordlist.txt"
        @SCORE_FILE = "wordscore.dat"
        @DATA_FILE = "worddata.dat"
        @say_answer = true
        @initial_point_value = 100
        @official_initial_point_value = 300
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
        @point_value = @initial_point_value
        @last_winner = nil
        @consecutive_wins = 0
        @ignored_player = nil
        @current_word_index = 0
        @players = nil

        @game_parameters = Array.new
        @GAME_STATE = 0
        @GAME_NUM_ROUNDS = 1
        @GAME_CURRENT_ROUND = 2
        @GAME_STARTER = 3
        @GAME_WIN_CRITERION = 4
        @game_parameters[ @GAME_STATE ] = @STATE_NONE

        @STATE_NONE = 0
        @STATE_SETUP = 1
        @STATE_GOING = 2

        @PLAYER_PLAYING = 0
        @PLAYER_WINS = 1
        @PLAYER_SCORE = 2

        @WINBY_POINTS = 0
        @WINBY_WINS = 1
        @WINBYSTR = [ "points", "wins" ]
        @DEFAULT_WIN_CRITERION = @WINBY_POINTS
        
        @words = Array.new
        @num_syllables = Hash.new
        @part_of_speech = Hash.new
        @etymology = Hash.new
        @definition = Hash.new
        @score = Hash.new

        @GAME_BINDS = {
            "rounds" => "setup_numRounds",
            "join" => "setup_addPlayer",
            "start" => "startGame",
            "abort" => "setup_abort",
            "players" => "setup_listPlayers",
            "winby" => "setup_winBy",
            "leave" => "setup_removePlayer"
        }

        loadWords
        loadScores
        loadData
    end

    def loadWords
        $reby.log "Loading word list ..."
        num_words = 0
        IO.readlines( @WORDS_FILE ).each do |line|
            tokens = line.strip.split( /_/ )
            word = tokens[ 0 ]
            @words[ num_words ] = word
            num_words += 1
            @num_syllables[ word ] = tokens[ 1 ]
            @part_of_speech[ word ] = tokens[ 2 ]
            @etymology[ word ] = tokens[ 3 ]
            @definition[ word ] = tokens[ 4 ]
        end
        $reby.log "... word list loaded."
    end

    def loadScores
        $reby.log "Loading scores ..."
        if FileTest.exist? @SCORE_FILE
            IO.readlines( @SCORE_FILE ).each do |line|
                tokens = line.strip.split( /\s+/ )
                nick = tokens[ 0 ]
                @score[ nick ] = Array.new
                @score[ nick ][ @SCORE_TOTAL_POINTS ] = tokens[ 1 ].to_i
                @score[ nick ][ @SCORE_OFFICIAL_POINTS ] = tokens[ 2 ].to_i
                @score[ nick ][ @SCORE_TOTAL_WINS ] = tokens[ 3 ].to_i
                @score[ nick ][ @SCORE_OFFICIAL_WINS ] = tokens[ 4 ].to_i
                @score[ nick ][ @SCORE_OFFICIAL_ROUNDS_PLAYED ] = tokens[ 5 ].to_i
                @score[ nick ][ @SCORE_GAMES_WON ] = tokens[ 6 ].to_i
                @score[ nick ][ @SCORE_GAMES_PLAYED ] = tokens[ 7 ].to_i
                @score[ nick ][ @SCORE_GAMES_TIED ] = tokens[ 8 ].to_i
            end
        end
        $reby.log "... scores loaded."
    end

    def loadData
        if FileTest.exist? @DATA_FILE
            lines = IO.readlines( @DATA_FILE )
            @current_word_index = lines[ 0 ].to_i
        end
    end

    def saveScores
        f = File.new( @SCORE_FILE, "w" )
        @score.each do |nick, data|
            f.puts( nick + " " + data.join( " " ) )
        end
        f.close
    end

    def saveData
        f = File.new( @DATA_FILE, "w" )
        f.puts @current_word_index
        f.close
    end

    # Sends a line to the game channel.
    def put( text, destination = @channel )
        $reby.putserv "PRIVMSG #{destination} :#{text}"
    end

    def sendNotice( text, destination = @channel )
        $reby.putserv "NOTICE #{destination} :#{text}"
    end

    def oneRound( nick, userhost, handle, channel, text )
        return if @game_parameters[ @GAME_STATE ] != @STATE_GOING and playing?

        @channel = channel
        killTimers
        @def_shown = false
        @point_value = @initial_point_value
        if @game_parameters[ @GAME_STATE ] == @STATE_GOING
            num_players = 0
            @players.each do |nick, data|
                if data[ @PLAYER_PLAYING ]
                    num_players += 1
                end
            end
            @point_value += (num_players - 2) * 15
        end
        @already_guessed = false

        @word = @words[ @current_word_index ]

        # Mix up the letters

        indices = Array.new
        0.upto( @word.length ) do |index|
            indices.push index
        end
        mixed_word = ""
        0.upto( @word.length ) do
            index = indices.delete_at( rand( indices.length ) )
            mixed_word += @word[ index..index ]
        end

        $reby.bind( "pub", "-", @word, "correctGuess", "$wordx" )

        put "Unscramble ... #{mixed_word}"
        @current_word_index += 1
        if @current_word_index == @words.length
            @current_word_index = 0
        end
        saveData

        # Set the timers to reveal the clues

        $reby.utimer( 90, "nobodyGotIt", "$wordx" )
        $reby.utimer( 15, "clue1", "$wordx" )
        $reby.utimer( 20, "clue2", "$wordx" )
        $reby.utimer( 25, "clue3", "$wordx" )
        $reby.utimer( 40, "clue4", "$wordx" )
        $reby.utimer( 55, "clue5", "$wordx" )
    end

    def printScore( nick, userhost, handle, channel, text )
        num_to_show = text.join.to_i
        num_to_show = @SHOW_ALL_SCORES if num_to_show == 0
        score_array = @score.sort do |a,b|
            awon = a[ 1 ][ @SCORE_GAMES_WON ].to_f
            aplayed = a[ 1 ][ @SCORE_GAMES_PLAYED ].to_f
            bwon = b[ 1 ][ @SCORE_GAMES_WON ].to_f
            bplayed = b[ 1 ][ @SCORE_GAMES_PLAYED ].to_f
            
            if aplayed == 0
                apercent = 0
            else
                apercent = awon / aplayed
            end
            if bplayed == 0
                bpercent = 0
            else
                bpercent = bwon / bplayed
            end
            
            if bpercent == apercent
                atotalwins = a[ 1 ][ @SCORE_TOTAL_WINS ]
                btotalwins = b[ 1 ][ @SCORE_TOTAL_WINS ]
                if btotalwins == atotalwins
                    atotalpoints = a[ 1 ][ @SCORE_TOTAL_POINTS ]
                    btotalpoints = b[ 1 ][ @SCORE_TOTAL_POINTS ]
                    btotalpoints <=> atotalpoints
                else
                    btotalwins <=> atotalwins
                end
            else
                bpercent <=> apercent
            end
            
        end
        score_array = score_array.find_all do |x|
            x[ 1 ][ @SCORE_GAMES_PLAYED ] >= MIN_GAMES_PLAYED_TO_SHOW_SCORE
        end
        longest_nick_length = 0
        score_array.each do |x|
            if x[ 0 ].length > longest_nick_length
                longest_nick_length = x[ 0 ].length
            end
        end
        
        num_that_will_show = [ score_array.length, num_to_show ].min
        
        if num_that_will_show >= @TOO_MANY_SCORES
            recipient = nick
        else
            recipient = channel
        end
        
        put( "Player - total points (official points), total wins (<official wins>/<rounds played>), <games won>/<games tied>/<games played> (win %)", recipient )
        num_shown = 0
        score_array.each do |s|
            nick = s[ 0 ]
            data = s[ 1 ]
            if data[ @SCORE_GAMES_PLAYED ] == 0
                win_percent = 0
            else
                win_percent = ( ( data[ @SCORE_GAMES_WON ].to_f / data[ @SCORE_GAMES_PLAYED ].to_f ) * 100 )
            end
            put( "%-#{longest_nick_length}s %6d (%6d), %4d (%4dW/%4d), %4dW/%4dT/%4d (%3.1f%%)" % [
                    nick,
                    data[ @SCORE_TOTAL_POINTS ],
                    data[ @SCORE_OFFICIAL_POINTS ],
                    data[ @SCORE_TOTAL_WINS ],
                    data[ @SCORE_OFFICIAL_WINS ],
                    data[ @SCORE_OFFICIAL_ROUNDS_PLAYED ],
                    data[ @SCORE_GAMES_WON ],
                    data[ @SCORE_GAMES_TIED ],
                    data[ @SCORE_GAMES_PLAYED ],
                    win_percent
                ],
                recipient
            )
            num_shown += 1
            break if num_shown == num_to_show
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

    def addScoreRecord( nick )
        if nick != nil
            nick = nick.to_s
            @score[ nick ] = Array.new
            @score[ nick ][ @SCORE_TOTAL_POINTS ] = 0
            @score[ nick ][ @SCORE_OFFICIAL_POINTS ] = 0
            @score[ nick ][ @SCORE_TOTAL_WINS ] = 0
            @score[ nick ][ @SCORE_OFFICIAL_WINS ] = 0
            @score[ nick ][ @SCORE_OFFICIAL_ROUNDS_PLAYED ] = 0
            @score[ nick ][ @SCORE_GAMES_WON ] = 0
            @score[ nick ][ @SCORE_GAMES_PLAYED ] = 0
            @score[ nick ][ @SCORE_GAMES_TIED ] = 0
        else
            $reby.log "nick == nil !!"
        end
    end

    def correctGuess( nick, userhost, handle, channel, text )
        #nick = nick.to_s
        return if @already_guessed
        if ( @game_parameters[ @GAME_STATE ] != @STATE_GOING ) and ( nick == @ignored_player )
            put( "You've already won #{@consecutive_wins} times in a row!  Give some other people a chance.", nick )
            return
        end
        if ( @game_parameters[ @GAME_STATE ] == @STATE_GOING ) and ( @players[ nick ] == nil )
            sendNotice( "Since you did not join this game, your guesses are not counted.", nick )
            return
        end

        @already_guessed = true

        killTimers

        $reby.unbind( "pub", "-", @word, "correctGuess", "$wordx" )

        put "#{nick} got it ... #{@word} ... for #{@point_value} points."

        if nick == @last_winner
            @consecutive_wins += 1
            put "#{@consecutive_wins} wins in a row!"
            if ( @game_parameters[ @GAME_STATE ] != @STATE_GOING ) and ( @consecutive_wins >= @MAX_WINS )
                @ignored_player = nick
                put "#{nick}'s guesses will be ignored in the next non-game round."
            end
        else
            @consecutive_wins = 1
            @ignored_player = nil
        end

        @last_winner = nick

        if not @def_shown
            showDefinition
        end

        # Record score.

        if @score[ nick ] == nil
            # New player
            put "First win for #{nick}!"
            addScoreRecord( nick )
        end
        @score[ nick ][ @SCORE_TOTAL_POINTS ] += @point_value
        @score[ nick ][ @SCORE_TOTAL_WINS ] += 1

        if @game_parameters[ @GAME_STATE ] == @STATE_GOING
            @score[ nick ][ @SCORE_OFFICIAL_POINTS ] += @point_value
            @score[ nick ][ @SCORE_OFFICIAL_WINS ] += 1
            @players.each_key do |nick2|
                if @score[ nick2 ] == nil
                    addScoreRecord( nick2 )
                end
                @score[ nick2 ][ @SCORE_OFFICIAL_ROUNDS_PLAYED ] += 1
            end
            @players[ nick ][ @PLAYER_WINS ] += 1
            @players[ nick ][ @PLAYER_SCORE ] += @point_value
        end

        saveScores

        @channel = nil unless nextRound

    end

    def nobodyGotIt
        put "No one solved it in time.  The word was #{@word}."
        $reby.unbind( "pub", "-", @word, "correctGuess", "$wordx" )
        @channel = nil unless nextRound
    end

    # Returns true iff doing another round.
    def nextRound
        retval = false
        if @game_parameters[ @GAME_STATE ] == @STATE_GOING
            if @game_parameters[ @GAME_CURRENT_ROUND ] < @game_parameters[ @GAME_NUM_ROUNDS ]
                @game_parameters[ @GAME_CURRENT_ROUND ] += 1
                oneRound( nil, nil, nil, @channel, nil )
                retval = true
            else
                # No more rounds in the game.  GAME OVER.

                put "Game over."

                @game_parameters[ @GAME_STATE ] = @STATE_NONE

                # Reward game winner.

                high_score = 0
                high_wins = 0
                @players.each_value do |data|
                    if data[ @PLAYER_WINS ] > high_wins
                        high_wins = data[ @PLAYER_WINS ]
                    end
                    if data[ @PLAYER_SCORE ] > high_score
                        high_score = data[ @PLAYER_SCORE ]
                    end
                end

                $reby.log "highs: #{high_wins} #{high_score}"

                winners = Array.new
                @players.each do |nick, data|
                    if @game_parameters[ @GAME_WIN_CRITERION ] == @WINBY_WINS
                        if data[ @PLAYER_WINS ] == high_wins
                            winners.push nick
                            $reby.log "Adding winner: #{nick}"
                        end
                    elsif @game_parameters[ @GAME_WIN_CRITERION ] == @WINBY_POINTS
                        if data[ @PLAYER_SCORE ] == high_score
                            winners.push nick
                            $reby.log "Adding winner: #{nick}"
                        end
                    end
                    if @score[ nick ] == nil
                        # New player
                        addScoreRecord( nick )
                    end
                    @score[ nick ][ @SCORE_GAMES_PLAYED ] += 1
                end

                win_reason = "nothing"
                if @game_parameters[ @GAME_WIN_CRITERION ] == @WINBY_WINS
                    win_reason = "#{high_wins} wins"
                elsif @game_parameters[ @GAME_WIN_CRITERION ] == @WINBY_POINTS
                    win_reason = "#{high_score} points"
                end
                if winners.length > 1
                    put "A #{winners.length}-way tie for the win!"
                    put "#{winners.join( ', ' )} each had #{win_reason}."
                else
                    put "#{winners[ 0 ]} is the game winner with #{win_reason}."
                end

                other_scores = "Other scores: "
                @players.each do |nick, data|
                    next if winners.include?( nick )
                    case @game_parameters[ @GAME_WIN_CRITERION ]
                        when @WINBY_WINS
                            score_str = data[ @PLAYER_WINS ]
                        when @WINBY_POINTS
                            score_str = data[ @PLAYER_SCORE ]
                    end
                    other_scores += "#{nick}: #{score_str}  "
                end
                put other_scores

                if winners.length == 1
                    @score[ winners[ 0 ] ][ @SCORE_GAMES_WON ] += 1
                else
                    winners.each do |winner|
                        @score[ winner ][ @SCORE_GAMES_TIED ] += 1
                    end
                end

                saveScores

            end
        end
        return retval
    end

    def clue1
        @point_value = (@initial_point_value * 0.95).to_i
        put "Part of speech: #{ @part_of_speech[ @word ] }"
    end
    def clue2
        @point_value = (@initial_point_value * 0.90).to_i
        put "Etymology: #{ @etymology[ @word ] }"
    end
    def clue3
        @point_value = (@initial_point_value * 0.85).to_i
        put "Number of syllables: #{ @num_syllables[ @word ] }"
    end
    def clue4
        @point_value = (@initial_point_value * 0.70).to_i
        put "Starts with: #{ @word[ 0..0 ] }"
    end
    def clue5
        @point_value = (@initial_point_value * 0.30).to_i
        showDefinition
    end

    def showDefinition( word = @word )
        put "Definition: #{ @definition[ word ] }"
        @def_shown = true
    end

    def playing?
        retval = false
        if @game_parameters[ @GAME_STATE ] == @STATE_SETUP
            put "A game is currently being setup."
            retval = true
        elsif @game_parameters[ @GAME_STATE ] == @STATE_GOING
            put "A game is currently underway in #{@channel}."
            retval = true
        elsif @channel != nil
            put "A round is in progress in #{@channel}."
            retval = true
        end
        return retval
    end

    def setupGame( nick, userhost, handle, channel, text )
        return if playing?

        @game_parameters[ @GAME_STATE ] = @STATE_SETUP
        @channel = channel
        put "Defaults: Rounds: #{@DEFAULT_NUM_ROUNDS}; Win by: #{@WINBYSTR[ @DEFAULT_WIN_CRITERION ]}"
        put "Commands: rounds <number>; join; leave; players; winby <points|wins>; abort; start"
        @game_parameters[ @GAME_NUM_ROUNDS ] = @DEFAULT_NUM_ROUNDS
        @game_parameters[ @GAME_STARTER ] = nick
        @game_parameters[ @GAME_WIN_CRITERION ] = @DEFAULT_WIN_CRITERION
        @players = Hash.new
        setup_addPlayer( nick, userhost, handle, channel, text )

        @GAME_BINDS.each do |command, method|
            $reby.bind( "pub", "-", command, method, "$wordx" )
        end
    end

    def setup_numRounds( nick, userhost, handle, channel, text )
        return if channel != @channel
        num_rounds = text.to_i
        if num_rounds < 1
            put "Usage: rounds <positive integer>"
            return
        elsif num_rounds >= @TOO_MANY_ROUNDS
            put "Usage: rounds <some reasonable positive integer>"
            return
        end
        @game_parameters[ @GAME_NUM_ROUNDS ] = num_rounds
        put "Number of rounds set to #{@game_parameters[ @GAME_NUM_ROUNDS ]}."
    end

    def setup_addPlayer( nick, userhost, handle, channel, text )
        return if channel != @channel
        @players[ nick ] = Array.new
        @players[ nick ][ @PLAYER_PLAYING ] = true
        @players[ nick ][ @PLAYER_WINS ] = 0
        @players[ nick ][ @PLAYER_SCORE ] = 0
        put "#{nick} has joined the game."
    end

    def setup_removePlayer( nick, userhost, handle, channel, text )
        return if channel != @channel
        if nick == @game_parameters[ @GAME_STARTER ]
            sendNotice( "You can't leave the game, you started it.  Try the abort command.", nick )
            return
        end
        @players[ nick ] = nil
        put "#{nick} has withdrawn from the game."
    end

    def setup_listPlayers( nick, userhost, handle, channel, text )
        player_list = ""
        @players.each do |nick, data|
            if data[ @PLAYER_PLAYING ]
                player_list += "#{nick} "
            end
        end
        put player_list
    end

    def setup_winBy( nick, userhost, handle, channel, text )
        case text
            when /points/
                @game_parameters[ @GAME_WIN_CRITERION ] = @WINBY_POINTS
            when /wins/
                @game_parameters[ @GAME_WIN_CRITERION ] = @WINBY_WINS
        end
        put "Winner will be decided by #{@WINBYSTR[ @game_parameters[ @GAME_WIN_CRITERION ] ] }."
    end

    def isStarter?( nick )
        if nick == @game_parameters[ @GAME_STARTER ] or not $reby.onchan( @game_parameters[ @GAME_STARTER ] )
            return true
        else
            put "Only the person who invoked the game can issue that command."
            return false
        end
    end

    def unbindSetupBinds
        @GAME_BINDS.each do |command, method|
            $reby.unbind( "pub", "-", command, method, "$wordx" )
        end
    end

    def setup_abort( nick, userhost, handle, channel, text )
        return if channel != @channel
        return if not isStarter?( nick )

        unbindSetupBinds
        @game_parameters[ @GAME_STATE ] = @STATE_NONE
        put "Game aborted."
        @channel = nil
    end

    def startGame( nick, userhost, handle, channel, text )
        return if channel != @channel
        return if not isStarter?( nick )
        num_players = 0
        @players.each do |nick, data|
            if data[ @PLAYER_PLAYING ]
                num_players += 1
            end
        end
        if num_players < 2
            put "At least two players need to be in the game."
            return
        end

        unbindSetupBinds

        @game_parameters[ @GAME_CURRENT_ROUND ] = 1
        @channel = nil
        @game_parameters[ @GAME_STATE ] = @STATE_GOING
        oneRound( nick, userhost, handle, channel, text )
    end
end

$wordx = WordX.new

$reby.bind( "pub", "-", "!wordx", "oneRound", "$wordx" )
$reby.bind( "pub", "-", "!wordxscore", "printScore", "$wordx" )
$reby.bind( "pub", "-", "!word", "oneRound", "$wordx" )
$reby.bind( "pub", "-", "!wordscore", "printScore", "$wordx" )
$reby.bind( "pub", "-", "!wordsetup", "setupGame", "$wordx" )
