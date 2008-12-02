# This script polls the Twitter API, echoing new messages to IRC.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'twitter'
require 'time'
require 'nice-inspect'
require 'yaml'

class RebyTwitter
  
  CHANNELS = {
    'webbynode' => [ '#webbynode', '#mathetes', ],
    #'Pistos' => [ '#mathetes', ],
    'manveru' => [ '#ramaze', '#mathetes', ],
    '_why' => [ '#ramaze', '#mathetes', ],
  }
  
  def initialize
    config = YAML.load_file 'reby-twitter.yaml'
    @twitter = Twitter::Base.new( config[ 'username' ], config[ 'password' ] )
    @last_timestamp = Time.now
    @thread = Thread.new do
      loop do
        poll_twitter
        sleep 30
      end
    end
    $reby.registerThread @thread
  end
  
  def say( message, destination = "#mathetes" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end
  
  def poll_twitter
    tl = @twitter.timeline( :friends, :since => ( @last_timestamp + 1 ).to_s )
    if tl.any?
      tl.reverse!
      @last_timestamp = Time.parse( tl[ -1 ].created_at )
      tl.each do |tweet|
        say_tweet tweet
      end
    end
  end
  
  def say_tweet tweet
    src = tweet.user.screen_name
    text = tweet.text.gsub( /[^a-zA-Z0-9,.;:!? _-]/, '' )
    alert = "[twitter] <#{src}> #{text}"
    channels = CHANNELS[ src ] || [ '#mathetes' ]
    channels.each do |channel|
      say alert, channel
    end
  end
end

RebyTwitter.new