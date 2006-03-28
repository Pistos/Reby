class TitleController < ApplicationController
    layout 'standard'
    
    def index
        redirect_to :action => 'list'
    end
    
    def list
        title_set_rows = TitleSet.find( :all, :order => :name )
        @title_sets = Hash.new
        title_set_rows.each do |row|
            @title_sets[ row.name ] = Title.find(
                :all,
                :conditions => [
                    "title_set_id = ?",
                    row.id
                ],
                :order => :title_level_id
            )
        end
    end
end
