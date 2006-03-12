require 'active_record'

class Word < ActiveRecord::Base
end

class Game < ActiveRecord::Base
    has_and_belongs_to_many :players
end

class Player < ActiveRecord::Base
    has_and_belongs_to_many :games
end

class Channel < ActiveRecord::Base
end