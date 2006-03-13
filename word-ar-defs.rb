require 'active_record'

class Word < ActiveRecord::Base
end

class Game < ActiveRecord::Base
    has_and_belongs_to_many :players
    
    attr_reader :attributes
end

class Player < ActiveRecord::Base
    has_and_belongs_to_many :games
    
    BASE_RATING = 2000
    
    def games_played
        result = Player.find_by_sql [
            " \
                SELECT COUNT( game_id ) AS num_games
                FROM games_players
                WHERE player_id = ?
            ",
            id
        ]
        if result != nil
            return result[ 0 ].num_games.to_i
        else
            return nil
        end
    end
    
    def rating
        points = BASE_RATING
        
        # Add wins ...
        g = Game.find_by_sql [
            " \
                select sum( games.points_awarded ) as rating \
                from games, games_players \
                where \
                    games.winner = ? \
                    and games.id = games_players.game_id \
                    and games_players.player_id = games.winner \
                group by games.winner",
            id
        ]
        if not g.nil? and not g.empty?
            points += g[ 0 ].rating.to_i
        end
        
        # Subtract losses...
        g = Game.find_by_sql [
            " \
                select sum( games.points_awarded ) as rating \
                from games, games_players \
                where \
                    games.winner <> ? \
                    and games.id = games_players.game_id \
                    and games_players.player_id = ? \
                group by games_players.player_id",
            id,
            id
        ]
        if not g.nil? and not g.empty?
            points -= g[ 0 ].rating.to_i
        end
        
        return points
    end
end

class Channel < ActiveRecord::Base
end