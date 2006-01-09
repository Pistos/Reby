# lastspoke.rb 

# A Reby script to keep track of when people last spoke.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'stored-hash'

class Fixnum
    def seconds_to_interval_string
        seconds = self
        
        minutes = 0
        hours = 0
        days = 0
        
        if seconds > 59
            minutes = seconds / 60
            seconds = seconds % 60
            if minutes > 59
                hours = minutes / 60
                minutes = minutes % 60
                if hours > 23
                    days = hours / 24
                    hours = hours % 24
                end
            end
        end
    
        msg_array = Array.new
        if days > 0
            msg_array << "#{days} day#{days > 1 ? 's' : ''}"
        end
        if hours > 0
            msg_array << "#{hours} hour#{hours > 1 ? 's' : ''}"
        end
        if minutes > 0
            msg_array << "#{minutes} minute#{minutes > 1 ? 's' : ''}"
        end
        if seconds > 0
            msg_array << "#{seconds} second#{seconds > 1 ? 's' : ''}"
        end
        
        return msg_array.join( ", " )
    end
end

class Float
    def seconds_to_interval_string
        return self.to_i.seconds_to_interval_string
    end
end

class LastSpoke
    # Add bot names to this list, if you like.
    IGNORED = [ "", "*" ]
    
    def initialize
        @last_spoke = StoredHash.new( "lastspoke.hash" )
        @spoke_start = StoredHash.new( "lastspoke-start.hash" )
        @spoke_start[ 'time' ] = Time.now
        
        $reby.bind( "raw", "-", "PRIVMSG", "sawPRIVMSG", "$lastspoke" )
        $reby.bind( "pub", "-", "!last", "query", "$lastspoke" )
        $reby.bind( "pub", "-", "!lastspoke", "query", "$lastspoke" )
        $reby.bind( "pub", "-", "!spoke", "query", "$lastspoke" )
    end
    
    def sawPRIVMSG( from, keyword, text )
        if from =~ /^(.+?)!/
            nick = $1
            channel, speech = text.split( " :", 2 )
            if not IGNORED.include?( nick )
                @last_spoke[ nick ] = [ Time.now, channel, speech ]
            end
        else
            $reby.log "[lastspoke] No nick?  '#{from}' !~ /^(.+?)!/"
        end
    end
    
    def query( nick, userhost, handle, channel, args )
        target = args.to_s
        
        if target == nick
            $reby.putserv "PRIVMSG #{channel} :Um... you JUST spoke, to issue the command.  :)"
        elsif $reby.isbotnick( target )
            $reby.putserv "PRIVMSG #{channel} :I don't watch myself."
        elsif @last_spoke[ target ] == nil
            $reby.putserv "PRIVMSG #{channel} :As far as I know, #{target} hasn't said anything."
            $reby.putserv "PRIVMSG #{channel} :I've been watching for #{( Time.now - @spoke_start[ 'time' ] ).seconds_to_interval_string}."
        else
            interval_string = ( Time.now - @last_spoke[ target ][ 0 ] ).seconds_to_interval_string
            $reby.putserv "PRIVMSG #{channel} :#{interval_string} ago, #{target} said: '#{@last_spoke[ target ][ 2 ]}' in #{@last_spoke[ target ][ 1 ]}."
        end
    end
end

$lastspoke = LastSpoke.new