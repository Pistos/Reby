# Word Extreme

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

# The classic word unscramble game, but enhanced.
# http://word.purepistos.net
# http://purepistos.net/wiki/doku.php?id=Reby:Scripts:word2.rb

# By Pistos
# irc.freenode.net#mathetes

# !word
# !wordbattle
# !wordscore [number of scores to list]
# !wordrank[ing] [number of ranks to list]

require 'word-ar-defs'
require 'set'

def find_or_create_player( nick )
    player = Player.find_by_nick( nick )
    if not player
        player = Player.create( :nick => nick, :creation_time => Time.now )
    end
    return player
end


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
        :player_teams, :king, :wins, :num_rounds

    DEFAULT_NUM_ROUNDS = 3
    BATTLE_SETUP_TIMEOUT = 300 # seconds
    MAX_TEAM_NAME_LENGTH = 32
    TOO_MANY_ROUNDS = 11
    TOO_MANY_LOSSES = 4
    DEFAULT_KO_LOSSES = 2
    GAME_BINDS = {
        "rounds" => "setNumRounds",
        "join" => "addPlayer",
        "start" => "start",
        "abort" => "abort",
        "players" => "listPlayers",
        "leave" => "removePlayer",
        "team" => 'joinTeam',
        'mode' => 'changeMode',
        'losses' => 'setNumLosses',
    }
    
    def initialize( channel, nick )
        @channel = Channel.find_or_create_by_name( channel )
        player = Player.find_or_create_by_nick( nick )
        @mode = :rounds
        
        @num_rounds = DEFAULT_NUM_ROUNDS
        @current_round = 0
        @starter = player
        @battlers = Array.new # All battlers in this battle
        @players = Array.new # Only those playing in this and subsequent rounds
        @initial_titles = Hash.new
        @initial_money = Hash.new
        @player_teams = Hash.new
        @king = nil
        @lms_losses = Hash.new( 0 )
        @ko_losses = DEFAULT_KO_LOSSES
        @wins = Hash.new( 0 )
        
        GAME_BINDS.each do |command, method|
            $reby.bind( "pub", "-", command, method, "$wordx.battle" )
        end
        
        $reby.utimer( BATTLE_SETUP_TIMEOUT, "timeoutGame", "$wordx.battle" )
        
        put "Defaults: Rounds: #{DEFAULT_NUM_ROUNDS} LMS Losses: #{DEFAULT_KO_LOSSES}"
        put "Commands: " + GAME_BINDS.keys.join( '; ' )
        
        addPlayer( nick, nil, nil, channel, nil )
    end
    
    def put( text, destination = @channel.name )
        $reby.putserv "PRIVMSG #{destination} :[b] #{text}"
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
    
    def battlers
        return @battlers.collect! { |b| b.reload }
    end
    
    def setNumRounds( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        if @mode == :lms
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
    
    def setNumLosses( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        if @mode != :lms
            put "Number of losses can only be set when battle mode is Last Man Standing."
            return
        end
        
        num_losses = text.to_i
        if num_losses < 1
            put "Usage: losses <positive integer>"
            return
        elsif num_losses >= TOO_MANY_LOSSES
            put "Usage: losses <some reasonable positive integer>"
            return
        end
        
        @ko_losses = num_losses
        put "Number of losses set to #{@num_losses}."
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
        if @mode != :lms
            old_rounds = @num_rounds
        end
        case mode
            when :koth
                @num_rounds = old_rounds || arg.to_i
                put "Battle mode: King of the Hill (#{@num_rounds} rounds)"
            when :lms
                @num_rounds = 99
                put "Battle mode: Last Man Standing"
            when :rounds
                @num_rounds = old_rounds || arg.to_i
                put "Battle mode: Rounds (#{@num_rounds})"
            else
                put "Invalid game mode (#{mode.to_s})"
                okay = false
        end
        if okay
            @mode = mode
        end
    end
    def changeMode( nick, userhost, handle, channel, text )
        mode = text.strip
        case mode
            when 'lms'
                if @battlers.size < 3
                    put "At least 3 players are needed for Last Man Standing."
                else
                    setMode( :lms )
                end
            when 'koth'
                if @battlers.size < 3
                    put "At least 3 players are needed for King of the Hill."
                else
                    setMode( :koth )
                end
            else
                put "Valid modes: lms, koth"
        end
    end

    def teammates?( player1, player2 )
        return( @player_teams[ player1 ] == @player_teams[ player2 ] )
    end
    
    def joinTeam( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        if @mode == :koth
            put "There are no teams in King of the Hill."
            return
        end
        
        team = text.strip[ 0...MAX_TEAM_NAME_LENGTH ]
        if team.empty?
            put "#{nick}: team <team name>"
            return
        end
        
        player = Player.find_or_create_by_nick( nick )
        includePlayer( player )
        @player_teams[ player ] = team
        if team != player.nick
            put "#{player.nick} joined Team #{team}."
        end
    end
    
    def includePlayer( player )
        included = false
        if not @players.include? player
            @battlers << player
            @players << player
            if @players.size > 2 and @mode == :rounds
                setMode( :koth )
            end
            @player_teams[ player ] = player.nick
            put "#{player.nick} has joined the game.", @channel.name
            included = true
            $wordx.initiateRegistrationCheck( player )
        end
        return included
    end
    
    def addPlayer( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        player = find_or_create_player( nick )
        if not includePlayer( player )
            put "#{player.nick}: You're already in the game!"
        end
    end
    
    def removePlayer( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        player = find_or_create_player( nick )
        if player == @starter
            if $wordx.registered?( player )
                put "#{player.nick}: You can't leave the game, you started it.  Try the abort command."
            else
                doAbort
            end
        elsif @players.delete( player )
            put "#{nick} has withdrawn from the game."
            if @players.size < 3
                setMode( :rounds, DEFAULT_NUM_ROUNDS )
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
    
    def checkRegistered( nick )
        p = Player.find_by_nick( nick )
        if p != nil and not $wordx.registered?( p )
            put "#{p.nick} is not identified with network services.  Forcing withdrawl..."
            removePlayer( p.nick, nil, nil, @channel.name, nil )
        end
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
            find_or_create_player( nick ) != @starter and
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
        
        if find_or_create_player( nick ) != @starter
            put "Only the person who invoked the battle can start it."
            return
        end
        
        all_players_registered = true
        @players.each do |p|
            all_players_registered &&= $wordx.registered?( p )
        end
        if not all_players_registered
            put "Please wait until all players are determined to be registered..."
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
            @initial_money[ player ] = player.money
        end
        
        $wordx.oneRound( nil, nil, nil, @channel.name, nil )
    end
    
    def eliminate( player )
        @lms_losses[ player ] += 1
        if @lms_losses[ player ] >= @ko_losses
            @players.delete( player )
            put "#{player.nick} has been knocked out of contention!"
        end
    end
    
    def addWin( player )
        @wins[ player ] += 1
    end
    
    def report
        report_text = ''
        @final_ranking = $wordx.ranking
        @final_titles = Hash.new
        @final_money = Hash.new
        players = battlers
        players.each do |player|
            @final_titles[ player ] = player.title
            @final_money[ player ] = player.money
        end
        if @players.size > 1 and teams.size < @players.size
            report_text << "  Team #{@player_teams[ @players[ 0 ] ]} won!"
        end
        players.each do |player|
            initial_rank, initial_score = @initial_ranking.rank_and_score( player )
            initial_score ||= Player::BASE_RATING
            initial_title = @initial_titles[ player ]
            initial_money = @initial_money[ player ] || 0
            
            final_rank, final_score = @final_ranking.rank_and_score( player )
            final_score ||= Player::BASE_RATING
            final_title = @final_titles[ player ]
            final_money = @final_money[ player ] || 0
            
            terminal_punctuation = '.'
            sentence = [ ]
            
            if final_score > initial_score
                sentence << "gained #{final_score - initial_score} points"
                if initial_title != final_title
                    sentence << "advanced from #{initial_title} to #{final_title}"
                    terminal_punctuation = '!'
                end
                if initial_rank != nil and final_rank < initial_rank
                    sentence << "rose from ##{initial_rank} to ##{final_rank}"
                    terminal_punctuation = '!'
                end
            elsif final_score < initial_score
                sentence << "lost #{initial_score - final_score} points"
                if initial_title != final_title
                    sentence << "got demoted from #{initial_title} to #{final_title}"
                    terminal_punctuation = '!'
                end
                if initial_rank != nil and final_rank > initial_rank
                    sentence << "fell from ##{initial_rank} to ##{final_rank}"
                    terminal_punctuation = '!'
                end
            end
            if final_money > initial_money
                sentence << "gained #{final_money - initial_money} #{WordX::CURRENCY}"
            elsif final_money < initial_money
                sentence << "incurred a net loss of #{initial_money - final_money} #{WordX::CURRENCY}"
            end
            report_text << "  #{player.nick} " << sentence.join( ' and ' ) << terminal_punctuation
        end
        
        put "Battle over.#{report_text}"
    end
end

class WordX
    attr_reader :battle
    
    VERSION = '2.2.2'
    LAST_MODIFIED = 'April 5, 2006'
    MIN_GAMES_PLAYED_TO_SHOW_SCORE = 0
    DEFAULT_INITIAL_POINT_VALUE = 100
    MAX_SCORES_TO_SHOW = 10
    INCLUDE_PLAYERS_WITH_NO_GAMES = true
    CURRENCY = 'gold'
    MONETARY_AWARD_FRACTION = 0.25
    GIVE_AWAY_REDUCTION = 0.10
    PARTICIPATION_AWARD = 5
    CLUE4_FRACTION = 0.70
    CLUE5_FRACTION = 0.40
    CLUE6_FRACTION = 0.15
    CONFIRMATION_TIMEOUT = 5 # seconds
    COST_CLASS_CHANGE = 5 # gold
    MAX_WARMUP_POINTS = 2000
    MAX_MEMOS_PER_PLAYER = 3
    
    OPS = Set.new [
        "Pistos",
    ]
    
    def initialize
        # Change these as you please.
        @say_answer = true
        # End of configuration variables.

        @channel = nil
        @word = nil
        @game = nil

        @num_syllables = Hash.new
        @part_of_speech = Hash.new
        @etymology = Hash.new
        @definition = Hash.new
        
        @registered_players = Hash.new
        @registration_check_pending = Hash.new
        @memo_counts = Hash.new( 0 )
        
        connect_to_db
        
        @item_glass_shield = Item.find_by_code( 'glass-shield' )
    end

    def connect_to_db
        ActiveRecord::Base.establish_connection(
            :adapter  => "postgresql",
            :host     => "localhost",
            :username => "word",
            :password => "word",
            :database => "word"
        )
    end
    
    # Sends a line to the game channel.
    def put( text, destination = @active_channel || @channel.name )
        $reby.putserv "PRIVMSG #{destination} :#{@battle.nil? ? '' : '[b] '}#{text}"
    end
    def putquick( text, destination = @active_channel || @channel.name )
        $reby.putquick "PRIVMSG #{destination} :#{@battle.nil? ? '' : '[b] '}#{text}"
    end
    
    def sendNotice( text, destination = @active_channel || @channel.name )
        $reby.putserv "NOTICE #{destination} :#{text}"
    end

    def oneRound( nick, userhost, handle, channel, text )
        @active_channel = channel
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
        @word = Word.random( @battle.nil? )
        @game = Game.create( { :word_id => @word.id, :start_time => Time.now } )
        @initial_point_value = DEFAULT_INITIAL_POINT_VALUE
        @given_away_by = nil
        @word_regexp = Regexp.new( @word.word.split( // ).join( ".*" ) )
        
        if @battle != nil
            highest_rating = 0
            _king = nil
            _king_participation = nil
            @battle.players.each do |player|
                partic = Participation.new(
                    :player_id => player.id,
                    :game_id => @game.id,
                    :team => @battle.player_teams[ player ]
                )
                @game.participations << partic
                
                if @battle.mode == :koth
                    if @king.nil?
                        r = player.rating
                        if r > highest_rating
                            highest_rating = r
                            _king = player
                            _king_participation = partic
                        end
                    elsif player == @king
                        @king_participation = partic
                    end
                end
            end
            if @king.nil?
                @king = _king
                @king_participation = _king_participation
            else
                put "#{@king.nick} is the king."
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
        $reby.utimer( 15, "showClue1", "$wordx" )
        $reby.utimer( 20, "showClue2", "$wordx" )
        $reby.utimer( 25, "showClue3", "$wordx" )
        $reby.utimer( 40, "showClue4", "$wordx" )
        $reby.utimer( 55, "showClue5", "$wordx" )
        $reby.utimer( 70, "showClue6", "$wordx" )
        
        round_str = ""
        if @battle != nil
            round_str = "(round #{@battle.current_round} of #{@battle.num_rounds})"
        end
        putquick "Unscramble ... #{mixed_word}         #{round_str}"
    end

    def printScore( nick, userhost, handle, channel, text )
        @active_channel = channel
        num_to_show, start_rank, end_rank = printing_parameters( text )
        
        num_shown = 0
        index = 0
        players = Player.find( :all, :conditions => [ 'warmup_points > 0' ], :order => 'warmup_points desc' )
        players.each do |player|
            index += 1
            next if index < start_rank
            
            put "%2d. %-20s %5d" % [ index, player.nick, player.warmup_points ]
            
            num_shown += 1
            break if num_shown >= num_to_show
        end
    end
    
    def printRating( nick, userhost, handle, channel, text )
        @active_channel = channel
        if not text.empty?
            player = Player.find_by_nick( text )
            if player.nil?
                put "'#{text}' is not a player."
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
            put "http://word.purepistos.net/player/view?id=#{player.id}"
            put "\002#{player.nick}\002, \002#{player.title}\002 (L\002#{player.level}\002) - Battle rating: \002#{player.rating}\002 (Rank: \002##{rank}\002) (#{player.money} #{CURRENCY}) (#{player.games_played} rounds) High/Low Rating: #{player.highest_rating}/#{player.lowest_rating}"
        else
            put "#{nick}: You're not a !word warrior!  Play a !wordbattle."
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
        @active_channel = channel
        if text =~ /^[^\d -]+$/
            printRating( nick, userhost, handle, channel, text )
            return
        end
        
        put "http://word.purepistos.net"
        
        num_to_show, start_rank, end_rank = printing_parameters( text )
        
        num_shown = 0
        index = 0
        r = ranking
        r.each do |player, rating|
            index += 1
            next if index < start_rank
            
            put( "%2d. %-32s %-5s %5d" % [ index, "#{player.nick}, #{player.title}", "(L#{player.level})", rating ] )
            num_shown += 1
            break if num_shown >= num_to_show
        end
        
        put "(#{num_shown} of #{r.size} players shown)"
    end
    
    def killTimers
        $reby.utimers.each do |utimer|
            case utimer[ 1 ]
                when /nobodyGotIt|showClue\d/
                    $reby.killutimer( utimer[ 2 ] )
            end
        end
    end
    
    def bindPracticeCommand
        $reby.unbind( "pub", "-", "!word", "noPracticeMessage", "$wordx" )
        $reby.bind( "pub", "-", "!word", "oneRound", "$wordx" )
    end
    def unbindPracticeCommand
        $reby.unbind( "pub", "-", "!word", "oneRound", "$wordx" )
        $reby.bind( "pub", "-", "!word", "noPracticeMessage", "$wordx" )
    end
    def calculatedLoss( winner, loser )
        return ( @point_value * ( loser.rating.to_f / winner.rating.to_f ) ).to_i
    end
    
    def highest_loser( winner )
        winner_award = 0
        winner_rating = winner.rating.to_f
        highest_opponent_rating = 0
        losing_participation = nil
        low_wins = 999
        
        @battle.players.each do |player|
            next if player == winner
            if @battle.wins[ player ] < low_wins
                low_wins = @battle.wins[ player ]
            end
        end
        
        @game.participations.each do |participation|
            player = Player.find( participation.player_id )
            next if player == winner
            next if @battle.wins[ player ] > low_wins
            
            loss = calculatedLoss( winner, player )
            player_rating = player.rating
            if player_rating > highest_opponent_rating
                highest_opponent_rating = player_rating
                losing_participation = participation
                winner_award = loss
            end
        end
        
        return losing_participation, winner_award
    end
    
    def correctGuess( nick, userhost, handle, channel, text )
        @active_channel = channel
        # Validity checks:
        
        return if @already_guessed
        
        winner = find_or_create_player( nick )
        return if winner.nil?
        
        if @battle.nil?
            if winner.winning_too_much?
                put "#{nick}: You have already demonstrated your great skill in the game.  It is time for you to graduate to !wordbattle.  If you insist, you may practice again in about an hour.", nick
                return
            end
        elsif not @game.participations.find_by_player_id( winner.id )
            sendNotice( "Since you are not a surviving battler, your guesses are not counted.", winner.nick )
            @given_away_by = nick
            return
        end
        
        # -----

        @already_guessed = true

        killTimers
        $reby.unbind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        
        @game.end_time = Time.now
        
        put "#{winner.nick} got it ... #{@word.word}"
        
        if @given_away_by != nil
            put "Since #{@given_away_by} gave the answer away, the award is reduced."
            @point_value = ( @point_value * GIVE_AWAY_REDUCTION ).to_i
        end
        
        winner_award = @point_value
        losing_participation = nil
        if @battle.nil?
            winner.update_attribute( :warmup_points, winner.warmup_points + winner_award )
            @game.warmup_winner = winner.id
            
            if winner.warmup_points > MAX_WARMUP_POINTS
                put "#{winner.nick} has exceeded #{MAX_WARMUP_POINTS} practice points!  Congratulations!  Practice scores have been reset."
                Player.update_all "warmup_points = 0"
            end
        else
            # Determine loser.
            
            loser = nil
            case @battle.mode
                when :rounds
                    @game.participations.each do |participation|
                        player = Player.find( participation.player_id )
                        next if player == winner
                        
                        loser = player
                        loss = calculatedLoss( winner, player )
                        participation.points_awarded = -loss
                        losing_participation = participation
                        winner_award = loss
                    end
                when :koth
                    if winner != @king
                        loser = @king
                        losing_participation = @king_participation
                        winner_award = calculatedLoss( winner, @king )
                    else
                        losing_participation, winner_award = highest_loser( winner )
                        loser = losing_participation.player
                    end
                    @king = winner
                when :lms
                    @battle.addWin( winner )
                    losing_participation, winner_award = highest_loser( winner )
                    loser = losing_participation.player
                    put "#{winner.nick} strikes #{loser.nick}!"
                    @battle.eliminate( loser )
            end
            
            # Is the loser using a shield?
            
            shield = loser.equipment.find(
                :first,
                :conditions => [
                    "item_id = ? AND equipped",
                    @item_glass_shield.id
                ]
            )
            if shield
                #put "(shield effects temporarily disabled)"
                put "#{loser.nick}'s shield absorbs the blow, reducing the point value!  But the shield shatters into innumerable fragments."
                winner_award -= 100
                if winner_award < 0
                    winner_award = 0
                end
                Equipment.delete( shield.id )
            end
            
            # Dole out the awards...
            
            losing_participation.points_awarded = -winner_award
        end

        put "... for #{winner_award} points."
        
        #if not @def_shown
            #showDefinition
        #end

        # Record score.
        
        @game.participations.each do |p|
            monetary_award = PARTICIPATION_AWARD
            if p.player_id == winner.id
                p.update_attribute( :points_awarded, winner_award )
                monetary_award += ( winner_award * MONETARY_AWARD_FRACTION ).to_i
            else
                p.save
            end
            player = p.player
            player.money += monetary_award
            player.save
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
        @word = nil
        @game = nil

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
                
                @battle.battlers.each do |player|
                    player.save_rating_records
                end
                
                @battle.report
                @battle = nil
            end
        end
        return retval
    end

    def clue1
        return "Part of speech: #{ @word.pos }"
    end
    def clue2
        return "Etymology: #{ @word.etymology }"
    end
    def clue3
        return "Number of syllables: #{ @word.num_syllables }"
    end
    def clue4
        return "Starts with: #{ @word.word[ 0..0 ] }"
    end
    def clue5
        return "Starts and ends with: " +
            @word.word[ 0..0 ] +
            "." * ( @word.word.length - 2 ) +
            @word.word[ -1..-1 ]
    end
    def clue6
        "Definition: #{ @word.definition }"
    end
    def showClue1
        @point_value = (@initial_point_value * 0.95).to_i
        put clue1
    end
    def showClue2
        @point_value = (@initial_point_value * 0.90).to_i
        put clue2
    end
    def showClue3
        @point_value = (@initial_point_value * 0.85).to_i
        put clue3
    end
    def showClue4
        @point_value = (@initial_point_value * CLUE4_FRACTION).to_i
        put clue4
    end
    def showClue5
        @point_value = (@initial_point_value * CLUE5_FRACTION).to_i
        put clue5
    end
    def showClue6
        @point_value = (@initial_point_value * CLUE6_FRACTION).to_i
        showDefinition
    end

    def showDefinition
        put clue6
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
                        @battle.battlers.collect { |p| p.nick }.join(', ') + ".",
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
        @active_channel = channel
        return if battle_going?( channel )
        
        unbindPracticeCommand
        @battle = Battle.new( channel, nick )
        @king = nil
    end
    
    def abortBattle
        @battle = nil
        bindPracticeCommand
    end
    
    def listCharacterClasses( nick, userhost, handle, channel, text )
        @active_channel = channel
        classes = []
        TitleSet.find( :all, :order => 'name' ).each do |ts|
            classes << ts.name
        end
        put "http://word.purepistos.net/title/list"
        put "Character Classes: #{classes.join( ', ' )}"
    end
    
    def setCharacterClass( nick, userhost, handle, channel, text )
        @active_channel = channel
        cl = text.strip.split.collect { |w| w.capitalize }.join( ' ' )
        ts = TitleSet.find_by_name( cl )
        if ts.nil?
            put "'#{cl}' is not a class."
            listCharacterClasses( nil, nil, nil, channel, nil )
        else
            player = Player.find_by_nick( nick )
            if player.nil?
                put "#{nick}: You are not a player.  Join a !wordbattle first."
            else
                cost = COST_CLASS_CHANGE
                if player.debit( cost )
                    player.title_set_id = ts.id
                    player.save
                    put "#{player.nick} is now a#{ts.name =~ /^[aoeuiAOEUI]/ ? 'n' : ''} #{ts.name}."
                else
                    put "#{player.nick}: You don't have the #{cost} #{CURRENCY} needed to change classes."
                end
                
            end
        end
    end
    
    def buy( nick, userhost, handle, channel, text )
        @active_channel = channel
        arg = text.strip
        
        player = Player.find_by_nick( nick )
        
        item = Item.find_by_code( arg )
        if item != nil
            if player.under_limit?( item )
                sellItem( player, item )
            else
                put "#{nick}: You may not have more than #{item.ownership_limit} #{item.ownership_limit > 1 ? item.name.pluralize : item.name}"
            end
        elsif @game != nil
            case arg
                when '4'
                    buyClue( player, clue4, CLUE4_FRACTION )
                when '5'
                    buyClue( player, clue5, CLUE5_FRACTION )
                when '6'
                    buyClue( player, clue6, CLUE6_FRACTION )
                else
                    put "No such item or clue for sale."
            end
        else
            put(
                "No such item '#{arg}' for sale.  Items: " + (
                    Item.find( :all ).collect { |item| item.code }.join( ', ' )
                )
            )
        end
    end
    
    def sellItem( player, item )
        cost = item.price
        if player.debit( cost )
            player.equipment.create( :item_id => item.id )
            put "#{player.nick} spent #{cost} #{CURRENCY}."
        else
            put "#{player.nick}: #{item.name.pluralize} cost #{cost} #{CURRENCY}, you haven't got that much!"
        end
    end
    
    def buyClue( player, clue, fraction )
        cost = ( @initial_point_value * ( 1.0 - fraction ) ).to_i
        if player.debit( cost )
            sendNotice( clue, player.nick )
            put "#{player.nick} spent #{cost} #{CURRENCY}."
        else
            put "#{player.nick}: You don't have the #{cost} #{CURRENCY} needed to buy that!"
        end
    end
    
    def registrationNotification( from, keyword, text )
        return if keyword != "320"
        
        if text =~ /(\S+) :is identified to services/
            player = Player.find_by_nick( $1 )
            if player != nil
                @registered_players[ player ] = true
            end
        end
    end
    def registrationCheck( from, keyword, text )
        return if keyword != "318"  # end of WHOIS
        
        if text =~ /(\S+) :End of \/WHOIS list./
            player = Player.find_by_nick( $1 )
            if player != nil
                @registration_check_pending[ player ] = false
            end
            if @battle != nil
                @battle.checkRegistered( $1 )
            end
        end
    end
    
    def registered?( player )
        return( @registered_players[ player ] == true )
    end

    def initiateRegistrationCheck( player )
        @registered_players[ player ] = false
        $reby.putserv "WHOIS #{player.nick}"
    end
    
    def confirmRegistration( nick )
        retval = false
        player = Player.find_by_nick( nick )
        if player != nil
            @registration_check_pending[ player ] = true
            initiateRegistrationCheck( player )
            t1 = Time.now
            while @registration_check_pending[ player ]
                sleep 0.5
                if Time.now - t1 > CONFIRMATION_TIMEOUT
                    break
                end
            end
            if not @registration_check_pending[ player ]
                retval = registered?( player )
            end
        end
        
        return retval
    end
    
    def command( nick, userhost, handle, channel, text )
        @active_channel = channel
        
        player = Player.find_by_nick( nick )
        if player.nil?
            put "#{nick}: You are not a player.  Fight in a !wordbattle first."
            return
        end
        
        command = text.strip
        case command
            when /^c\S*\s+(\w+)(?:\s+(\w+))?$/
                if $2.nil?
                    nick1 = nick
                    nick2 = $1
                else
                    nick1 = $1
                    nick2 = $2
                end
                player1 = Player.find_by_nick( nick1 )
                player2 = Player.find_by_nick( nick2 )
                if player1.nil?
                    put "#{nick1} is not a player."
                elsif player2.nil?
                    put "#{nick2} is not a player."
                else
                    success_rate = player1.success_rate( player2 )
                    if success_rate
                        put "#{nick1} wins %.1f%% of the time in battles involving #{nick2}." % [ success_rate * 100 ]
                    else
                        put "I don't think #{nick1} and #{nick2} have ever battled."
                    end
                end
            when /^eq\S*\s+(.+)$/
                # Equip an item
                
                item_code = $1.strip
                item = Item.find_by_code( item_code )
                if item.nil?
                    put "No such item '#{item_code}'."
                else
                    owned_item = player.equipment.find( :first, :conditions => [ "item_id = ?",  item.id ] )
                    if owned_item
                        owned_item.update_attribute( :equipped, true )
                        put "#{nick} equips #{item.name}."
                    else
                        put "#{nick}: You don't have any #{item.name}."
                    end
                end
                
            when /^h/
                # Help
                
                sendNotice "Commands:", player.nick
                sendNotice "eq[uip] <item code>", player.nick
                sendNotice "uneq[uip] <item code>", player.nick
                sendNotice "r[emove] <item code>", player.nick
                sendNotice "i[nventory]", player.nick
                
            when /^i/
                # Inventory listing
                
                inventory = player.equipment.collect { |eq|
                    eq.item.name + (
                        eq.equipped ? ' (equipped)' : ''
                    )
                }.join( ', ' )
                
                if inventory.empty?
                    sendNotice( "You have no items.", player.nick )
                else
                    sendNotice( inventory, player.nick )
                end
                
            when /^(?:uneq|r)\S*\s+(.+)$/
                # Unequip an item
                
                item_code = $1.strip
                item = Item.find_by_code( item_code )
                if item.nil?
                    put "No such item '#{item_code}'."
                else
                    owned_item = player.equipment.find( :first, :conditions => [ "item_id = ?",  item.id ] )
                    if owned_item
                        owned_item.update_attribute( :equipped, false )
                        put "#{nick} unequips #{item.name}."
                    else
                        put "#{nick}: You don't have any #{item.name}."
                    end
                end
                
            else
                put "Unknown command '#{command}'.  Try '!w help' for help."
        end
    end
    
    def op?( nick )
        retval = OPS.include?( nick ) && confirmRegistration( nick )
    end
    
    def opCommand( nick, userhost, handle, channel, text )
        @active_channel = channel
        if not op?( nick )
            put "#{nick}: You are not a !word operator who has identified with the network."
            return
        end
        
        command = text.strip
        case command
            when /^checkeconomy/
                total_points = 0
                players = Player.find( :all )
                players.each do |player|
                    total_points += player.rating
                end
                put "Average rating: %.2f" % [ total_points.to_f / players.length ]
            when /^clearmemo\s+(\S+)/
                nick = $1
                victim = Player.find_by_nick( nick )
                if victim != nil
                    @memo_counts[ victim.nick ] = 0
                    put "Reset memo count for #{victim.nick}."
                else
                    put "No such player, '#{nick}'"
                end                
            when /^del\S*\s+(\S+)/
                nick = $1
                victim = Player.find_by_nick( nick )
                if victim != nil
                    games_to_delete = Game.find(
                        :all,
                        :conditions => [
                            "EXISTS ( \
                                SELECT 1 \
                                FROM participations \
                                WHERE participations.game_id = games.id \
                                    AND player_id = ? \
                            ) OR \
                            games.warmup_winner = ?",
                            victim.id,
                            victim.id
                        ]
                    )
                    
                    num_games = games_to_delete.length
                    games_to_delete.each do |game|
                        Participation.delete_all(
                            [ "game_id = ?", game.id ]
                        )
                        Game.delete( game.id )
                    end
                    victim.destroy
                    put "Deleted #{nick} and #{num_games} rounds."
                else
                    put "No such player: '#{nick}'"
                end
            when /^msg\s+(.+)$/
                sendMemo nick, $1
        end
    end
    
    def sendMemo( sender, message, recipient = "Pistos" )
        $reby.putserv "PRIVMSG MemoServ :send #{recipient} <#{sender}> #{message}"
        put "Message sent to #{recipient}."
    end
    
    def listen( nick, userhost, handle, channel, args )
        return if @word.nil?
        
        $reby.log "listen_args: #{args.inspect}"
        
        text = nil
        case args
            when Array
                text = args.join( ' ' )
            when String
                text = args
            else
                text = args.to_s
        end
        checkGiveAway( nick, text )
    end
    
    def checkGiveAway( nick, text )
        if(
            @battle != nil and not @battle.players.collect{ |p| p.nick }.include?( nick ) 
        ) and text =~ @word_regexp
            @given_away_by = nick
        end
    end
    
    def reportProblem( nick, userhost, handle, channel, args )
        @active_channel = channel
        if confirmRegistration( nick )
            if @memo_counts[ nick ] >= MAX_MEMOS_PER_PLAYER
                put "#{nick}: You have sent too many memos already."
            elsif args.to_s.strip.empty?
                put "#{nick}: !wordreport <suggested new word | problem word | bug report>"
            else
                sendMemo( nick, args.to_s.strip )
            end
        else
            put "Only registered players may report things."
        end
    end
    
    def noPracticeMessage( nick, userhost, handle, channel, args )
        if @battle.nil?
            put "People are playing in #{@channel.name} right now.", channel
        else
            put "A battle is ensuing in #{@battle.channel.name} right now!", channel
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
$reby.bind( "raw", "-", "320", "registrationNotification", "$wordx" )
$reby.bind( "raw", "-", "318", "registrationCheck", "$wordx" )
$reby.bind( "pub", "-", "!wordop", "opCommand", "$wordx" )
$reby.bind( "pubm", "-", "#mathetes *", "listen", "$wordx" )
$reby.bind( "pub", "-", "!wordreport", "reportProblem", "$wordx" )
$reby.bind( "pub", "-", "!wordbuy", "buy", "$wordx" )
$reby.bind( "pub", "-", "!w", "command", "$wordx" )
