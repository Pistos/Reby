# google.rb

# Performs a google search.
# By Pistos - irc.freenode.net#geoshell

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop).

# Usage:
# !google [number of results] <search terms>

require "open-uri"

class Google
    def initialize
        @MAX_RESULTS = 5
        $reby.bind( "pub", "-", "!google", "search", "$google" )
        $reby.bind( "pub", "-", "!docs", "searchGeoShellDocs", "$google" )
        $reby.bind( "pub", "-", "!rubybook", "searchPickAxe", "$google" )
        $reby.bind( "pub", "-", "!rubydoc", "searchRubyDoc", "$google" )
    end

    def searchSite( nick, userhost, handle, channel, args, site )
        search( nick, userhost, handle, channel, args.to_a.push( "site:#{site}" ) )
    end

    # -----------
    # You can setup some custom searches here.

    def searchGeoShellDocs( nick, uhost, handle, chan, arg )
        searchSite( nick, uhost, handle, chan, arg, "docs.geoshell.com" )
    end
    def searchPickAxe( nick, uhost, handle, chan, arg )
        searchSite( nick, uhost, handle, chan, arg, "phrogz.net" )
    end
    def searchRubyDoc( nick, uhost, handle, chan, arg )
        searchSite( nick, uhost, handle, chan, arg, "www.ruby-doc.org" )
    end

    def search( nick, userhost, handle, channel, args )
        num_results = 1

        if args.class == Array
            if args.length < 1
                $reby.putserv "PRIVMSG #{channel} :!google [number of results] <search terms>"
                return
            end
            if args[ 0 ].to_i.to_s == args[ 0 ]
                # A number of results has been specified
                num_results = args[ 0 ].to_i
                if num_results > @MAX_RESULTS
                    num_results = @MAX_RESULTS
                end
                arg = args[ 1..-1 ].join( "+" )
            else
                arg = args.join( "+" )
            end
        else
            arg = args
        end

        open( "http://www.google.com/search?q=#{ arg }" ) do |html|
            text = html.read
            counter = 0
            text.scan /<p class=g><a href=([^>]+)>/m do |url|
                $reby.putserv "PRIVMSG #{channel} :#{url}"
                counter += 1
                if counter >= num_results
                    break
                end
            end
        end

    end
end

class String
    def escapeGoogle( str )
        newstring = str.gsub( /\s+/, "+" )
        newstring.gsub!( /[^\w\.]/ ) do |match|
            "%%%02X" % match[ 0 ]
        end
        return newstring
    end
end

$google = Google.new
