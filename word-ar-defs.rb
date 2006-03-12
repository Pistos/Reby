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
    
    def rating
        points = 0
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
            points = g[ 0 ].rating.to_i
        end
        
        return BASE_RATING + points
    end
end

class Channel < ActiveRecord::Base
end