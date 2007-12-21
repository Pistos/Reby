# chanstats.rb

# Maintains some basic stats for channels

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'stored-hash'

class ChanStats
    DATA_FILE = 'chanstats.dat'
    EXCLUDED_CHANNELS = [ '#sequel' ]
    
    def initialize
        $reby.bind( "join", "-", "*", "on_join", "$chanstats" )
        $reby.bind( "pub", "-", "!cs", "chanstats_command", "$chanstats" )
        load_data
    end
    
    def put( message, destination = ( @channel || 'Pistos' ) )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end
    
    def set_defaults( channel )
        @stats[ channel ] ||= Hash.new
        @stats[ channel ][ :size_record ] ||= 0
        @stats[ channel ][ :members ] ||= { 0 => [] }
        @stats[ channel ][ :date ] ||= { 0 => Time.now }
        @stats[ channel ]
    end
    
    def load_data
        @stats = StoredHash.new( DATA_FILE )
    end
    
    def on_join( nick, userhost, handle, channel )
        return if EXCLUDED_CHANNELS.include?( channel )
        
        members = $reby.chanlist( channel )
        n = members.size
        cs = set_defaults( channel )
        if n > cs[ :size_record ]
            cs[ :size_record ] = n
            cs[ :members ][ n ] = members
            cs[ :date ][ n ] = Time.now
            
            put "*** New size record for #{channel}!  #{n} members!", channel
            
            i = n - 1
            num_reported = 0
            while i >= 0 and num_reported < 2
                if cs[ :members ][ i ]
                    put "Previous record: #{i} set on #{cs[ :date ][ i ]}", channel
                    num_reported += 1
                end
                i -= 1
            end
        end
    end
    
    def chanstats_command( nick, userhost, handle, channel, args )
        case args.to_s
            when /^reload$/i
                load_data
        end
    end
end

$chanstats = ChanStats.new
