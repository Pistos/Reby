class TitleController < ApplicationController
    layout 'standard'
    
    def index
        redirect_to :action => 'list'
    end
    
    def list
        @title_sets = TitleSet.find( :all, :order => :name )
    end
end
