# This script polls the Twitter API, echoing new messages to IRC.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'cgi'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'timeout'

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
    when %r{http://pastie\.org},
      %r{http://github\.com/.*/blob},
      %r{http://gist\.github\.com},
      %r{http://\d+\.\d+\.\d+\.\d+}
      # Blacklist; swallow and discard
    when %r{twitter\.com/\w+/status(?:es)?/(\d+)}
      open( "http://twitter.com/statuses/show/#{$1.to_i}.json" ) do |http|
        json = http.read
        tweet = JSON.parse( json )
        escaped_text = CGI.unescapeHTML( tweet[ 'text' ].gsub( '&quot;', '"' ).gsub( '&amp;', '&' ) ).gsub( /\s/, ' ' )
        say "[twitter] <#{tweet[ 'user' ][ 'screen_name' ]}> #{escaped_text}", channel
      end
    when %r{(http://github.com/.+?/(.+?)/commit/.+)}
      doc            = Nokogiri::HTML( open( $1 ) )

      project        = $2
      commit_message = doc.css( 'div.human div.message pre' )[ 0 ].content
      author         = doc.css( 'div.human div.name a')[ 0 ].content

      number_files            = {}
      number_files[:modified] = doc.css( 'div#toc ul li.modified' ).size
      number_files[:added]    = doc.css( 'div#toc ul li.added'    ).size
      number_files[:removed]  = doc.css( 'div#toc ul li.removed'  ).size

      s = "[github] [#{project}] <#{author}> #{commit_message} {+#{number_files[ :added ]}/-#{number_files[ :removed ]}/*#{number_files[ :modified ]}}"
      say s, channel
    when %r{(http://(?:[0-9a-zA-Z-]+\.)+[a-zA-Z]+(?:/[0-9a-zA-Z~!@#%&./?=_+-]*)?)}
      begin
        doc = nil
        Timeout::timeout( 30 ) do
          doc = Nokogiri::HTML( open( $1 ) )
        end

        summary = nil

        catch :found do
          description = doc.at( 'meta[@name="description"]' )
          if description
            summary = description.attribute( 'content' ).to_s
            throw :found
          end

          title = doc.at( 'title' )
          if title
            summary = title.content
            throw :found
          end

          heading = doc.at( 'h1,h2,h3,h4' )
          if heading
            summary = heading.content
            throw :found
          end
        end

        if summary
          summary = summary.strip.gsub( /\s+/, ' ' )
          if summary.length > 10
            summary = summary.split( /\n/ )[ 0 ]
            say "[URL] #{summary[ 0...160 ]}#{summary.size > 159 ? '[...]' : ''}", channel
          end
        end
      rescue RuntimeError => e
        if e.message !~ /redirect/
          raise e
        end
      end
    end
  end
end

$url_summarizer = URLSummarizer.new
