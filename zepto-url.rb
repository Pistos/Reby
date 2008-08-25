# zepto-url.rb

# Performs various functions related to ZeptoURL
# http://zep.purepistos.net

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

class Zepto
  def initialize
    $reby.bind( "pub", "-", "!zu", "say_zepto_url", "$zepto" )
  end
    
  def put( message, destination = ( @channel || 'Pistos' ) )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end
  
  def say_zepto_url( nick, userhost, handle, channel, args )
    put "http://zep.purepistos.net/#{args}", channel
  end
end

$zepto = Zepto.new
