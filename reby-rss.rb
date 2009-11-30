# This script polls RSS feeds, echoing new items to IRC.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'mvfeed'
require 'nice-inspect'

class RebyRSS

  FEEDS = {
    'http://forum.webbynode.com/rss.php' => {
      :channels => [ '#webbynode', ],
      :interval => 60,
    },
    'http://blog.webbynode.com/feed/rss/' => {
      :channels => [ '#webbynode', ],
      :interval => 60 * 60,
    },
    'http://groups.google.com/group/ramaze/feed/rss_v2_0_msgs.xml' => {
      :channels => [ '#ramaze', ],
      :interval => 60 * 60,
    },
    'http://github.com/Pistos.private.atom?token=38fc2012cf93a2bf29be69409ad1272b' => {
      :channels => [ 'Pistos', ],
      :interval => 60 * 60,
    },
    'http://www.google.com/alerts/feeds/13535865067391668311/1085272382843306248' => {
      :channels => [ '#ramaze', ],
      :interval => 60 * 60,
    },
    'http://projects.stoneship.org/trac/nanoc/timeline?ticket=on&milestone=on&wiki=on&max=50&daysback=90&format=rss' => {
      :channels => [ '#nanoc', ],
      :interval => 60 * 60,
    },
    # 'http://linis.purepistos.net/ticket/rss/124' => {
      # :channels => [ 'Pistos', ],
      # :interval => 20,
    # },
  }

  def initialize
    @seen = Hash.new { |hash,key| hash[ key ] = Hash.new }
    @first = Hash.new { |hash,key| hash[ key ] = true }

    FEEDS.each do |uri, data|
      thread = Thread.new do
        loop do
          poll_feed( uri, data )
          sleep data[ :interval ]
        end
      end
      $reby.registerThread thread
    end
  end

  def say( message, destination = "#mathetes" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end

  def poll_feed( uri, data )
    feed = Feed.parse( uri )
    feed.children.each do |item|
      say_item uri, item, data[ :channels ]
    end
    @first[ uri ] = false
  rescue Exception => e
    $reby.log "RebyRSS exception: #{e.message}"
    #$reby.log e.backtrace.join( "\t\n" )
  end

  def zepto_url( url )
    URI.parse( 'http://zep.purepistos.net/zep/1?uri=' + CGI.escape( url ) ).read
  end

  def say_item( uri, item, channels )
    if item.author
      author = "<#{item.author}> "
    end

    alert = nil

    channels.each do |channel|
      id = item.link
      if not @seen[ channel ][ id ]
        if not @first[ uri ]
          if alert.nil?
            url = item.link
            if url.length > 28
              url = zepto_url( item.link )
            end
            alert = "[rss] #{author}#{item.title} - #{url}"
          end
          say alert, channel
        end
        @seen[ channel ][ id ] = true
      end
    end
  end
end

RebyRSS.new