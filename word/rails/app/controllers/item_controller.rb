class ItemController < ApplicationController
    layout 'standard'
    
    def index
        redirect_to :action => 'list'
    end
    
    def list
        @weapons = Weapon.find( :all, :order => 'modifier, price, name' )
        @armour = Armour.find( :all, :order => 'modifier DESC, price, name' )
    end
end
