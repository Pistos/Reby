# rps25.rb

# A rock-paper-scissors game, but insanely expanded from 3 to 25.
# http://www.umop.com/rps25.htm

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

class RockPaperScissors25
    ADMIN = 'nvidhive'
    CHANNEL = '#wordbattle'
    
    CHOICES = [
        'Gun',
        'Dynamite',
        'Nuke',
        'Lightning',
        'Devil',
        'Dragon',
        'Alien',
        'Water',
        'Bowl',
        'Air',
        'Moon',
        'Paper',
        'Sponge',
        'Wolf',
        'Cockroach',
        'Tree',
        'Man',
        'Woman',
        'Monkey',
        'Snake',
        'Axe',
        'Scissors',
        'Fire',
        'Sun',
        'Rock',
    ]
    
    def initialize
        $reby.bind( "msg", "-", 'rps', "select", "$rps25" )
    end
    
    def put( message, destination = CHANNEL )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end
    
    def parse_choice( str )
        if str.nil? or str.empty?
            nil
        else
            matches = CHOICES.find_all { |c|
                /^#{str}/i =~ c
            }
            matches[ 0 ]
        end
    end
    
    def beat_string( c1, c2 )
        'beats'
    end
    
    def winning_choice( c1, c2 )
        c1_index = CHOICES.index( c1 )
        c2_index = CHOICES.index( c2 )
        
        c1_victims = (1..13).map { |i|
            CHOICES[ c1_index - i ]
        }
        c2_victims = (1..13).map { |i|
            CHOICES[ c2_index - i ]
        }
        
        if c1_victims.include? c2
            c1
        elsif c2_victims.include? c1
            c2
        else
            nil
        end
    end
    
    def select( nick, userhost, handle, arg )
        choice = parse_choice( arg )
        if choice.nil?
            put "Invalid RPS-25 choice.", nick
        else
            if @previous
                if choice == @previous[ :choice ]
                    put "#{@previous[ :player ]} and #{nick} both picked #{choice}.", CHANNEL
                else
                    wc = winning_choice( choice, @previous[ :choice ] )
                    beat_str = beat_string( choice, @previous[ :choice ] )
                    if wc == choice
                        put "#{nick}'s #{choice} #{beat_str} #{@previous[ :player ]}'s #{@previous[ :choice ]}!", CHANNEL
                    else
                        put "#{@previous[ :player ]}'s #{@previous[ :choice ]} #{beat_str} #{nick}'s #{choice}!", CHANNEL
                    end
                    @previous = nil
                end
            else
                @previous = {
                    :player => nick,
                    :choice => choice,
                }
                put "Acknowledged: You chose #{choice}.", nick
                put "#{nick} has chosen...", CHANNEL
            end
        end
    end
    
end

$rps25 = RockPaperScissors25.new
