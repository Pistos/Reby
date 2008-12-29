# This script polls RSS feeds, echoing new items to IRC.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'mvfeed'
require 'nice-inspect'

class RebyTwitter

  FEEDS = {
    'http://forum.webbynode.com/syndication.php?limit=10' => [ '#webbynode', ],
    'http://groups.google.com/group/ramaze/feed/rss_v2_0_msgs.xml' => [ '#ramaze', ],
    #'http://linis.purepistos.net/ticket/rss/124' => [ 'Pistos', ],
  }

  def initialize
    @seen = Hash.new { |hash,key| hash[ key ] = Hash.new }
    @first = true

    @thread = Thread.new do
      loop do
        poll_feeds
        sleep 60
      end
    end
    $reby.registerThread @thread
  end

  def say( message, destination = "#mathetes" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end

  def poll_feeds
    FEEDS.each do |uri, channels|
      feed = Feed.parse( uri )
      feed.children.each do |item|
        channels.each do |channel|
          say_item item, channels
        end
      end
    end
    @first = false
  rescue Exception => e
    $reby.log "RebyRSS exception: #{e.message}"
    #$reby.log e.backtrace.join( "\t\n" )
  end

  def say_item( item, channels )
    if item.author
      author = "<#{item.author}> "
    end
    alert = "[rss] #{author}#{item.title} - #{item.link}"
    channels.each do |channel|
      id = item.link
      if not @seen[ channel ][ id ]
        if not @first
          say alert, channel
        end
        @seen[ channel ][ id ] = true
      end
    end
  end
end

RebyTwitter.new