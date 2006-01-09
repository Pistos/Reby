# websearch.rb

# Performs a search on the web using any of various search engines.
# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

# Usage:
# !google [number of results] <search terms>
# !teoma [number of results] <search terms>
# !atw [number of results] <search terms>
# etc.

require "open-uri"
require "cgi"

class WebSearch
    MAX_RESULTS = 5
    ENGINE_GOOGLE = 0
    ENGINE_TEOMA = 1
    ENGINE_ALLTHEWEB = 2
    ENGINE_ALTAVISTA = 3
    ENGINE_WIKIPEDIA = 4
    ENGINE_ETYMONLINE = 5
    ENGINE_GEOSHELL_WIKI = 6
    ENGINE_SYNONYM_COM = 7
    ENGINE_BADPUNS_COM = 8
    MAX_IRC_LINE_LENGTH = 400
    
    def initialize
        $reby.bind( "pub", "-", "!google", "google", "$websearch" )
        $reby.bind( "pub", "-", "!teoma", "teoma", "$websearch" )
        $reby.bind( "pub", "-", "!atw", "allTheWeb", "$websearch" )
        $reby.bind( "pub", "-", "!alltheweb", "allTheWeb", "$websearch" )
        $reby.bind( "pub", "-", "!alta", "altaVista", "$websearch" )
        $reby.bind( "pub", "-", "!altavista", "altaVista", "$websearch" )
        $reby.bind( "pub", "-", "!wiki", "wikipedia", "$websearch" )
        $reby.bind( "pub", "-", "!wikip", "wikipedia", "$websearch" )
        $reby.bind( "pub", "-", "!pedia", "wikipedia", "$websearch" )
        $reby.bind( "pub", "-", "!wikipedia", "wikipedia", "$websearch" )
        $reby.bind( "pub", "-", "!etym", "etymOnline", "$websearch" )
        $reby.bind( "pub", "-", "!syn", "synonym", "$websearch" )
        $reby.bind( "pub", "-", "!pun", "badPuns", "$websearch" )
        
        $reby.bind( "pub", "-", "!docs", "searchGeoShellDocs", "$websearch" )
        $reby.bind( "pub", "-", "!rubybook", "searchPickAxe", "$websearch" )
        $reby.bind( "pub", "-", "!rubydoc", "searchRubyDoc", "$websearch" )
    end

    def searchSite( nick, userhost, handle, channel, args, site )
        search( nick, channel, args.to_a.push( "site:#{site}" ) )
    end

    # -----------
    # You can setup some custom searches here.

    def searchPickAxe( nick, uhost, handle, chan, arg )
        searchSite( nick, uhost, handle, chan, arg, "phrogz.net" )
    end
    def searchRubyDoc( nick, uhost, handle, chan, arg )
        searchSite( nick, uhost, handle, chan, arg, "www.ruby-doc.org" )
    end
    
    # -----------
    
    def google( nick, userhost, handle, channel, args )
        search( nick, channel, args, ENGINE_GOOGLE )
    end

    def searchGeoShellDocs( nick, uhost, handle, chan, args )
        search( nick, chan, args, ENGINE_GEOSHELL_WIKI )
    end
    
    def teoma( nick, userhost, handle, channel, args )
        search( nick, channel, args, ENGINE_TEOMA )
    end

    def allTheWeb( nick, userhost, handle, channel, args )
        search( nick, channel, args, ENGINE_ALLTHEWEB )
    end

    def altaVista( nick, userhost, handle, channel, args )
        search( nick, channel, args, ENGINE_ALTAVISTA )
    end
    
    def wikipedia( nick, userhost, handle, channel, args )
        search( nick, channel, args, ENGINE_WIKIPEDIA )
    end

    def etymOnline( nick, userhost, handle, channel, args )
        search( nick, channel, args, ENGINE_ETYMONLINE )
    end
    
    def synonym( nick, userhost, handle, channel, args )
        search( nick, channel, args, ENGINE_SYNONYM_COM )
    end
    
    def badPuns( nick, userhost, handle, channel, args )
        getResults(
            "http://www.badpuns.com/jokes.php?section=oneline&pos=random",
            /<br><br>(.+?)<br><br>/m,
            channel,
            1
        )
    end
    
    def search( nick, channel, args, engine = ENGINE_GOOGLE )
        num_results = 1

        if args.class == Array
            if args.length < 1
                $reby.putserv "PRIVMSG #{channel} :!google [number of results] <search terms>"
                return
            end
            if args[ 0 ].to_i.to_s == args[ 0 ]
                # A number of results has been specified
                num_results = args[ 0 ].to_i
                if num_results > MAX_RESULTS
                    num_results = MAX_RESULTS
                end
                arg = args[ 1..-1 ].join( "+" )
                unescaped_arg = args[ 1..-1 ].join( " " )
            else
                arg = args.join( "+" )
                unescaped_arg = args.join( " " )
            end
        else
            unescaped_arg = arg = args
        end
        
        arg = CGI.escape( arg )

        case engine
            when ENGINE_GOOGLE
                max_results = num_results
                open( "http://www.google.com/search?q=#{ arg }&safe=active" ) do |html|
                    text = html.read
                    
                    File.open( "websearch.last", "w" ) { |f| f.puts text }
                    
                    counter = 0
                    text.scan /<p class=g><a class=l href="?([^>"]+).*?>(.+?)<\/a>/m do |match|
                        url, title = match
                        title.gsub!( /<.+?>/, "" )
                        $reby.putserv "PRIVMSG #{channel} :[#{unescaped_arg}]: #{url} - #{title}"
                        counter += 1
                        if counter >= max_results
                            break
                        end
                    end
                end
                
            when ENGINE_TEOMA
                getResults(
                    "http://s.teoma.com/search?q=#{ arg }",
                    /<div id="result".+?<a href=".+?u=([^"]+)"/m,
                    channel,
                    num_results
                )
            when ENGINE_ALLTHEWEB
                getResults(
                    "http://www.alltheweb.com/search?q=#{ arg }",
                    /<span class="resURL">(.+?)[ <]/m,
                    channel,
                    num_results
                )
            when ENGINE_ALTAVISTA
                getResults(
                    "http://www.altavista.com/web/results?q=#{ arg }",
                    /<span class=ngrn>(.+?)[ <]/m,
                    channel,
                    num_results
                )
            when ENGINE_ETYMONLINE
                getResults(
                    "http://www.etymonline.com/index.php?term=#{ arg }",
                    /<dt(?: class="highlight")?>(.+?)<\/dd>/m,
                    channel,
                    num_results,
                    arg
                )
            when ENGINE_SYNONYM_COM
                #if arg =~ /[a-zA-Z -]/
                    begin
                        open( "http://thesaurus.reference.com/search?q=#{ CGI.escape( unescaped_arg ) }" ) do |html|
                            text = html.read
                            num_printed = 0
                            text.scan( /Main Entry:(.+?)Source:/m ) do |entr|
                                entry = entr[ 0 ]
                                entry.gsub!( /<[^>]+?>/, "" )
                                entry.gsub!( /&nbsp;/, " " )
                                main_entry = entry[ /([a-zA-Z -]+)/, 1 ].strip
                                if main_entry.downcase == unescaped_arg.downcase
                                    definition = entry[ /Definition:(.+)/, 1 ].strip
                                    syns = entry[ /Synonyms:(.+)/, 1 ].strip
                                    if num_printed < 2 or channel == "#mathetes"
                                        dest = "PRIVMSG #{channel}"
                                    else
                                        dest = "NOTICE #{nick}"
                                        if num_printed == 2
                                            $reby.putserv "PRIVMSG #{channel} :(more results given in private to #{nick})"
                                        end
                                    end
                                        
                                    $reby.putserv "#{dest} :[#{unescaped_arg}] #{definition} - #{syns}"
                                    num_printed += 1
                                end
                            end
                            if num_printed == 0
                                $reby.putserv "PRIVMSG #{channel} :[syn #{unescaped_arg}] No synonyms found."
                            end
                        end
                    rescue Exception => e
                        $reby.putserv "PRIVMSG #{channel} :[syn #{unescaped_arg}] No synonyms found."
                        $reby.log( e.message + "\n" + e.backtrace.join( "\n\t" ) )
                    end
                #else
                    #$reby.putserv "PRIVMSG #{channel} :[syn] Invalid input."
                #end
            when ENGINE_WIKIPEDIA
                open( "http://en.wikipedia.org/w/wiki.phtml?search=#{ arg }" ) do |html|
                    text = html.read
                    title = text[ /href.+?title=(.+?)&/, 1 ]
                    if title == "Main_Page"
                        $reby.putserv "PRIVMSG #{channel} :No wikipedia entries found for '#{arg}'."
                    else
                        $reby.putserv "PRIVMSG #{channel} :[#{arg}] http://en.wikipedia.org/wiki/#{title}"
                    end
                end
            when ENGINE_GEOSHELL_WIKI
                open( "http://docs.geoshell.org/dosearchsite.action?searchQuery.queryString=#{ arg }" ) do |html|
                    text = html.read
                    counter = 0
                    text.scan( /<a href="(\/confluence\/display[^"]+).+?<br\/>.+?(<span.+?)<\/td>/m ) do |url,desc|
                        d = desc.gsub( /<[^>]+>/, "" )
                        $reby.putserv "PRIVMSG #{channel} :http://docs.geoshell.com:8080#{url} - #{d}"
                        counter += 1
                        if counter >= max_results
                            break
                        end
                    end
                end
        end

    end
    
    def getResults( search_url, regexp, channel, max_results, search_term = "" )
        open( search_url ) do |html|
            text = html.read
            counter = 0
            text.scan regexp do |url|
                case url
                    when Array
                        url.collect! do |u|
                            u.gsub( /\n/m, " " ).gsub( /<.+?>/, "" )
                        end
                    when String
                        u.gsub!( /\n/m, " " )
                        u.gsub!( /<.+?>/, "" )
                end
                output = CGI.unescapeHTML( url.to_s )
                while output.length > MAX_IRC_LINE_LENGTH
                    segment = output[ 0...MAX_IRC_LINE_LENGTH ]
                    output = output[ MAX_IRC_LINE_LENGTH..-1 ]
                    $reby.puthelp "PRIVMSG #{channel} :#{segment}"
                end
                $reby.puthelp "PRIVMSG #{channel} :#{output}"
                counter += 1
                if counter >= max_results
                    break
                end
            end
            
            if counter == 0
                $reby.puthelp "PRIVMSG #{channel} :[#{search_term}] No results found."
            end
        end
    end
end

$websearch = WebSearch.new
