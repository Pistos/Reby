# Word Extreme

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

# The classic word unscramble game, but enhanced.

# By Pistos
# irc.freenode.net#mathetes

# !word
# !wordbattle
# !wordscore [number of scores to list]
# !wordrank[ing] [number of ranks to list]

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

class Battle
    attr_reader :state, :channel, :starter, :mode, :current_round, :players,
        :player_teams

    DEFAULT_NUM_ROUNDS = 3
    BATTLE_SETUP_TIMEOUT = 300 # seconds
    MAX_TEAM_NAME_LENGTH = 32
    TOO_MANY_ROUNDS = 50
    GAME_BINDS = {
        "rounds" => "setNumRounds",
        "join" => "addPlayer",
        "start" => "start",
        "abort" => "abort",
        "players" => "listPlayers",
        "leave" => "removePlayer",
        "team" => 'joinTeam',
    }
    
    def initialize( channel, nick )
        @channel = Channel.find_or_create_by_name( channel )
        player = Player.find_or_create_by_nick( nick )
        @mode = :rounds
        
        @num_rounds = DEFAULT_NUM_ROUNDS
        @current_round = 0
        @starter = player
        @players = Array.new
        @initial_titles = Hash.new
        @player_teams = Hash.new
        addPlayer( nick, nil, nil, channel, nil )
        
        GAME_BINDS.each do |command, method|
            $reby.bind( "pub", "-", command, method, "$wordx.battle" )
        end
        
        $reby.utimer( BATTLE_SETUP_TIMEOUT, "timeoutGame", "$wordx.battle" )
        
        put "Defaults: Rounds: #{DEFAULT_NUM_ROUNDS}"
        put "Commands: " + GAME_BINDS.keys.join( '; ' )
    end
    
    def put( text, destination = @channel.name )
        $reby.putserv "PRIVMSG #{destination} :#{text}"
    end
    def sendNotice( text, destination = @channel.name )
        $reby.putserv "NOTICE #{destination} :#{text}"
    end
    
    def unbindSetupBinds
        GAME_BINDS.each do |command, method|
            $reby.unbind( "pub", "-", command, method, "$wordx.battle" )
        end
        $reby.utimers.each do |utimer|
            case utimer[ 1 ]
                when /timeoutGame/
                    $reby.killutimer( utimer[ 2 ] )
            end
        end
    end
    
    def lms_mode?
        return( @mode == :lms )
    end
    def rounds_mode?
        return( @mode == :rounds )
    end
    
    def initial_players
        return @initial_titles.keys
    end
    
    def setNumRounds( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        if lms_mode?
            put "Number of rounds cannot be altered when battle mode is Last Man Standing."
            return
        end
        
        num_rounds = text.to_i
        if num_rounds < 1
            put "Usage: rounds <positive integer>"
            return
        elsif num_rounds >= TOO_MANY_ROUNDS
            put "Usage: rounds <some reasonable positive integer>"
            return
        end
        
        @num_rounds = num_rounds
        put "Number of rounds set to #{@num_rounds}."
    end
    
    def teams
        t = Set.new
        @players.each do |p|
            t << @player_teams[ p ]
        end
        return t
    end
    
    def more_rounds?
        retval = false
        
        if @current_round < @num_rounds
            retval = ( teams.size > 1 )
        end
        
        return retval
    end
    def inc_round
        @current_round += 1
    end
    
    def setMode( mode, arg = DEFAULT_NUM_ROUNDS )
        okay = true
        case mode
            when :lms
                @num_rounds = 99
                put "Battle mode: Last Man Standing"
            when :rounds
                @num_rounds = arg.to_i
                put "Battle mode: Rounds (#{@num_rounds})"
            else
                put "Invalid game mode (#{mode.to_s})"
                okay = false
        end
        if okay
            @mode = mode
        end
    end

    def clearLMS
        if @mode == :lms
            setMode( :rounds, DEFAULT_NUM_ROUNDS )
        end
    end

    def teammates?( player1, player2 )
        return( @player_teams[ player1 ] == @player_teams[ player2 ] )
    end
    
    def joinTeam( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        player = Player.find_or_create_by_nick( nick )
        includePlayer( player )
        team = text.strip[ 0...MAX_TEAM_NAME_LENGTH ]
        @player_teams[ player ] = team
        if team != player.nick
            put "#{player.nick} joined Team #{team}."
        end
    end
    
    def includePlayer( player )
        included = false
        if not @players.include? player
            @players << player
            if @players.size > 2
                setMode( :lms )
            end
            @player_teams[ player ] = player.nick
            put "#{player.nick} has joined the game.", @channel.name
            included = true
        end
        return included
    end
    
    def addPlayer( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        player = Player.find_or_create_by_nick( nick )
        if includePlayer( player )
            @initial_titles[ player ] = player.title
        else
            put "#{player.nick}: You're already in the game!"
        end
    end
    
    def removePlayer( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        player = Player.find_or_create_by_nick( nick )
        if player == @starter
            sendNotice( "You can't leave the game, you started it.  Try the abort command.", player.nick )
        elsif @players.delete( player )
            put "#{nick} has withdrawn from the game."
            if @players.size < 3
                clearLMS
            end
        else
            put "#{nick}: You cannot leave what you have not joined."
        end
    end

    def listPlayers( nick, userhost, handle, channel, text )
        str = "Players: "
        str << ( @players.collect { |p|
            p.nick + (
                @player_teams[ p ] != p.nick ?
                " (#{@player_teams[ p ]})" :
                ''
            )
        } ).join( ', ' )
        put str
    end
    
    def timeoutGame
        r = @starter.rating
        if r > Player::BASE_RATING
            put "Looks like you've got everyone running scared, #{@starter.nick}..."
        else
            put "It must be hard for a lesser fighter to break into the big leagues, huh, #{@starter.nick}?"
        end
        doAbort
    end
    
    def abort( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        if (
            Player.find_or_create_by_nick( nick ) != @starter and
            $reby.onchan( @starter.nick )
        )
            put "Only the person who invoked the battle can abort it."
            return
        end

        doAbort
    end
    
    def doAbort
        unbindSetupBinds
        put "Game aborted."
        $wordx.abortBattle
    end
    
    def start( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        if Player.find_or_create_by_nick( nick ) != @starter
            put "Only the person who invoked the battle can start it."
            return
        end
        if @players.length < 2
            put "At least two players need to be in the game."
            return
        end

        unbindSetupBinds

        @current_round = 1
        @initial_ranking = $wordx.ranking
        @players.each do |player|
            @initial_titles[ player ] = player.title
        end
        
        $wordx.oneRound( nil, nil, nil, @channel.name, nil )
    end
    
    def eliminate( player )
        @players.delete( player )
        put "#{player.nick} has been knocked out of contention!"
    end
    
    def report
        report_text = ''
        @final_ranking = $wordx.ranking
        @final_titles = Hash.new
        players = @initial_titles.keys
        players.each do |player|
            @final_titles[ player ] = player.title
        end
        if @players.size > 1 and teams.size < @players.size
            report_text << "  Team #{@player_teams[ @players[ 0 ] ]} won!"
        end
        players.each do |player|
            initial_rank, initial_score = @initial_ranking.rank_and_score( player )
            initial_score ||= Player::BASE_RATING
            final_rank, final_score = @final_ranking.rank_and_score( player )
            initial_title = @initial_titles[ player ]
            final_title = @final_titles[ player ]
            terminal_punctuation = '.'
            sentence = []
            if final_score > initial_score
                sentence = [ "#{player.nick} gained #{final_score - initial_score} points" ]
                if initial_title != final_title
                    sentence << "advanced from #{initial_title} to #{final_title}"
                    terminal_punctuation = '!'
                end
                if initial_rank != nil and final_rank < initial_rank
                    sentence << "rose from ##{initial_rank} to ##{final_rank}"
                    terminal_punctuation = '!'
                end
            elsif final_score < initial_score
                sentence = [ "#{player.nick} lost #{initial_score - final_score} points" ]
                if initial_title != final_title
                    sentence << "got demoted from #{initial_title} to #{final_title}"
                    terminal_punctuation = '!'
                end
                if initial_rank != nil and final_rank > initial_rank
                    sentence << "fell from ##{initial_rank} to ##{final_rank}"
                    terminal_punctuation = '!'
                end
            end
            report_text << "  " << sentence.join( ' and ' ) << terminal_punctuation
        end
        
        put "Battle over.#{report_text}"
    end
end

class WordX
    attr_reader :battle
    
    VERSION = '2.0.0'
    LAST_MODIFIED = 'March 20, 2006'
    MIN_GAMES_PLAYED_TO_SHOW_SCORE = 0
    DEFAULT_INITIAL_POINT_VALUE = 100
    MAX_SCORES_TO_SHOW = 10
    INCLUDE_PLAYERS_WITH_NO_GAMES = true
    
    def initialize
        # Change these as you please.
        @say_answer = true
        # End of configuration variables.

        @channel = nil
        @word = nil
        @game = nil
        @last_winner = nil
        @consecutive_wins = 0

        @num_syllables = Hash.new
        @part_of_speech = Hash.new
        @etymology = Hash.new
        @definition = Hash.new

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
        #return if nick != nil and battle_going?( channel )
        
        if nick != nil
            # Practice game.
            player = Player.find_by_nick( nick )
            if player != nil and player.winning_too_much?
                put "#{nick}: You have already demonstrated your great skill in the game.  It is time for you to graduate to !wordbattle.  If you insist, you may practice again in about an hour.", channel
                return
            end
        end

        unbindPracticeCommand        

        @channel = Channel.find_or_create_by_name( channel )
        @word = Word.random
        @game = Game.create( { :word_id => @word.id } )
        @initial_point_value = DEFAULT_INITIAL_POINT_VALUE
        
        if @battle != nil
            @battle.players.each do |player|
                @game.participations << Participation.new(
                    :player_id => player.id,
                    :game_id => @game.id,
                    :team => @battle.player_teams[ player ]
                )
            end
            @initial_point_value += (@game.participations.size - 2) * 15
        end

        killTimers
        @def_shown = false
        @already_guessed = false
        
        @point_value = @initial_point_value
        
        # Mix up the letters

        mixed_word = @word.mixed
        while mixed_word == @word.word
            mixed_word = @word.mixed
        end

        $reby.bind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        
        # Set the timers to reveal the clues

        $reby.utimer( 100, "nobodyGotIt", "$wordx" )
        $reby.utimer( 15, "clue1", "$wordx" )
        $reby.utimer( 20, "clue2", "$wordx" )
        $reby.utimer( 25, "clue3", "$wordx" )
        $reby.utimer( 40, "clue4", "$wordx" )
        $reby.utimer( 55, "clue5", "$wordx" )
        $reby.utimer( 70, "clue6", "$wordx" )
        
        put "Unscramble ... #{mixed_word}"
    end

    def printScore( nick, userhost, handle, channel, text )
        num_to_show, start_rank, end_rank = printing_parameters( text )
        
        num_shown = 0
        index = 0
        players = Player.find( :all, :conditions => [ 'warmup_points > 0' ], :order => 'warmup_points desc' )
        players.each do |player|
            index += 1
            next if index < start_rank
            
            put( "%2d. %-20s %5d" % [ index, player.nick, player.warmup_points ], channel )
            
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
            put "\002#{player.nick}\002, \002#{player.title}\002 (L\002#{player.level}\002) - Battle rating: \002#{player.rating}\002 (Rank: \002##{rank}\002) (#{player.games_played} games) High/Low Rating: #{player.highest_rating}/#{player.lowest_rating}", channel
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
            
            put( "%2d. %-32s %-5s %5d" % [ index, "#{player.nick}, #{player.title}", "(L#{player.level})", rating ], channel )
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
    
    def bindPracticeCommand
        $reby.bind( "pub", "-", "!word", "oneRound", "$wordx" )
    end
    def unbindPracticeCommand
        $reby.unbind( "pub", "-", "!word", "oneRound", "$wordx" )
    end

    def correctGuess( nick, userhost, handle, channel, text )
        return if @already_guessed
        
        winner = Player.find_or_create_by_nick( nick )
        return if winner.nil?
        
        if @battle.nil?
            if winner.winning_too_much?
                put "#{nick}: You have already demonstrated your great skill in the game.  It is time for you to graduate to !wordbattle.  If you insist, you may practice again in about an hour.", nick
                return
            end
        elsif not @game.participations.find_by_player_id( winner.id )
            sendNotice( "Since you did not join this game, your guesses are not counted.", winner.nick )
            return
        end

        @already_guessed = true

        killTimers
        $reby.unbind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        
        @game.end_time = Time.now
        
        winner_award = @point_value
        losing_participation = nil
        if @battle != nil
            # Modify award based on comparison of ratings.
            
            winner_award = 0
            winner_rating = winner.rating.to_f
            highest_opponent_rating = 0
            high_loser = nil
            
            @game.participations.each do |participation|
                player = Player.find( participation.player_id )
                next if player == winner
                next if @battle.teammates?( player, winner )
                
                player_rating = player.rating.to_f
                loss = ( @point_value * ( player_rating / winner_rating ) ).to_i
                if not @battle.lms_mode?
                    participation.points_awarded = -loss
                end
                if player_rating > highest_opponent_rating
                    highest_opponent_rating = player_rating
                    high_loser = player
                    losing_participation = participation
                    winner_award = loss
                end
            end
        else
            winner.warmup_points += winner_award
        end

        put "#{winner.nick} got it ... #{@word.word} ... for #{winner_award} points."
        
        if @battle.nil?
            @game.warmup_winner = winner.id
        elsif @battle.lms_mode?
            losing_participation.points_awarded = -winner_award
            @battle.eliminate( high_loser )
        end

        if winner == @last_winner
            winner.consecutive_wins += 1
            put "#{winner.consecutive_wins} consecutive victories!"
        else
            winner.consecutive_wins = 1
        end
        
        @last_winner = winner

        if not @def_shown
            showDefinition
        end

        # Record score.
        
        winner.save
        @game.participations.each do |p|
            if p.player_id == winner.id
                p.points_awarded = winner_award
            end
            p.save
        end
        
        endRound
    end

    def nobodyGotIt
        put "No one solved it in time.  The word was #{@word.word}."
        $reby.unbind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        
        @game.end_time = Time.now
        
        endRound
    end
    
    def endRound
        @game.save
        @channel.save
        
        if not nextRound
            bindPracticeCommand
            @channel = nil
        end
    end

    # Returns true iff doing another round.
    def nextRound
        retval = false
        if @battle != nil
            if @battle.more_rounds?
                @battle.inc_round
                oneRound( nil, nil, nil, @channel.name, nil )
                retval = true
            else
                # No more rounds in the game.  GAME OVER.
                
                @battle.initial_players.each do |player|
                    player.save_rating_records
                end
                
                @battle.report
                @battle = nil
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
        @point_value = (@initial_point_value * 0.40).to_i
        put "Starts and ends with: " +
            @word.word[ 0..0 ] +
            "." * ( @word.word.length - 2 ) +
            @word.word[ -1..-1 ]
    end
    def clue6
        @point_value = (@initial_point_value * 0.15).to_i
        showDefinition
    end

    def showDefinition( word = @word )
        put "Definition: #{ @word.definition }"
        @def_shown = true
    end

    def battle_going?( channel )
        retval = false
        if @battle != nil
            if @battle.current_round == 0
                put( "A battle is being setup in #{@battle.channel.name} by #{@battle.starter.nick}.", channel )
            else
                put(
                    "A battle is currently underway in #{@battle.channel.name} between " +
                        @battle.initial_players.collect { |p| p.nick }.join(', ') + ".",
                    channel
                )
            end
            retval = true
        elsif @channel != nil
            put "A round is in progress in #{@channel.name}.", channel
            retval = true
        end
        return retval
    end

    def setupGame( nick, userhost, handle, channel, text )
        return if battle_going?( channel )
        
        unbindPracticeCommand
        @battle = Battle.new( channel, nick )
    end
    
    def abortBattle
        @battle = nil
        bindPracticeCommand
    end
    
    def listCharacterClasses( nick, userhost, handle, channel, text )
        classes = []
        TitleSet.find( :all, :order => 'name' ).each do |ts|
            classes << ts.name
        end
        put "Character Classes: #{classes.join( ', ' )}", channel
    end
    
    def setCharacterClass( nick, userhost, handle, channel, text )
        cl = text.strip.split.collect { |w| w.capitalize }.join( ' ' )
        ts = TitleSet.find_by_name( cl )
        if ts.nil?
            put "'#{cl}' is not a class.  Try !wordclasses to get a list of available classes.", channel
        else
            player = Player.find_by_nick( nick )
            if player.nil?
                put "#{nick}: You are not a player.  Join a !wordbattle first.", channel
            else
                player.title_set_id = ts.id
                player.save
                put "#{player.nick} is now a#{ts.name =~ /^[aoeuiAOEUI]/ ? 'n' : ''} #{ts.name}.", channel
            end
        end
    end
end

$wordx = WordX.new

$wordx.bindPracticeCommand
$reby.bind( "pub", "-", "!wordbattle", "setupGame", "$wordx" )
$reby.bind( "pub", "-", "!wordscore", "printScore", "$wordx" )
$reby.bind( "pub", "-", "!wordrating", "printRating", "$wordx" )
$reby.bind( "pub", "-", "!wordrank", "printRanking", "$wordx" )
$reby.bind( "pub", "-", "!wordranking", "printRanking", "$wordx" )
$reby.bind( "pub", "-", "!wordclass", "setCharacterClass", "$wordx" )
$reby.bind( "pub", "-", "!wordclasses", "listCharacterClasses", "$wordx" )

