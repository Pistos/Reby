# This script polls the Twitter API, echoing new messages to IRC.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'twitter'
require 'time'
require 'nice-inspect'
require 'yaml'
require 'rexml/document'
require 'cgi'

$KCODE = 'u'

class RebyTwitter

  CHANNELS = {
    'webbynode' => [ '#webbynode', ],
    'ramazetest' => [ '#mathetes', ],
  }
  SEARCHES = {
    'ramaze' => [ '#ramaze', ],
    'ruby dbi' => [ '#ruby-dbi', ],
    'webbynode' => [ '#webbynode', ],
    'rvm -rain -treadmill -running -qualifiers -weather -car -"the rvm"' => [ '#rvm', ],
  }

  def initialize
    config = YAML.load_file 'reby-twitter.yaml'
    @twitter = Twitter::Base.new( config[ 'username' ], config[ 'password' ] )
    @last_timestamp = Time.now
    @last_search_id = Hash.new
    @seen = Hash.new { |hash,key| hash[ key ] = Array.new }

    SEARCHES.each do |search_term,channels|
      search = Twitter::Search.new( search_term )
      begin
        fetched = search.fetch
        max_id = fetched[ 'max_id' ].to_i
        @last_search_id[ search_term ] = max_id
        channels.each do |channel|
          @seen[ channel ] << max_id
        end
      rescue Exception => e
        $reby.log "Reby Twitter exception: #{e}"
      end
    end

    @thread = Thread.new do
      loop do
        poll_timeline
        poll_searches
        sleep 60
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
      tl.reverse_each do |tweet|
        say_tweet tweet
      end
    end
  rescue Exception => e
    $reby.log "RebyTwitter exception: #{e.message}"
    # $reby.log e.backtrace.join( "\t\n" )
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
    # $reby.log e.backtrace.join( "\t\n" )
  end

  def clean_text( text )
    converted = text.gsub( /&#([[:digit:]]+);/ ) {
      [ $1.to_i ].pack( 'U*' )
    }.gsub( /&#x([[:xdigit:]]+);/ ) {
      [ $1.to_i(16) ].pack( 'U*' )
    }
    REXML::Text::unnormalize(
      #text.gsub( /&\#\d{3,};/, '?' )
      converted
    )
    # ).gsub( /[^a-zA-Z0-9,.;:&\#@'!?\/ ()_-]/, '' )
  end

  def say_tweet( tweet )
    tweet_time = Time.parse( tweet.created_at )
    return  if tweet_time < @last_timestamp
    @last_timestamp = tweet_time
    tweet_id = tweet.id.to_i
    src = tweet.user.screen_name
    text = clean_text( tweet.text )
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
    text = clean_text( tweet[ 'text' ] )
    alert = "[twitter] <#{src}> #{text}"
    channels.each do |channel|
      if not @seen[ channel ].include?( tweet_id )
        say alert, channel
        @seen[ channel ] << tweet_id
      end
    end
  end
end

$reby_twitter = RebyTwitter.new
