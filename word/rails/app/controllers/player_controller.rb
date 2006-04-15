class PlayerController < ApplicationController
    layout 'standard'
    
    def index
        redirect_to :action => 'list'
    end
    
    def list
        days = params[ 'days' ].to_i
        @players = Player.find( :all )
        @players.delete_if { |p|
            p.games_played( days ) < 1 ||
            p.success_rate == 0.0
        }
        case params[ :sort ]
            when 'rounds'
                @players.sort! { |p1,p2| p2.games_played( days ) <=> p1.games_played( days ) }
            when 'money'
                @players.sort! { |p1,p2| p2.money <=> p1.money }
            when 'nick'
                @players.sort! { |p1,p2| p1.nick.downcase <=> p2.nick.downcase }
            when 'bp'
                @players.sort! { |p1,p2| p2.bp( days ) <=> p1.bp( days ) }
            when 'winp'
                @players.sort! { |p1,p2| p2.success_rate <=> p1.success_rate }
            when 'awpd'
                @players.sort! { |p1,p2| p2.awpd( days ) <=> p1.awpd( days ) }
            when 'words'
                @players.sort! { |p1,p2| p2.num_words_contributed <=> p1.num_words_contributed }
            else
                @players.sort! { |p1,p2| p2.bp( days ) <=> p1.bp( days ) }
        end
        
        if params[ :reverse ]
            @players.reverse!
        end
    end
    
    def view
        @player = Player.find( params[ :id ].to_i )
    end
end
