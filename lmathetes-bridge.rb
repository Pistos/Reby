# lmathetes-bridge.rb

# Acts as a bridge between the Learning Mathetes AI engine and your
# eggdrop (through Reby)
# By Pistos - irc.freenode.net#geobot

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop).

# Usage:
# Directly address the bot.
# e.g. GeoBot: How are you?

class String
    def escapeQuotes
        temp = ""
        each_byte do |b|
            if b == 39
                temp << 39
                temp << 92
                temp << 39
            end
            temp << b
        end
        
        return temp
    end
end

class Array
    def escapeQuotes
        return to_s.escapeQuotes
    end
end


class LMathetesBridge
    def initialize
        $reby.bind( "pubm", "-", "#geoshell *", "listen", "$lmathetes_bridge" )
        $reby.bind( "pubm", "-", "#mathetes *", "listen", "$lmathetes_bridge" )
    end
    
    def listen( nick, userhost, handle, channel, args )
        if args.join( " " ) =~ /^[Gg][Ee][Oo][Bb][Oo][Tt] ?[^A-Za-z!.\s]+\s+(.+)$/
            speech = $1.escapeQuotes
            
            pwd = Dir.pwd
            #Dir.chdir( "/home/geobot/mathetes-unloved" )
            Dir.chdir( "/home/geobot/public-mathetes" )
            #response = `./lmathetes.rb -s '#{nick.escapeQuotes}' --database 'lmathetes_unloved' '#{speech}'`.chomp
            $reby.log "./lmathetes.rb -s '#{nick.escapeQuotes}' '#{speech}'"
            response = `./lmathetes.rb -s '#{nick.escapeQuotes}' '#{speech}'`.chomp
            Dir.chdir( pwd )
            if response == nil or response == ""
                response = "I experienced technical difficulties handling your input.  Please try again."
            end
            $reby.putserv "PRIVMSG #{channel} :#{nick}: #{response}"
        end
    end
end

$lmathetes_bridge = LMathetesBridge.new
