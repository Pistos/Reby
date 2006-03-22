# locate.rb

# Does a geographic search by nick.
# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

# Usage:
# !locate <nick>

require 'open-uri'
require 'rubygems'
require 'rubyful_soup'
require 'net/http'

class GeoLocate
    def initialize
        $reby.bind( "pub", "-", "!locate", "locate", "$locate" )
        @requests = 0
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
        timezone = ""
        
        found = false
        t = Thread.new do
            begin
                open( "http://www.geobytes.com/IpLocator.htm?GetLocation&ipaddress=#{ip_address}" ) do |html|
                    soup = BeautifulSoup.new( html.read )
                    itag = soup.find( 'input', :attrs => { 'name' => /ro-no_bots_pls13/ } )
                    if itag != nil
                        country = itag[ 'value' ]
                    end
                    itag = soup.find( 'input', :attrs => { 'name' => /ro-no_bots_pls15/ } )
                    if itag != nil
                        region = itag[ 'value' ]
                    end
                    itag = soup.find( 'input', :attrs => { 'name' => /ro-no_bots_pls17/ } )
                    if itag != nil
                        city = itag[ 'value' ]
                    end
                    itag = soup.find( 'input', :attrs => { 'name' => /ro-no_bots_pls9/ } )
                    if itag != nil
                        timezone = itag[ 'value' ]
                    end
                        
                    found = ( not ( country.empty? or region.empty? or city.empty? or timezone.empty? ) )
                end
            rescue Exception => e
                # ignore
            end
        end
        threads << t
        
        country2 = ''
        found2 = false
        t = Thread.new do
            begin
                open( "http://www.dnsstuff.com/tools/whois.ch?ip=#{ip_address}" ) do |html|
                    text = html.read
                    
                    if( text =~ /Country:\s+(.+?)\s\s/ )
                        country2 = $1
                        found2 = true
                    end
                end
            rescue Exception => e
                # ignore
            end
        end
        threads.push t
        
        country3 = nil
        city3 = nil
        latitude = nil
        longitude = nil
        found3 = false
        t = Thread.new do ||
            begin
                open( "http://hostip.info/api/get.html?ip=#{ip_address}&position=true" ) do |html|
                    text = html.read
                    
                    country3 = text[ /Country: (.+?) \(/, 1 ]
                    city3 = text[ /City: (.+)/, 1 ]
                    latitude = text[ /Latitude: (.+)/, 1 ]
                    longitude = text[ /Longitude: (.+)/, 1 ]
                    
                    found3 = ( country3 != nil and country3 !~ /Unknown/ )
                end
            rescue Exception => e
                # ignore
            end
        end
        threads.push t

        threads.each do |t|
            begin
                t.join
            rescue Timeout::Error
                $stderr.puts "(timed out)"
            end
        end
        
        location = ''
        if found
            location << "near #{city}, #{region}, #{country} (#{timezone})"
            if found2 
                location << " or perhaps just somewhere in #{country2}"
            end
        elsif found2 
            location << "in #{country2}"
        end
        
        if not location.empty?
            $reby.puthelp "PRIVMSG #{@ip_channel} :I estimate that #{@ip_nick} is somewhere #{location}."
        else
            $reby.puthelp "PRIVMSG #{@ip_channel} :Unable to !locate #{@ip_nick}."
        end
    end
    
    def locate( nick, userhost, handle, channel, args )
        @ip_nick = args.split()[ 0 ]
        @ip_channel = channel
        $reby.putquick "PRIVMSG #{@ip_channel} :Searching for #{@ip_nick} ..."
        @requests += 1
        bindWhoisResponse
        $reby.putserv "WHOIS #{@ip_nick}"
    end
end

$locate = GeoLocate.new