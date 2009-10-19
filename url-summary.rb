# This script polls the Twitter API, echoing new messages to IRC.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'cgi'
require 'open-uri'
require 'json'
require 'nokogiri'

class URLSummarizer

  def initialize
    $reby.bind( "raw", "-", "PRIVMSG", "sawPRIVMSG", "$url_summarizer" )
  end

  def say( message, destination = "#mathetes" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end

  def sawPRIVMSG( from, keyword, text )
    if from !~ /^(.+?)!/
      $reby.log "[url-summary] No nick?  '#{from}' !~ /^(.+?)!/"
      return
    end

    nick = $1
    channel, speech = text.split( " :", 2 )

    case speech
    when %r{twitter\.com/\w+/status(?:es)?/(\d+)}
      open( "http://twitter.com/statuses/show/#{$1.to_i}.json" ) do |http|
        json = http.read
        tweet = JSON.parse( json )
        escaped_text = CGI.unescapeHTML( tweet[ 'text' ].gsub( '&quot;', '"' ).gsub( '&amp;', '&' ) ).gsub( /\s/, ' ' )
        say "[twitter] <#{tweet[ 'user' ][ 'screen_name' ]}> #{escaped_text}", channel
      end
    when %r{(http://[0-9a-zA-Z~!@#%&./?=_-]+)}
      doc = Nokogiri::HTML( open( $1 ) )

      description = doc.at( 'meta[@name="description"]' )
      if description
        say "[URL] #{description.attribute( 'content' )}"
        return
      end

      title = doc.at( 'title' ).content
      if title && ! title.empty?
        say "[URL] #{title}"
        return
      end

      heading = doc.at( 'h1,h2,h3,h4' ).content
      if heading && ! heading.empty?
        say "[URL] #{heading}"
      end
    end
  end
end

$url_summarizer = URLSummarizer.new
