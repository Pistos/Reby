# geoboard.rb

# Polls the GeoShell forums for new posts, and sends them to the channel.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'cgi'
require 'rexml/document'

class String
    def to_time
        retval = nil
        # Sat, 11 Jun 2005 14:06:56 GMT
        case self
            when /^.+? (\d+) (.+?) (\d+) (\d+):(\d+):(\d+) [A-Z]+$/
                retval = Time.local( $3, $2, $1, $4, $5, $6 )
            when /^.+? (.+?) (\d+) (\d+):(\d+):(\d+) [A-Z]+ (\d+)$/
                retval = Time.local( $6, $1, $2, $3, $4, $5 )
            when /^Today at (\d+):(\d+):(\d+) [AP]M$/
                t = Time.now
                retval = Time.local( t.year, t.month, t.day, $1, $2, $3 )
            when /^Yesterday at (\d+):(\d+):(\d+) [AP]M$/
                t = Time.now - 86400
                retval = Time.local( t.year, t.month, t.day, $1, $2, $3 )
            when /^(\w+) (\d+), (\d+), (\d+):(\d+):(\d+) [AP]M$/
                retval = Time.local( $3, $1[0..2], $2, $4, $5, $6 )
        end
        
        return retval
    end
    
    def extractAttribute( attrib )
        return self[ /<#{attrib}>(.+?)<\/#{attrib}>/m, 1 ]
    end
    
    def convertCDATA
        return self[ /^(?:<!\[CDATA\[)?(.+?)(?:\]\]>)?$/m, 1 ]
    end
end

class GeoBoard
    # Time in minutes between pollings.
    CHECK_INTERVAL = 2
    
    def initialize
        poll
    end
    
    def poll
        if FileTest.exist?( "geoboard.last" )
            #previous_last = IO.readlines( "geoboard.last" ).join.to_time
            previous_last = IO.readlines( "geoboard.last" ).join.to_i
        else
            #previous_last = Time.local( 1990 )
            previous_last = 0
        end
        
        `wget -q -O geoboard.xml 'http://www.geoshell.org/board/index.php?action=.xml;limit=10'`
        doc = REXML::Document.new( File.new( "geoboard.xml" ) )
        new_last = previous_last
        doc.elements.each( "*/recent-post" ) do |post|
            id = post.elements[ 'id' ].text.to_i
            link = post.elements[ "link" ].text
            
            subject = post.elements[ "subject" ].cdatas.join
            #subject.gsub!( /&nbsp;/, " " )
            #subject.gsub!( /&quot;/, "\"" )
            subject = CGI.unescapeHTML( subject )
            
            body = post.elements[ "body" ].cdatas.join
            body.gsub!( /<br.*>/, " " )
            body.gsub!( /<.+?>/, "" )
            body.gsub!( /&nbsp;/, " " )
            body.gsub!( /&quot;/, "\"" )
            body = body[ 0, 250 ]
            
            poster = CGI.unescapeHTML( post.elements[ "poster" ].elements[ "name" ].cdatas.join )
            
            if id > previous_last
                #$reby.putserv( "NOTICE #geoshell :#{subject} - #{link} <#{poster}> " + CGI.unescapeHTML( body ) )
                $reby.putserv( "NOTICE #geoshell :#{subject} - #{link} <#{poster}>" )
                if id > new_last
                    new_last = id
                end
            end
        end
        
        if new_last > previous_last
            File.open( "geoboard.last", "w" ) do |f|
                f.print new_last
            end
        end
        
        $reby.timer( CHECK_INTERVAL, "poll", "$geoboard" )
    end
end

$geoboard = GeoBoard.new