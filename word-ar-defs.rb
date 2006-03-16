require 'active_record'

class Word < ActiveRecord::Base
    def Word::random
        return Word.find(
            :first,
            :order => 'RANDOM()',
            :limit => 1
        )
    end
    
    def mixed
        return word.split(//).sort_by{rand}.join
    end
end

class Game < ActiveRecord::Base
    has_many :participations
end

class Player < ActiveRecord::Base
    BASE_RATING = 2000
    
    has_many :participations
    
    def games_played
        return Participation.count( "player_id = #{id}" )
    end
    
    def rating
        points = BASE_RATING
        
        g = Participation.find_by_sql [
            " \
                select sum( points_awarded ) as rating \
                from participations \
                where player_id = ? \
            ",
            id
        ]
        if not g.nil? and not g.empty?
            points += g[ 0 ].rating.to_i
        end
        
        return points
    end
    
    def title
        retval = nil
        t = Title.find_by_sql [
            " \
                select titles.text, points \
                from title_levels, titles \
                where \
                    title_levels.id = titles.title_level_id \
                    and title_levels.points <= ? \
                    and title_set_id = 1 \
                order by points desc \
                limit 1",
            rating
        ]
        if not t.nil?
            retval = t[ 0 ].text
        end
        return retval
    end
end

class Participation < ActiveRecord::Base
    belongs_to :game
end

class Channel < ActiveRecord::Base
end

class Title < ActiveRecord::Base
end

class TitleSet < ActiveRecord::Base
end

class TitleLevel < ActiveRecord::Base
end