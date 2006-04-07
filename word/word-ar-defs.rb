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

class BattleWord < ActiveRecord::Base
    def BattleWord::random
        retval = nil
        
        w = BattleWord.find( :first )
        
        if w != nil
            retval = Word.find( w.word_id )
        end
        
        return retval
    end
end
class PracticeWord < ActiveRecord::Base
    def PracticeWord::random
        retval = nil
        
        w = PracticeWord.find( :first, :order => 'random()' )
        
        if w != nil
            retval = Word.find( w.word_id )
        end
        
        return retval
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
    has_many :equipment
    
    def games_played( days = nil )
        num_games = nil
        days = days.to_i
        if days < 1
            days = 99999
        end
        p = Participation.find_by_sql [
            " \
                select count(*) as num_games \
                from participations, games \
                where participations.player_id = ? \
                    AND participations.game_id = games.id \
                    AND games.end_time > NOW() - '? days'::INTERVAL \
            ",
            id,
            days
        ]
        if not p.empty?
            num_games = p[ 0 ][ 'num_games' ].to_i
        end
        return num_games
    end
    
    def rating( days = nil )
        points = BASE_RATING
        days = days.to_i
        g = nil
        if days > 0
            g = Participation.find_by_sql [
                " \
                    select sum( participations.points_awarded ) as rating \
                    from participations, games \
                    where player_id = ? \
                        AND participations.game_id = games.id \
                        AND games.end_time > NOW() - '? days'::INTERVAL \
                ",
                id,
                days
            ]
        else
            g = Participation.find_by_sql [
                " \
                    select sum( points_awarded ) as rating \
                    from participations \
                    where player_id = ? \
                ",
                id
            ]
        end
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
    
    def credit( amount )
        update_attribute( :money, money + amount )
    end
    
    def icon
        if rating <= BASE_RATING
            the_icon = title_set.icons[ 0 ]
        else
            the_icon = title_set.icons[ 1 ]
        end
        
        return the_icon
    end
    
    def time_of_last_battle
        p = Game.find(
            :first,
            :include => [ :participations ],
            :conditions => [
                "participations.player_id = ? AND participations.game_id = games.id AND games.end_time IS NOT NULL",
                id
            ],
            :order => 'games.end_time DESC'
        )
        if p != nil
            return p.end_time
        else
            return nil
        end
    end
    def time_of_last_victory
        p = Game.find(
            :first,
            :include => [ :participations ],
            :conditions => [
                "participations.player_id = ? AND \
                 participations.game_id = games.id AND \
                 participations.points_awarded > 0 AND \
                 games.end_time IS NOT NULL",
                id
            ],
            :order => 'games.end_time DESC'
        )
        if p != nil
            return p.end_time
        else
            return nil
        end
    end
    
    def under_limit?( item )
        num_owned = Equipment.count( [
            "item_id = ? AND player_id = ?",
            item.id,
            id
        ] )
        return( num_owned < item.ownership_limit )
    end
    
    def success_rate( opponent )
        rate = nil
        sql = <<-EOS
            SELECT
                (
                    SELECT COUNT(*) from (
                        select distinct game_id from participations where player_id = ? and points_awarded > 0
                        intersect
                        select distinct game_id from participations where player_id = ?
                    ) AS bar
                )::FLOAT
                /
                (
                    SELECT COUNT(*) from (
                        select distinct game_id from participations where player_id = ?
                        intersect
                        select distinct game_id from participations where player_id = ?
                    )  AS foo
                )::FLOAT
                AS success_rate
            ;
        EOS
        begin
            result = Participation.find_by_sql( [ sql, id, opponent.id, id, opponent.id ] )[ 0 ]
            if result
                rate = result[ 'success_rate' ].to_f
            end
        rescue Exception => e
            # ignore
        end
        return rate
    end
    
    #def easiest_opponent
        #Players.find( :all ).each do |player|
            #next if player == self
            
            
        #end
    #end
    
    def num_words_contributed
        return Word.count( [ "suggester = ?", id ] )
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

class Item < ActiveRecord::Base
end

class Equipment < ActiveRecord::Base
    belongs_to :player
    belongs_to :item
end

