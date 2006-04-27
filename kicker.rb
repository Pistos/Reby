# kicker.rb

# Kicks people based on public PRIVMSG regexps.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

class Kicker
    CHANNEL = "#mathetes"
    # Add bot names to this list, if you like.
    WATCHLIST = [
        'scry',
    ]
    REGEXPS = [
        /^(\S+): chamber \d of \d => \*BANG\*/
    ]
    INVINCIBLE = [
        'Specimen',
    ]
    
    def initialize
        $reby.bind( "raw", "-", "PRIVMSG", "sawPRIVMSG", "$kicker" )
    end
    
    def sawPRIVMSG( from, keyword, text )
        from = from.to_s
        delimiter_index = from.index( "!" )
        if delimiter_index != nil
            nick = from[ 0...delimiter_index ]
            channel, speech = text.split( " :", 2 )
            if channel == CHANNEL and WATCHLIST.include?( nick )
                REGEXPS.each do |r|
                    if r =~ speech
                        victim = $1
                        if not INVINCIBLE.include?( victim )
                            $reby.putkick( channel, [ victim ], "{You just shot yourself!}" )
                        end
                    end
                end
            end
        else
            $reby.log "[kicker] No nick?  '#{from}' (#{from.index( '!' )})"
        end
    end
end

$kicker = Kicker.new