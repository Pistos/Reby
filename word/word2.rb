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
        armament = player.create_armament( :weapon_id => player.title_set.default_weapon_id )
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

class Bet
    attr_reader :bettor, :bettee, :amount
    
    def initialize( bettor, bettee, amount )
        @bettor = bettor
        @bettee = bettee
        @amount = amount
    end
end

class BattleManager
    attr_reader :state, :channel, :current_round,
        :player_teams, :king, :wins, :num_rounds, :survivors

    DEFAULT_NUM_ROUNDS = {
        'rounds' => 3,
        'lms' => 99,
    }
    BATTLE_SETUP_TIMEOUT = 300 # seconds
    MAX_TEAM_NAME_LENGTH = 32
    TOO_MANY_ROUNDS = 11
    MINIMUM_BET = 5 # gold
    BATTLE_AWARD_PER_ROUND = 10 # gold
    GAME_BINDS = {
        "rounds" => "setNumRounds",
        "join" => "addPlayer",
        "start" => "start",
        "abort" => "abort",
        "players" => "listPlayers",
        "leave" => "removePlayer",
        "team" => 'joinTeam',
        'bet' => 'bet',
        'unbet' => 'unbet',
        'bets' => 'listBets',
        'mode' => 'changeMode',
    }
    
    @@last_mode = 'lms'
    
    def initialize( channel, nick )
        @channel = Channel.find_or_create_by_name( channel )
        
        starter = find_or_create_player( nick )
        @battle = Battle.new(
            :starter => starter,
            :battle_mode => @@last_mode
        )
        
        @num_rounds = DEFAULT_NUM_ROUNDS[ @battle[ :battle_mode ] ]
        @current_round = 0
        @players = Array.new
        @survivors = Array.new # Only those playing in this and subsequent rounds
        @initial_titles = Hash.new
        @initial_money = Hash.new
        @initial_odds = Hash.new
        @player_teams = Hash.new
        @player_data = Hash.new { |hash, key| hash[ key ] = Hash.new }
        @mode = :rounds
        
        @wins = Hash.new( 0 )
        @bets = Array.new
        @results = Hash.new
        
        GAME_BINDS.each do |command, method|
            $reby.bind( "pub", "-", command, method, "$wordx.battle" )
        end
        
        $reby.utimer( BATTLE_SETUP_TIMEOUT, "timeoutGame", "$wordx.battle" )
        
        put "Mode: #{@battle[ :battle_mode ]}  Defaults: Rounds: #{@num_rounds}"
        put "Commands: " + GAME_BINDS.keys.join( '; ' )
        
        addPlayer( nick, nil, nil, channel, nil )
    end
    
    def put( text, destination = @channel.name )
        $reby.putserv "PRIVMSG #{destination} :[b] #{text}"
    end
    def sendNotice( text, destination = @channel.name )
        $reby.putserv "NOTICE #{destination} :#{text}"
    end
    
    def mode
        @battle.battle_mode
    end
    def starter
        @battle.starter
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
    
    def players
        return @players.collect! { |p| p.reload }
    end
    
    def setNumRounds( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        if @battle.battle_mode == 'lms'
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
        @survivors.each do |p|
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
    
    def setMode( mode, arg = DEFAULT_NUM_ROUNDS[ mode ] )
        okay = true
        if @battle.battle_mode != 'lms'
            old_rounds = @num_rounds
        end
        case mode
            when 'lms'
                @num_rounds = DEFAULT_NUM_ROUNDS[ mode ]
                put "Battle mode: Last Man Standing"
            when 'rounds'
                @num_rounds = old_rounds || arg.to_i
                put "Battle mode: Rounds (#{@num_rounds})"
            else
                put "Invalid game mode (#{mode})"
                okay = false
        end
        if okay
            @battle.battle_mode = mode
            @@last_mode = mode
        end
    end
    def changeMode( nick, userhost, handle, channel, text )
        mode = text.strip
        case mode
            when 'lms', 'rounds'
                setMode( mode )
            else
                put "Valid modes: lms, rounds"
        end
    end
    
    def teammates?( player1, player2 )
        return( @player_teams[ player1 ] == @player_teams[ player2 ] )
    end
    
    def joinTeam( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        team = text.strip[ 0...MAX_TEAM_NAME_LENGTH ]
        if team.empty?
            put "#{nick}: team <team name>"
            return
        end
        
        player = find_or_create_player( nick )
        includePlayer( player )
        @player_teams[ player ] = team
        if team != player.nick
            put "#{player.nick} joined Team #{team}."
        end
    end
    
    def includePlayer( player )
        included = false
        if not @players.include? player
            put "#{player.nick} has joined the game.", @channel.name
            unbet( player.nick, nil, nil, nil, nil )
            @players << player
            @player_teams[ player ] = player.nick
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
        if player == starter
            if $wordx.registered?( player )
                put "#{player.nick}: You can't leave the game, you started it.  Try the abort command."
            else
                doAbort
            end
        elsif @players.delete( player )
            put "#{nick} has withdrawn from the game."
        else
            put "#{nick}: You cannot leave what you have not joined."
        end
    end

    def listPlayers( nick, userhost, handle, channel, text )
        str = "Players: "
        str << ( @players.collect { |p|
            "L#{p.level} " +
            ( "%s (1:%.4f odds)" % [ p.nick, p.odds || 0.0 ] ) +
            (
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
        put "Looks like no one wants to play!"
        doAbort
    end
    
    def abort( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        if (
            find_or_create_player( nick ) != starter and
            $reby.onchan( starter.nick )
        )
            put "Only the person who invoked the battle can abort it."
            return
        end

        doAbort
    end
    
    def doAbort
        unbindSetupBinds
        bettors = Set.new
        @bets.each do |bet|
            bettors << bet.bettor
        end
        bettors.each do |bettor|
            unbet( bettor.nick, nil, nil, nil, nil )
        end
        put "Game aborted."
        $wordx.abortBattle
    end
    
    def start( nick, userhost, handle, channel, text )
        return if channel != @channel.name
        
        if find_or_create_player( nick ) != starter
            put "Only the person who invoked the battle can start it."
            $reby.log starter.inspect
            return
        end
        
        if @players.length < 2
            put "At least two players need to be in the game."
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
        
        # Good to go!
        
        begin
            @battle.save!
        rescue RecordNotSaved => e
            put "Eep!  Couldn't save battle record!"
        end

        unbindSetupBinds

        @current_round = 1
        @initial_ranking = $wordx.ranking
        @players.each do |player|
            @initial_titles[ player ] = player.title
            @initial_money[ player ] = player.money
            @initial_odds[ player ] = player.odds
            @survivors << player
            @player_data[ player ][ :hp ] = player.max_hp
        end
        
        $wordx.oneRound( nil, nil, nil, @channel.name, nil )
    end
    
    def eliminate( player )
        @survivors.delete( player )
        put "#{player.nick} has been knocked out of contention!"
    end
    
    def addWin( player )
        @wins[ player ] += 1
    end
    def << ( game )
        @battle.games << game
        @battle.save
    end
    
    def finalise
        calculateResults
        @battle.save
        settleBets
        report
    end
    
    def calculateResults
        final_ranking = $wordx.ranking
        final_titles = Hash.new
        final_money = Hash.new
        players.each do |player|
            final_titles[ player ] = player.title
            final_money[ player ] = player.money
        end
        if @survivors.size > 1 and teams.size < @survivors.size
            @results[ :winning_team ] = @player_teams[ @survivors[ 0 ] ]
        end
        
        players.each do |player|
            @results[ player ] = Hash.new
            
            @results[ player ][ :initial_rank ], @results[ player ][ :initial_score ] = @initial_ranking.rank_and_score( player )
            @results[ player ][ :initial_score ] ||= 0
            @results[ player ][ :initial_title ] = @initial_titles[ player ]
            @results[ player ][ :initial_money ] = @initial_money[ player ] || 0
            
            @results[ player ][ :final_rank ], @results[ player ][ :final_score ] = final_ranking.rank_and_score( player )
            @results[ player ][ :final_score ] ||= 0
            @results[ player ][ :final_title ] = final_titles[ player ]
            @results[ player ][ :final_money ] = final_money[ player ] || 0
        end
        
        # Determine battle victor
        
        win_counts = Hash.new( 0 )
        @battle.games.each do |game|
            game.participations.each do |par|
                if par.points_awarded != nil and par.points_awarded > 0
                    win_counts[ par.player ] += 1
                    break
                end
            end
        end
        winningest_players = Array.new
        high_wins = 0
        win_counts.each do |player, wins|
            if wins > high_wins
                high_wins = wins
                winningest_players = [ player ]
            elsif wins == high_wins
                winningest_players << player
            end
        end
        
        @battle_victor = winningest_players[ 0 ]
        if winningest_players.size > 1
            # We must resolve the tie.
            
            winningest_players[ 1..-1 ].each do |player|
                r = @results[ player ]
                w = @results[ @battle_victor ]
                
                score_delta = r[ :final_score ] - r[ :initial_score ]
                w_score_delta = w[ :final_score ] - w[ :initial_score ]
                
                if score_delta > w_score_delta
                    # Tie broken by point gain.
                    @battle_victor = player
                elsif score_delta == w_score_delta
                    if r[ :final_score ] > w[ :final_score ]
                        # Tie broken by final score.
                        @battle_victor = player
                    elsif r[ :final_score ] == w[ :final_score ]
                        if r[ :initial_score ] > w[ :initial_score ]
                            # Tie broken by initial score.
                            @battle_victor = player
                        else
                            # Tie broken by random chance?
                            put "? Tie between #{player.nick} and #{@battle_victor.nick}?"
                        end
                    end
                end
            end
        end

        # Reward battle victor.
        
        award = BATTLE_AWARD_PER_ROUND * @battle.games.length
        @battle_victor.money += award
        @battle_victor.save
        @results[ @battle_victor ][ :final_money ] += award
    end
        
    def report
        report_text = "Battle over.  #{@battle_victor.nick} is the battle victor!"
        
        if @results[ :winning_team ]
            report_text << "  Team #{@results[ :winning_team ]} won!"
        end
        
        players.each do |player|
            terminal_punctuation = '.'
            sentence = [ ]
            
            r = @results[ player ]
            score_delta = r[ :final_score ] - r[ :initial_score ]
            
            if score_delta > 0
                sentence << "gained #{score_delta} points"
                if r[ :initial_title ] != r[ :final_title ]
                    sentence << "\002GAINED A LEVEL, advancing from #{r[ :initial_title ]} to #{r[ :final_title ]}\002"
                    terminal_punctuation = '!'
                end
                if r[ :initial_rank ] != nil and r[ :final_rank ] < r[ :initial_rank ]
                    sentence << "rose from ##{r[ :initial_rank ]} to ##{r[ :final_rank ]}"
                    terminal_punctuation = '!'
                end
            elsif score_delta < 0
                sentence << "lost #{-score_delta} points"
                if r[ :initial_title ] != r[ :final_title ]
                    sentence << "get demoted from #{r[ :initial_title ]} to #{r[ :final_title ]}"
                    terminal_punctuation = '!'
                end
                if r[ :initial_rank ] != nil and r[ :final_rank ] > r[ :initial_rank ]
                    sentence << "fell from ##{r[ :initial_rank ]} to ##{r[ :final_rank ]}"
                    terminal_punctuation = '!'
                end
            end
            money_delta = r[ :final_money ] - r[ :initial_money ]
            if money_delta > 0
                sentence << "gained #{money_delta} #{WordX::CURRENCY}"
            elsif money_delta < 0
                sentence << "incurred a net loss of #{-money_delta} #{WordX::CURRENCY}"
            end
            report_text << "  #{player.nick} " << sentence.join( ' and ' ) << terminal_punctuation
        end
        
        put report_text
        
        report_text = ''
        @winnings.each do |w|
            report_text << "#{w[ :bet ].bettor.nick} won #{w[ :amount ]} #{WordX::CURRENCY} for betting on #{w[ :bet ].bettee.nick}.  "
        end
        @losings.each do |l|
            report_text << "#{l.bettor.nick} lost #{l.amount} #{WordX::CURRENCY} for betting on #{l.bettee.nick}.  "
        end
        if not report_text.empty?
            put report_text
        end
    end
    
    def bet( nick, userhost, handle, channel, text )
        bettor = Player.find_by_nick( nick )
        if bettor.nil?
            put "#{nick}: You don't have any money to bet!"
            return
        end
        if players.include?( bettor )
            put "#{nick}: You can't wager if you're in the battle!"
            return
        end
        
        if text !~ /^\s*(\d+)\s+(?:on\s+)?(\S+)\s*$/
            put "Syntax: bet <amount> [on] <player>"
            return
        end
        
        amount = $1.to_i
        bettee_nick = $2
        
        if amount < MINIMUM_BET
            put "The minimum bet is #{MINIMUM_BET} #{WordX::CURRENCY}."
            return
        end
        
        bettee = @players.find { |b| b.nick == bettee_nick }
        
        if bettee.nil?
            put "There is no player by the name of '#{bettee_nick}'."
            return
        elsif bettee.odds.nil?
            put "You cannot bet on new players."
            return
        end
        
        if not bettor.debit( amount )
            put "#{nick}: You don't have that kind of money!"
            return
        end
        
        @bets << Bet.new( bettor, bettee, amount )
        
        put "#{bettor.nick} has bet #{amount} #{WordX::CURRENCY} on #{bettee.nick}."
    end
    
    def unbet( nick, userhost, handle, channel, text )
        bettor = Player.find_by_nick( nick )
        if bettor.nil?
            put "#{nick}: You're not even a character in the realm!"
            return
        end
        
        credit_amount = 0
        to_delete = []
        @bets.each do |bet|
            if bet.bettor == bettor
                bettor.credit bet.amount
                credit_amount += bet.amount
                to_delete << bet
            end
        end
        @bets.delete_if { |bet|
            to_delete.include? bet
        }
        
        if credit_amount > 0
            put "#{bettor.nick} has withdrawn all bets.  (#{credit_amount} #{WordX::CURRENCY} total)"
        end
    end
    
    def settleBets
        @winnings = []
        @losings = []
        @bets.each do |bet|
            if bet.bettee == @battle_victor
                amount_won = ( bet.amount * @initial_odds[ @battle_victor ] ).to_i
                @winnings << { :bet => bet, :amount => amount_won - bet.amount }
                bet.bettor.credit( amount_won )
            else
                @losings << bet
            end
        end
    end
    
    def listBets( nick, userhost, handle, channel, text )
        bets = []
        @bets.each do |bet|
            bets << "#{bet.bettor.nick} #{bet.amount} on #{bet.bettee.nick}"
        end
        put bets.join( '; ' )
    end
    
    def injure( victim, damage )
        @player_data[ victim ][ :hp ] -= damage
        if @player_data[ victim ][ :hp ] <= 0
            eliminate( victim )
        else
            put( "HP: " + @survivors.collect { |s| "#{s.nick}: #{@player_data[ s ][ :hp ]}" }.join( '  ' ) )
            #put "#{victim.nick} has #{@player_data[ victim ][ :hp ]} HP left."
        end
    end
end

class WordX
    attr_reader :battle
    
    VERSION = '2.5.2'
    LAST_MODIFIED = 'May 25, 2006'
    
    DEFAULT_INITIAL_POINT_VALUE = 100
    INCLUDE_PLAYERS_WITH_NO_GAMES = true
    MONETARY_AWARD_FRACTION = 0.25
    GIVE_AWAY_REDUCTION = 0.10
    PARTICIPATION_AWARD = 5 # gold
    CLUE4_FRACTION = 0.70
    CLUE5_FRACTION = 0.40
    CLUE6_FRACTION = 0.15
    CONFIRMATION_TIMEOUT = 5 # seconds
    MAX_MEMOS_PER_PLAYER = 3
    
    UNSOLVED_MESSAGES = [
        "The word sinks back into the roiling vat of molten glyph metal...",
        "The word descends back into the depths of the dark word ocean...",
    ]
    
    def initialize
        @channel = nil
        @word = nil
        @game = nil

        @registered_players = Hash.new
        @registration_check_pending = Hash.new
        @memo_counts = Hash.new( 0 )
        
        connect_to_db
        
        @item_glass_shield = Item.find_by_code( 'gs' )
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
        
        unbindPracticeCommand        
        
        if @battle.nil?
            @word = PracticeWord.random
        else
            @word = BattleWord.random
        end
        
        if @word.nil?
            put "Error: Failed to fetch word!"
            bindPracticeCommand        
            return
        end

        @channel = Channel.find_or_create_by_name( channel )
        @game = Game.create( { :word_id => @word.id, :start_time => Time.now } )
        @initial_point_value = DEFAULT_INITIAL_POINT_VALUE
        if @word.word.length < 6
            @initial_point_value = ( @initial_point_value * ( @word.word.length.to_f / 6 ) ).to_i
        end
        @given_away_by = nil
        @word_regexp = Regexp.new( @word.word.split( // ).join( ".*" ) )
        
        if @battle != nil
            @battle << @game
            @adjustment = Hash.new
            @battle.survivors.each do |player|
                partic = Participation.new(
                    :player_id => player.id,
                    :game_id => @game.id,
                    :team => @battle.player_teams[ player ]
                )
                @game.participations << partic
                @adjustment[ player ] = player.point_adjustment( @battle.players )
            end
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
        putquick "Unscramble ... \002#{mixed_word}\002         #{round_str}"
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
            put "#{STATS_SITE}/player/view?id=#{player.id}"
            put "\002#{player.nick}\002, \002#{player.title}\002 (L\002#{player.level}\002) - Battle points: \002#{player.bp}\002 (Rank: \002##{rank}\002) Skill: %+.1f  #{player.money} #{CURRENCY}, #{player.games_played} rounds;  odds: #{player.odds_string('')} (1:%.4f)" % [ ( player.awpd || 0.0 ) * 100, player.odds || 0.0 ]
        else
            put "#{nick}: You're not a #{BANG_COMMAND} warrior!  Play a #{BANG_COMMAND}battle."
        end
    end
    
    # Returns an array of [Player,bp] subarrays.
    def ranking( include_players_with_no_games = false )
        bps = Hash.new
        Player.find( :all ).each do |player|
            if player.games_played > 0 or include_players_with_no_games
                bps[ player ] = player.bp
            end
        end
        
        return bps.sort { |a,b| b[ 1 ] <=> a[ 1 ] }
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
        
        put STATS_SITE
        
        num_to_show, start_rank, end_rank = printing_parameters( text )
        
        num_shown = 0
        index = 0
        r = ranking
        r.each do |player, bp|
            index += 1
            next if index < start_rank
            
            put( "%2d. %-32s %-5s %5d" % [ index, "#{player.nick}, #{player.title}", "(L#{player.level})", bp ] )
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
        $reby.unbind( "pub", "-", "#{BANG_COMMAND}", "noPracticeMessage", "$wordx" )
        $reby.bind( "pub", "-", "#{BANG_COMMAND}", "oneRound", "$wordx" )
    end
    def unbindPracticeCommand
        $reby.unbind( "pub", "-", "#{BANG_COMMAND}", "oneRound", "$wordx" )
        $reby.bind( "pub", "-", "#{BANG_COMMAND}", "noPracticeMessage", "$wordx" )
    end
    
    def highest_loser( winner )
        highest_opponent_rating = -1
        loser = nil
        
        opponents = winner.opponents( @game )
        @game.participations.each do |participation|
            player = Player.find( participation.player_id )
            next if player == winner
            
            player_rating = winner.success_rate( opponents ) || 0
            if player_rating > highest_opponent_rating
                highest_opponent_rating = player_rating
                loser = participation.player
            end
        end
        
        return loser
    end
    
    def correctGuess( nick, userhost, handle, channel, text )
        @active_channel = channel
        
        # Validity checks:
        
        return if @already_guessed or ( @game != nil and @game.end_time != nil )
        
        winner = find_or_create_player( nick )
        return if winner.nil?
        
        if @battle != nil and not @game.participations.find_by_player_id( winner.id )
            sendNotice( "Since you are not a surviving player, your guesses are not counted.", winner.nick )
            @given_away_by = nick
            return
        end
        
        # -----

        @already_guessed = true

        killTimers
        $reby.unbind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        
        @game.end_time = Time.now
        
        put "#{winner.nick} got it ... #{@word.word}"
        
        damage = ( @point_value.to_f / DEFAULT_INITIAL_POINT_VALUE * BASE_WEAPON_DAMAGE ).to_i
        armament = winner.armament
        if armament
            damage += armament.modifier
        end
        
        if @given_away_by != nil
            put "Since #{@given_away_by} gave the answer away, the award is reduced."
            @point_value = ( @point_value * GIVE_AWAY_REDUCTION ).to_i
        end
        
        winner_award = @point_value
        if @battle.nil?
            winner.update_attribute( :warmup_points, winner.warmup_points + winner_award )
            @game.warmup_winner = winner.id
            
            if winner.warmup_points > MAX_WARMUP_POINTS
                put "#{winner.nick} has exceeded #{MAX_WARMUP_POINTS} practice points!  Congratulations!  Practice scores have been reset."
                Player.update_all "warmup_points = 0"
            end
        else
            # Determine person struck.
            
            loser = nil
            case @battle.mode
                when 'lms'
                    @battle.addWin( winner )
                    loser = winner.select_target( @game )
                    if loser.nil?
                        loser = highest_loser( winner )
                    end
                    if loser
                        protection = loser.protection
                        if protection
                            damage += protection.modifier
                            if damage < 0
                                damage = 0
                            end
                        end
                        put "#{winner.nick} strikes #{loser.nick} for #{damage} damage!"
                        @battle.injure( loser, damage )
                    else
                        put "?? #{winner.nick} swings at empty air??"
                    end
            end
            
            winner_award = ( @point_value * @adjustment[ winner ] ).to_i
        end

        put "... for #{winner_award} points."
        
        # Record score.
        
        @game.participations.each do |p|
            monetary_award = 0
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
        @game.end_time = Time.now
        #put "No one solved it in time.  The word was #{@word.word}."
        put "No one solved it in time.  " + UNSOLVED_MESSAGES[ rand( UNSOLVED_MESSAGES.length ) ]
        $reby.unbind( "pub", "-", @word.word, "correctGuess", "$wordx" )
        endRound
    end
    
    def endRound
        @game.participations.each do |p|
            player = p.player
            player.money += PARTICIPATION_AWARD
            player.save
        end
        
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
                
                @battle.finalise
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
                        @battle.players.collect { |p| p.nick }.join(', ') + ".",
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
        @battle = BattleManager.new( channel, nick )
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
        put "#{STATS_SITE}/title/list"
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
                put "#{nick}: You are not a player.  Join a #{BANG_COMMAND}battle first."
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
        command( nick, userhost, handle, channel, 'b ' + text )
    end
    
    def sellItem( player, item )
        cost = item.price
        if player.debit( cost )
            player.equipment.create( :item_id => item.id )
            put "#{player.nick} purchased a new #{item.name} for #{cost} #{CURRENCY}."
        else
            put "#{player.nick}: #{item.name.pluralize} cost #{cost} #{CURRENCY}; you haven't got that much!"
        end
    end
    def sellWeapon( player, weapon )
        cost = weapon.price
        if player.debit( cost )
            if player.armament
                player.armament.weapon = weapon
                player.save
            else
                armament = player.create_armament( :weapon_id => weapon.id )
            end
            put "#{player.nick} purchased a new #{weapon.name} for #{cost} #{CURRENCY}."
        else
            put "#{player.nick}: #{weapon.name.pluralize} cost #{cost} #{CURRENCY}; you haven't got that much!"
        end
    end
    def sellArmour( player, armour )
        cost = armour.price
        if player.debit( cost )
            if player.protection
                player.protection.armour = armour
                player.save
            else
                protection = player.create_protection( :armour_id => armour.id )
            end
            put "#{player.nick} purchased a new #{armour.name} for #{cost} #{CURRENCY}."
        else
            put "#{player.nick}: #{armour.name.pluralize} cost #{cost} #{CURRENCY}; you haven't got that much!"
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
        if USE_NICKSERV
            @registered_players[ player ] = false
            $reby.putserv "WHOIS #{player.nick}"
        else
            @registered_players[ player ] = true
            @registration_check_pending[ player ] = false
        end
    end
    
    def confirmRegistration( nick )
        return true if not USE_NICKSERV
        
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
            put "#{nick}: You are not a player.  Fight in a #{BANG_COMMAND}battle first."
            return
        end
        
        command = text.strip
        case command
            when /^b\S*\s*(.*)$/
                arg = $1
                
                item = Item.find_by_code( arg )
                weapon = Weapon.find_by_code( arg )
                armour = Armour.find_by_code( arg )
                if item != nil
                    if player.under_limit?( item )
                        sellItem( player, item )
                    else
                        put "#{nick}: You may not have more than #{item.ownership_limit} #{item.ownership_limit > 1 ? item.name.pluralize : item.name}"
                    end
                elsif weapon != nil
                    sellWeapon( player, weapon )
                elsif armour != nil
                    sellArmour( player, armour )
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
                            (
                                Item.find( :all ).collect { |item| item.code } +
                                Weapon.find( :all ).collect { |weapon| weapon.code } +
                                Armour.find( :all ).collect { |armour| armour.code }
                            ).join( ', ' )
                        )
                    )
                end
                
            when /^c\S*(?:\s+(\S+))+$/
                nicks = Array.new
                command.scan( /\s+(\S+)/ ) do |s|
                    nicks << s[ 0 ]
                end
                if nicks.length == 1
                    nicks.unshift nick
                end
                players = Array.new
                nicks.each do |n|
                    player = Player.find_by_nick( n )
                    if player.nil?
                        put "'#{n}' is not a player."
                    else
                        players << player
                    end
                end
                if not players.empty?
                    $stderr.puts players.inspect
                    success_rate = players[ 0 ].success_rate( players )
                    if success_rate
                        player_list = players[ 1..-1 ].collect { |p| p.nick }.join( ', ' )
                        put "#{players[ 0 ].nick} wins %.1f%% of the time in battles against #{player_list}." % [ success_rate * 100 ]
                    else
                        player_list = players.collect { |p| p.nick }.join( ', ' )
                        put "I don't think #{player_list} have ever battled."
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
                sendNotice "t[arget] <player> <priority>", player.nick
                
            when /^i/
                # Inventory listing
                
                if player.armament
                    weapon = player.armament.name
                end
                if player.protection
                    armour = player.protection.name
                end
                inventory = (
                    player.equipment.collect { |eq|
                        eq.item.name + (
                            eq.equipped ? ' (equipped)' : ''
                        )
                    } + [ weapon ] + [ armour ]
                ).compact.join( ', ' )
                
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
                
            when /^t\S*$/
                if player.targettings.empty?
                    put "You have no targets setup."
                else
                    put(
                        player.targettings.collect { |t| t.target.nick + ' ' + t.ordinal.to_s }.join( ', ' )
                    )
                end
            when /^t\S*(?:\s+(\S+)\s+(-?\d+))+$/
                command.scan( /(\S+)\s+(-?\d+)/ ) do |match|
                    victim_nick = $1
                    ordinal = $2.to_i
                    if player.setup_target( victim_nick, ordinal )
                        put "#{player.nick} is now targetting #{victim_nick} with priority #{ordinal}."
                    else
                        put "No such player: '#{victim_nick}'"
                    end
                end
            else
                put "Unknown command '#{command}', or invalid syntax.  Try '#{SHORT_BANG_COMMAND} help' for help."
        end
    end
    
    def op?( nick )
        retval = OPS.include?( nick ) && confirmRegistration( nick )
    end
    
    def opCommand( nick, userhost, handle, channel, text )
        @active_channel = channel
        if not op?( nick )
            put "#{nick}: You are not a #{BANG_COMMAND} operator who has identified with the network."
            return
        end
        
        command = text.strip
        case command
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
            when /^mix/
                put "Rebuilding and randomizing word lists..."
                ActiveRecord::Base.connection.select_one(
                    "SELECT rebuild_battle_words()"
                )
                put "... finished word list rebuild."
            when /^msg\s+(.+)$/
                sendMemo nick, $1
            when /^test(\s+\S+)+/
                put "bleh"
        end
    end
    
    def sendMemo( sender, message, recipient = "Pistos" )
        $reby.putserv "PRIVMSG MemoServ :send #{recipient} <#{sender}> #{message}"
        put "Message sent to #{recipient}."
    end
    
    def listen( nick, userhost, handle, channel, args )
        return if @word.nil?
        
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
                put "#{nick}: #{BANG_COMMAND}report <suggested new word | problem word | bug report>"
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

load 'wordbattle.conf'

$wordx = WordX.new

$wordx.bindPracticeCommand
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}battle", "setupGame", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}score", "printScore", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}rating", "printRating", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}rank", "printRanking", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}ranking", "printRanking", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}class", "setCharacterClass", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}classes", "listCharacterClasses", "$wordx" )
$reby.bind( "raw", "-", "320", "registrationNotification", "$wordx" )
$reby.bind( "raw", "-", "318", "registrationCheck", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}op", "opCommand", "$wordx" )
$reby.bind( "pubm", "-", "#mathetes *", "listen", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}report", "reportProblem", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::BANG_COMMAND}buy", "buy", "$wordx" )
$reby.bind( "pub", "-", "#{WordX::SHORT_BANG_COMMAND}", "command", "$wordx" )
