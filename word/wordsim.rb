#!/usr/bin/env ruby

class Player
    BASE_RATING = 2000
    PLAYER_PROXIMITY = 0.05
    
    attr_reader :skill, :nick
    attr_accessor :rating
    
    def initialize( nick, skill )
        @nick = nick
        @rating = BASE_RATING
        @skill = skill  # from 0.0 to 1.0
    end
    
    def agree_to_play?( opponent )
        # A player would be willing to play the nearest +/- 5% of players.
        return (
            @skill > opponent.skill - ( $simulator.skill_delta ) * ( $simulator.num_players * PLAYER_PROXIMITY )
        )
    end
end

class Game
    FRACTIONS = [
        1.0,
        0.95,
        0.9,
        0.85,
        0.7,
        0.4,
        0.15,
    ]
    
    def initialize( p1, p2 )
        @p1 = p1
        @p2 = p2
    end
    
    def run
        outcome = rand * ( @p1.skill + @p2.skill )
        initial_point_value = 100
        
        point_value = ( initial_point_value * FRACTIONS[ rand( FRACTIONS.length ) ] ).to_i
        
        if outcome < @p1.skill
            # Player 1 won
            award = ( point_value * ( @p2.rating / @p1.rating ) ).to_i
            @p1.rating += award
            @p2.rating -= award
        else
            # Player 2 won
            award = ( point_value * ( @p1.rating / @p2.rating ) ).to_i
            @p2.rating += award
            @p1.rating -= award
        end
    end
end

class Simulator
    attr_reader :num_players, :skill_delta
    
    def initialize
        @num_players = 100
        @num_rounds = 100000
        @skill_delta = 1.0 / @num_players 
    end
    
    def run
        @players = []
        @num_players.times do |i|
            @players << Player.new( "Player #{i}", @skill_delta * i )
        end
        
        @num_rounds.times do |round|
            
            # Look for two random opponents.
            
            p1 = nil
            p2 = nil
            loop do
                p1 = @players[ rand( @players.size ) ]
                p2 = @players[ rand( @players.size ) ]
                if p1 != p2
                    if p1.agree_to_play?( p2 ) and p2.agree_to_play?( p1 )
                        # We found our opponents.
                        break
                    end
                end
            end
            
            # FIGHT!
            
            Game.new( p1, p2 ).run
            
            if round % 1000 == 0
                $stdout.printf( "." ); $stdout.flush
            end
        end
        
        # Print final scoreboard.
        
        players = @players.sort { |p1,p2| p2.rating <=> p1.rating }
        
        puts
        players.each_with_index do |player,index|
            puts "%-20s %d" % [ player.nick, player.rating ]
        end
    end
end

if $PROGRAM_NAME == __FILE__
    $simulator = Simulator.new
    $simulator.run
end