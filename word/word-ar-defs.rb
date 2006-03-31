if __FILE__ =~ /word-ar-defs.rb/
    require 'rubygems'
    require_gem 'activerecord', '<= 1.13.2'
    if $reby != nil
        $reby.log "ActiveRecord <= 1.13.2"
    end
else
    require 'active_record'
    if $reby != nil
        $reby.log "ActiveRecord > 1.13.2"
    end
end

class Word < ActiveRecord::Base
    NOT_PRACTICE = false
    PRACTICE = true
    
    def Word::random( practice = NOT_PRACTICE )
        retval = nil
        
        if practice
            w = Word.find_by_sql( " \
                SELECT * \
                FROM word_frequency \
                WHERE times_used > 0 \
                ORDER BY random() \
                limit 1 \
            " )
        else
            w = Word.find_by_sql( " \
                SELECT * \
                FROM word_frequency \
                ORDER BY times_used, random() \
                limit 1 \
            " )
        end
        
        if w != nil and not w.empty?
            retval = Word.find( w[ 0 ].id )
        end
        return retval
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
    MAX_WINS_PER_HOUR = 3
    
    has_many :participations
    belongs_to :title_set
    
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
    
    def save_rating_records
        r = rating
        if r > highest_rating
            update_attribute( :highest_rating, r )
        elsif r < lowest_rating
            update_attribute( :lowest_rating, r )
        end
    end
    
    def title
        retval = nil
        t = Title.find_by_sql [
            " \
                select titles.text \
                from titles \
                where \
                    title_level_id <= ? \
                    and title_set_id = ? \
                order by title_level_id desc \
                limit 1 \
                ",
            level,
            title_set_id
        ]
        if not t.nil? and not t.empty?
            retval = t[ 0 ].text
        end
        return retval
    end
    
    def level
        retval = nil
        t = TitleLevel.find_by_sql [
            " \
                select id, points \
                from title_levels \
                where \
                    points <= ? \
                order by points desc \
                limit 1",
            rating
        ]
        if not t.nil?
            retval = t[ 0 ].id
        end
        return retval
    end
    
    def winning_too_much?
        return false
        #count = Game.count( [ "warmup_winner = ? AND end_time > NOW() - '1 hour'::INTERVAL", id ] )
        #return( count >= MAX_WINS_PER_HOUR )
    end
    
    #def save
        #$reby.log "Saving: #{inspect}"
        #$reby.log caller.join( "\n\t" )
        #super
    #end
    
    # Returns true if the amount was successfully debited from the player's money.
    # Returns false if the player has insufficient funds.
    def debit( amount )
        debitted = false
        if money >= amount
            update_attribute( :money, money - amount )
            debitted = true
        end
        return debitted
    end
    
    def icon
        if rating <= BASE_RATING
            the_icon = title_set.icons[ 0 ]
        else
            the_icon = title_set.icons[ 1 ]
        end
        
        return the_icon
    end
end

class Participation < ActiveRecord::Base
    belongs_to :game
    
    def player
        return Player.find( player_id )
    end
end

class Channel < ActiveRecord::Base
end

class Title < ActiveRecord::Base
    belongs_to :title_level
end

class TitleSet < ActiveRecord::Base
    has_many :titles, :order => 'title_level_id'
    has_many :players
    
    def icons
        retval = []
        file_prefix = name.downcase.gsub( / /, '-' )
        retval << file_prefix + "1"
        retval << file_prefix + "2"
    end
end

class TitleLevel < ActiveRecord::Base
    has_many :titles
end