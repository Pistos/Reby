class TitleController < ApplicationController
    layout 'standard'
    
    def index
        redirect_to :action => 'list'
    end
    
    def list
        title_set_rows = TitleSet.find( :all, :order => :name )
        @title_sets = Hash.new
        @title_icons = Hash.new
        title_set_rows.each do |row|
            @title_sets[ row.name ] = Title.find(
                :all,
                :conditions => [
                    "title_set_id = ?",
                    row.id
                ],
                :order => :title_level_id
            )
            @title_icons[ row.name ] = Array.new
            @title_icons[ row.name ] << Player::ICON_PREFIXES[ row.id ] + "1"
            @title_icons[ row.name ] << Player::ICON_PREFIXES[ row.id ] + "2"
        end
    end
end
