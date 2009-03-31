require '/misc/git/reby/time-in'

class TimeTeller
  def initialize
    $reby.bind( "pub", "-", "!time", "say_time", "$time_teller" )
    @time = TimeIn.new
  end

  def put( message, destination = ( @channel || 'Pistos' ) )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end

  def say_time( nick, userhost, handle, channel, args )
    put( @time.time_in( args.to_s ), channel )
  end
end

$time_teller = TimeTeller.new
