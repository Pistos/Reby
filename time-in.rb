require 'rubygems'
require 'mechanize'
require 'cgi'

class TimeIn
    attr_reader :place
    
    def initialize
        @agent = WWW::Mechanize.new
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
end

if $0 == __FILE__
    ti = TimeIn.new
    place = ARGV[ 0 ] || 'Manila'
    t = ti.time_in( place )
    if t
        puts "Time in #{ti.place} is: #{t}"
    else
        $stderr.puts "Failed to fetch time for #{place}."
    end
end