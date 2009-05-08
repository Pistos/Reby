# locate.rb

# Does a geographic search by nick.
# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

# Usage:
# !locate <nick>

require 'open-uri'
require 'rubygems'
require 'mechanize'
require 'cgi'

class GeoLocate
    def initialize
        $reby.bind( "pub", "-", "!locate", "locate", "$locate" )
        @requests = 0
        @agent = WWW::Mechanize.new
    end

    def bindWhoisResponse
        $reby.bind( "raw", "-", "311", "locate_ip", "$locate" )
    end
    def unbindWhoisResponse
        $reby.unbind( "raw", "-", "311", "locate_ip", "$locate" )
    end

    def locate_ip( from, keyword, text )
        return if(
            keyword != "311" or
            @ip_channel.empty? or
            $reby.isbotnick( @ip_nick )
        )
        @requests -= 1
        if @requests <= 0
            unbindWhoisResponse
            @requests = 0
        end

        ip_address = text.split()[ 3 ]

        threads = []
        country = ""
        region = ""
        city = ""

        begin
          # doc = Hpricot( open( "http://www.geoip.co.uk/?IP=#{ip_address}" ) )
          # data = doc.at('#mapinfo .textleft').to_enum( :traverse_text ).zip( doc.at('#mapinfo .textright' ).to_enum(:traverse_text)).map{ |a,b|
            # [ a.inner_text.strip,b.inner_text.delete(':').strip ]
          # }
          # country = data[ 3 ][ 1 ]
          # region = data[ 5 ][ 1 ]

          doc = Hpricot( open( "http://www.geobytes.com/IpLocator.htm?GetLocation&ipaddress=#{ip_address}" ) )
          country = doc.at( "[@name='ro-no_bots_pls13']" )[ 'value' ]
          region = doc.at( "[@name='ro-no_bots_pls15']" )[ 'value' ]
          city = doc.at( "[@name='ro-no_bots_pls17']" )[ 'value' ]
        rescue Exception => e
          $reby.log e.message
        end

        if not city.empty?
            put "I estimate that #{@ip_nick} is somewhere near #{city}, #{region}, #{country}.", @ip_channel
            t = time_in( city, region, country )
            if t
                put "Local time in #{@time_place} is #{t}.", @ip_channel
            end
        elsif not country.empty?
            put "I estimate that #{@ip_nick} is somewhere in #{country}.", @ip_channel
        else
            put "Unable to !locate #{@ip_nick}.", @ip_channel
        end
    end

    def put( message, destination = ( @channel || 'Pistos' ) )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end

    def locate( nick, userhost, handle, channel, args )
        @ip_nick = args.split()[ 0 ]
        @ip_channel = channel
        $reby.putquick "PRIVMSG #{@ip_channel} :Searching for #{@ip_nick} ..."
        @requests += 1
        bindWhoisResponse
        $reby.putserv "WHOIS #{@ip_nick}"
    end

    def time_in( city, region, country )
        @time_place = nil
        place = CGI.escape( "#{city}, #{region}, #{country}" )
        search_results = @agent.get "http://www.timeanddate.com/search/results.html?query=#{place}"
        links = search_results.links.find_all { |l| l.text =~ /Current local time in/ }
        link = links.find { |l| l.text =~ /#{city}/i }
        if not link
            link = links.find { |l| l.text =~ /#{country}/i }
            if not link
                link = links.first
            end
        end
        if link
            page = @agent.click( link )
            s = page.at( "h1[text()*='Current local time in']" ).inner_text
            if s
                @time_place = s[ /time in (.+)/, 1 ]
            end
            page.at( '#ct' ).inner_text
        end
    end
end

$locate = GeoLocate.new
