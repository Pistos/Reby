# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

class TopicProtect

  TOPIC_ADMINS = [
    'Pistos',
    'luke-jr',
    'manveru',
    'nvidhive',
  ]

  def initialize
    $reby.bind( "topc", "-", "*", "sawTOPC", "$topic_protect" )
    $reby.bind( "raw", "-", "TOPIC", "sawTOPIC", "$topic_protect" )
    # $reby.bind( "raw", "-", "PRIVMSG", "sawPRIVMSG", "$topic_protect" )
    @topics = {
      '#catholic' => 'Please see ##catholic.',
      '#mathetes' => 'Welcome.  Don\'t ask to ask; just ask.  Issue tracker: http://linis.purepistos.net .  Use !memo to send a message to someone who is absent.  Diakonos 0.8.12: http://purepistos.net.twi.bz/g',
    }
  end

  def say( message, destination = "#mathetes" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end

  def sawPRIVMSG( from, keyword, text )
    $reby.log "#{from} #{keyword} #{text}"
  end

  def sawTOPC( *args )
    $reby.log "--------- sawTOPC #{args.inspect}"
  end

  def sawTOPIC( from, keyword, text )
    nick = from[ /^(.+)!/, 1 ]
    return  if $reby.isbotnick( nick )

    return  if text !~ /(#\w+) :(.+)/
    channel, topic = $1.downcase, $2
    #return  if ! @topics.keys.include? channel

    if TOPIC_ADMINS.include? nick
      @topics[ channel ] = topic
    else
      t = @topics[ channel ]
      $reby.putserv "TOPIC #{channel} :#{t}"
    end
  end
end

$topic_protect = TopicProtect.new
