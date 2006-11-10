# kicker.rb

# Kicks people based on public PRIVMSG regexps.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

class RussianRoulette
    REASONS = [
        'You just shot yourself!',
        'Suicide is never the answer.',
        'If you wanted to leave, you could have just said so...',
        "Good thing these aren't real bullets...",
        "That's gotta hurt...",
    ]
    ALSO_BAN = true
    BAN_TIME = 1 # minutes
    
    def initialize
        $reby.bind( "pub", "-", "!roulette", "pullTrigger", "$roulette" )
    end
    
    def put( message, destination = ( @channel || 'Pistos' ) )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end
    
    def pullTrigger( nick, userhost, handle, channel, args )
        @channel = channel
        
        put '*spin* ...'
        sleep 4
        has_bullet = ( rand( 6 ) == 0 )
        if has_bullet
            if ALSO_BAN
                $reby.newban(
                    nick,
                    "RussianRoulette",
                    "Russian Roulette; for #{BAN_TIME} minute(s).",
                    BAN_TIME
                )
            end
            kick nick
        else
            put "-click-"
        end
    end
    
    def kick( victim )
        $reby.putkick(
            @channel,
            [ victim ],
            '{ *BANG* ' + 
                REASONS[ rand( REASONS.size ) ] +
            '}'
        )
    end
    
end

$roulette = RussianRoulette.new
