require 'rubygems'
require 'mechanize'
require 'cgi'

class TimeIn
    attr_reader :place
    
    def initialize
        @agent = WWW::Mechanize.new
        if $reby
            $reby.bind( "pub", "-", "!time", "time_in_bind", "$time_in" )
        end
    end
    
    def time_in( place_ )
        @place = nil
        place = CGI.escape( place_ )
        search_results = @agent.get "http://www.timeanddate.com/search/results.html?query=#{place}"
        first_link = search_results.links.find { |l| l.text =~ /Current local time in/ }
        if first_link
            page = @agent.click( first_link )
            s = page.at( "h1[text()*='Current local time in']" ).inner_text
            if s
                @place = s[ /time in (.+)/, 1 ]
            end
            page.at( '#ct' ).inner_text
        end
    end
    
    def put( message, destination = ( @channel || 'Pistos' ) )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end
    
    def time_in_bind( nick, userhost, handle, channel, args )
        place = args.to_s
        t = time_in( place )
        if t
            put "Local time in #{@place} is #{t}.", channel
        else
            put "Failed to determine local time in #{place}.", channel
        end
    end
end

$time_in = TimeIn.new
if $0 == __FILE__
    place = ARGV[ 0 ] || 'Manila'
    t = $time_in.time_in( place )
    if t
        puts "Time in #{$time_in.place} is: #{t}"
    else
        $stderr.puts "Failed to fetch time for #{place}."
    end
end