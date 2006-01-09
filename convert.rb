# convert.rb

# Uses Google to convert between almost any units (except currency).

# By Pistos - irc.freenode.net#geoshell

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop).

# Usage:
# !convert <any rough expression about conversion>
# e.g. !convert 20 mph to km/h

require "open-uri"
require "cgi"

class Converter
    def initialize
        $reby.bind( "pub", "-", "!convert", "convert", "$converter" )
        $reby.bind( "pub", "-", "!conv", "convert", "$converter" )
        $reby.bind( "pub", "-", "!calc", "convert", "$converter" )
    end
    
    def convert( nick, userhost, handle, channel, args )
        search( nick, channel, args )
    end
    
    def search( nick, channel, args )
        if args.class == Array
            if args.length < 1
                $reby.putserv "PRIVMSG #{channel} :!convert <conversion expression>"
                return
            end
            args2 = args << "="
            args2.collect! { |a| CGI.escape( a ) }
            arg = args2.join( "+" )
        else
            arg = [ CGI.escape( args ), CGI.escape( "=" ) ]
        end
        
        $reby.log "search arg: '#{arg}'"

        open( "http://www.google.com/search?q=#{ arg }" ) do |html|
            text = html.read
            counter = 0
            text.scan /calc_img.+?<b>(.+?)<\/b>/ do |result|
                stripped_result = result[ 0 ]
                stripped_result = stripped_result.gsub( /<sup>(.+?)<\/sup>/, "^(\\1)" )
                stripped_result = stripped_result.gsub( /<font size=-2> <\/font>/, "" )
                stripped_result = stripped_result.gsub( /<[^>]+>/, "" )
                stripped_result = stripped_result.gsub( /&times;/, "x" )
                $reby.putserv "PRIVMSG #{channel} :#{stripped_result}"
                counter += 1
                break
            end
            if counter == 0
                $reby.putserv "PRIVMSG #{channel} :(no results)"
            end
        end

    end
end

$converter = Converter.new
