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
  SEARCHES = {
    #'ramaze' => [ '#ramaze' ],
    'ramaze' => [ '#mathetes' ],
    'purepistos' => [ '#mathetes' ],
    'm4dbi' => [ '#mathetes' ],
    #'webbynode' => [ '#webbynode' ],
  }
  
  def initialize
    config = YAML.load_file 'reby-twitter.yaml'
    @twitter = Twitter::Base.new( config[ 'username' ], config[ 'password' ] )
    @last_timestamp = Time.now
    @last_search_id = Hash.new
    
    SEARCHES.each do |search_term,channels|
      search = Twitter::Search.new( search_term )
      fetched = search.fetch
      @last_search_id[ search_term ] = fetched[ 'max_id' ]
    end
    
    @thread = Thread.new do
      loop do
        @echoed_ids = []
        poll_timeline
        poll_searches
        sleep 30
      end
    end
    $reby.registerThread @thread
  end
  
  def say( message, destination = "#mathetes" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end
  
  def poll_timeline
    tl = @twitter.timeline( :friends, :since => ( @last_timestamp + 1 ).to_s )
    if tl.any?
      tl.reverse!
      @last_timestamp = Time.parse( tl[ -1 ].created_at )
      tl.each do |tweet|
        say_tweet tweet
      end
    end
  rescue Exception => e
    $reby.log "RebyTwitter exception: #{e.message}"
    #$reby.log e.backtrace.join( "\t\n" )
  end
  
  def poll_searches
    SEARCHES.each do |search_term,channels|
      search = Twitter::Search.new( search_term )
      last_id = @last_search_id[ search_term ] 
      search.since( last_id )
      fetched = search.fetch
      if fetched[ 'max_id' ] > last_id
        @last_search_id[ search_term ] = fetched[ 'max_id' ]
        fetched[ 'results' ].each do |tweet|
          say_search_tweet tweet, channels
        end
      end
    end
  rescue Exception => e
    $reby.log "RebyTwitter exception: #{e.message}"
    #$reby.log e.backtrace.join( "\t\n" )
  end
  
  def say_tweet tweet
    if @echoed_ids.include? tweet.id
      return
    end
    src = tweet.user.screen_name
    text = tweet.text.gsub( /[^a-zA-Z0-9,.;:'!?\/ _-]/, '' )
    alert = "[twitter] <#{src}> #{text}"
    channels = CHANNELS[ src ] || [ '#mathetes' ]
    channels.each do |channel|
      say alert, channel
    end
    @echoed_ids << tweet.id
  end
  
  def say_search_tweet( tweet, channels = [ '#mathetes' ] )
    if @echoed_ids.include? tweet[ 'id' ]
      return
    end
    src = tweet[ 'from_user' ]
    text = tweet[ 'text' ].gsub( /[^a-zA-Z0-9,.;:'!?\/ _-]/, '' )
    alert = "[twitter] <#{src}> #{text}"
    channels.each do |channel|
      say alert, channel
    end
    @echoed_ids << tweet[ 'id' ]
  end
end

RebyTwitter.new