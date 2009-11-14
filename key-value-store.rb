# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

__DIR__ = File.expand_path( File.dirname( __FILE__ ) )
require "#{__DIR__}/mutex-pstore"

module RebyKVStore

  class Store
    def initialize
      @h = MuPStore.new( "key-value.pstore" )
      $reby.bind( "pub", "-", "!info", "info", "$reby_kv_store" )
      $reby.bind( "pub", "-", "!i", "info", "$reby_kv_store" )
    end

    def say( message, channel )
      $reby.putserv "PRIVMSG #{channel} :[kv] #{message}"
    end

    def info( nick, userhost, handle, channel, args )
      params = args.to_s
      if params =~ /(.+?)=(.+)/
        key, value = $1.strip, $2.strip
        @h.transaction { @h[ { :channel => channel, :key => key }.inspect ] = value }
        say "Set '#{key}'.", channel
      else
        key = params.strip
        value = nil
        @h.transaction { value = @h[ { :channel => channel, :key => key }.inspect ] }
        if value
          say value, channel
        else
          say "No value for key '#{key}'.", channel
        end
      end
    end
  end

end

$reby_kv_store = RebyKVStore::Store.new
