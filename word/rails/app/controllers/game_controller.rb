class GameController < ApplicationController
    layout 'standard'
    
    def index
        redirect_to :action => 'list'
    end
    
    def list
        @games = Game.find(
            :all,
            :conditions => "end_time > NOW() - '24 hours'::INTERVAL",
            :order => 'start_time desc'
        )
    end
end
