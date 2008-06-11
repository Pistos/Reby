# chanstats.rb

# Maintains some basic stats for channels

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'yaml'
require 'pistos'
require 'fileutils'

class ChanStats
    DATA_FILE = 'chanstats.dat'
    EXCLUDED_CHANNELS = [ '#sequel', '#ruby-pro' ]
    
    def initialize
        $reby.bind( "join", "-", "*", "on_join", "$chanstats" )
        $reby.bind( "pub", "-", "!cs", "chanstats_command", "$chanstats" )
        load_data
    end
    
    def put( message, destination = ( @channel || 'Pistos' ) )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end
    
    def load_data
        if File.exist? DATA_FILE
            @stats = YAML::load( File.read( DATA_FILE ) )
            if not @stats
                $reby.log "Failed to load stats file!"
            end
        else
            @stats = Hash.new
            save_data
        end
    end
    def save_data
        File.open( DATA_FILE, 'w' ) do |f|
            f.write @stats.to_yaml
        end
    end
    
    def set_defaults( channel )
        @stats[ channel ] ||= Hash.new
        @stats[ channel ][ :size_record ] ||= 0
        @stats[ channel ][ :members ] ||= { 0 => [] }
        @stats[ channel ][ :date ] ||= { 0 => Time.now }
        save_data
        @stats[ channel ]
    end
    
    def on_join( nick, userhost, handle, channel )
        members = $reby.chanlist( channel )
        n = members.size
        cs = set_defaults( channel )
        if n > cs[ :size_record ]
            cs[ :size_record ] = n
            cs[ :members ][ n ] = members
            cs[ :date ][ n ] = Time.now
            save_data
            if not EXCLUDED_CHANNELS.include?( channel )
              put "*** New size record for #{channel}!  #{n} members!  Previous record: #{n-1} set on #{cs[ :date ][ n-1 ]}", channel
            end
        end
    end
    
    def chanstats_command( nick, userhost, handle, channel, args )
        case args.to_s
            when /^rec/i
                cs = set_defaults( channel )
                n = cs[ :size_record ]
                put "#{channel} had #{n} members on #{cs[:date][n]}.", channel
        end
    end
end

$chanstats = ChanStats.new
