# websearch.rb

# Performs a search on the web using any of various search engines.
# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

# Usage:
# !google [number of results] <search terms>
# !teoma [number of results] <search terms>
# !atw [number of results] <search terms>

require "open-uri"
require "cgi"

class String
    def translate( source, target )
        page = ""
        result = ""
        
        source = "es" if source == "sp"
        target = "es" if target == "sp"
        
        url = "http://babelfish.altavista.com/tr?doit=done&intl=1&tt=urltext&lp=#{source}_#{target}&submit=Translate&trtext=" + CGI.escape( self )
        
        begin
            open( url ) do |html|
                page = html.read.gsub(/\n/,' ').gsub(/\r/,' ')
                match = page.scan(/<td bgcolor=white class=s><[^>]*>(.*)<\/div>/)
                if ( match.size > 0 ) then
                    result = match[0][0]
                    idx = result.index('</div>')
                    result = result[0,idx]
                end
            end
        rescue
            result = "communication error: " + $!
        end
        
        result = "translation error" if ( result == "" )
            
        return result
    end
end

class Translator
    MAX_IRC_LINE_LENGTH = 400
    
    def initialize
        $reby.bind( "pub", "-", "!translate", "translate", "$translator" )
        $reby.bind( "pub", "-", "!trans", "translate", "$translator" )
        $reby.bind( "pub", "-", "!tran", "translate", "$translator" )
        $reby.bind( "pub", "-", "!tr", "translate", "$translator" )
    end

    def translate( nick, userhost, handle, channel, args )
        source, target, text = args.split( / /, 3 )
        if source.nil? or target.nil? or text.nil?
            $reby.putserv "PRIVMSG #{channel} :!translate <source lang> <target lang> <text to translate>"
        else
            translation = text.translate( source, target )
            $reby.putserv "PRIVMSG #{channel} :(#{source}) #{text}"
            $reby.putserv "PRIVMSG #{channel} :(#{target}) #{translation}"
        end
    end

end

$translator = Translator.new
