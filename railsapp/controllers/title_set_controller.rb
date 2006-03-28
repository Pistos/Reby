class TitleSetController < ApplicationController
    def index
        redirect_to :action => 'list'
    end
    
    def list
        @title_sets = TitleSet.find( :all )
    end    
end
