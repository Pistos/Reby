# This script polls the Twitter API, echoing new messages to IRC.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'twitter'
require 'time'
require 'nice-inspect'
require 'yaml'
require 'rexml/document'

class RebyTwitter

  CHANNELS = {
    'webbynode' => [ '#webbynode', 'Pistos', ],
    'manveru' => [ '#ramaze', 'Pistos', ],
    '_why' => [ '#ramaze', 'Pistos', ],
  }
  SEARCHES = {
    'm4dbi' => [ 'Pistos' ],
    'better-benchmark' => [ 'Pistos' ],
    'diakonos' => [ 'Pistos' ],
    'linistrac' => [ 'Pistos' ],
    'purepistos' => [ 'Pistos' ],
    'ramaze' => [ '#ramaze' ],
    'ruby dbi' => [ '#ruby-dbi' ],
    'webbynode' => [ '#webbynode' ],
  }

  def initialize
    config = YAML.load_file 'reby-twitter.yaml'
    @twitter = Twitter::Base.new( config[ 'username' ], config[ 'password' ] )
    @last_timestamp = Time.now
    @last_search_id = Hash.new
    @seen = Hash.new { |hash,key| hash[ key ] = Array.new }

    SEARCHES.each do |search_term,channels|
      search = Twitter::Search.new( search_term )
      fetched = search.fetch
      max_id = fetched[ 'max_id' ].to_i
      @last_search_id[ search_term ] = max_id
      channels.each do |channel|
        @seen[ channel ] << max_id
      end
    end

    @thread = Thread.new do
      loop do
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
      if fetched[ 'max_id' ].to_i > last_id
        @last_search_id[ search_term ] = fetched[ 'max_id' ].to_i
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
    tweet_id = tweet.id.to_i
    src = tweet.user.screen_name
    text = REXML::Text::unnormalize( tweet.text ).gsub( /[^a-zA-Z0-9,.;:&@'!?\/ ()_-]/, '' )
    alert = "[twitter] <#{src}> #{text}"
    channels = CHANNELS[ src ] || [ 'Pistos' ]
    channels.each do |channel|
      if not @seen[ channel ].include?( tweet_id )
        say alert, channel
        @seen[ channel ] << tweet_id
      end
    end
  end

  def say_search_tweet( tweet, channels = [ 'Pistos' ] )
    tweet_id = tweet[ 'id' ].to_i
    src = tweet[ 'from_user' ]
    text = REXML::Text::unnormalize( tweet[ 'text' ] ).gsub( /[^a-zA-Z0-9,.;:&@'!?\/ ()_-]/, '' )
    alert = "[twitter] <#{src}> #{text}"
    channels.each do |channel|
      if not @seen[ channel ].include?( tweet_id )
        say alert, channel
        @seen[ channel ] << tweet_id
      end
    end
  end
end

RebyTwitter.new