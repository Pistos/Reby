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
require 'rubygems'
require 'hpricot'

class WebSearch
    VERSION = '1.1.5'
    LAST_MODIFIED = '2009-05-07'

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
    GOOGLEFIGHT_VERBS = [
      [ 1000.0, "completely DEMOLISHES" ],
      [ 100.0, "utterly destroys" ],
      [ 10.0, "destroys" ],
      [ 5.0, "demolishes" ],
      [ 3.0, "crushes" ],
      [ 2.0, "shames" ],
      [ 1.2, "beats" ],
      [ 1.0, "barely beats" ],
    ]

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
        # $reby.bind( "pub", "-", "!pun", "badPuns", "$websearch" )
        $reby.bind( "pub", "-", "!pun", "pun", "$websearch" )
        $reby.bind( "pub", "-", "!googlefight", "googlefight", "$websearch" )
        $reby.bind( "pub", "-", "!gf", "googlefight", "$websearch" )
        $reby.bind( "pub", "-", "!meme", "meme", "$websearch" )
        $reby.bind( 'pub', '-', '!gloss', 'gloss', '$websearch' )
        $reby.bind( 'pub', '-', '!define', 'gloss', '$websearch' )
        $reby.bind( 'pub', '-', '!dict', 'wordsmyth', '$websearch' )
        $reby.bind( 'pub', '-', '?down', 'downforme', '$websearch' )
        $reby.bind( 'pub', '-', 'down?', 'downforme', '$websearch' )
        $reby.bind( 'pub', '-', '!down', 'downforme', '$websearch' )
        $reby.bind( 'pub', '-', '!down?', 'downforme', '$websearch' )
        $reby.bind( 'pub', '-', '?up', 'downforme', '$websearch' )
        $reby.bind( 'pub', '-', 'up?', 'downforme', '$websearch' )
        $reby.bind( 'pub', '-', '!up', 'downforme', '$websearch' )
        $reby.bind( 'pub', '-', '!up?', 'downforme', '$websearch' )

        $reby.bind( "pub", "-", "!docs", "searchGeoShellDocs", "$websearch" )
        $reby.bind( "pub", "-", "!rubybook", "searchPickAxe", "$websearch" )
        $reby.bind( "pub", "-", "!rubydoc", "searchRubyDoc", "$websearch" )
        $reby.bind( "pub", "-", "!rw", "search_ramaze_wiki", "$websearch" )
        $reby.bind( "pub", "-", "!ramaze", "search_ramaze_wiki", "$websearch" )
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
    def search_ramaze_wiki( nick, userhost, handle, channel, args )
        search( nick, channel, args + " site:ramaze.net -site:darcs.ramaze.net -site:hg.ramaze.net -site:p.ramaze.net", ENGINE_GOOGLE )
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

    def pun( nick, userhost, handle, channel, args )
      doc = Hpricot( open( "http://www.punoftheday.com/cgi-bin/randompun.pl" ) )
      p = doc.search( '#main-content p' )[ 0 ].inner_text
      put p, channel
    end

    def gloss( nick, userhost, handle, channel, args )
        search( nick, channel, args, :search_glossary )
    end

    def wordsmyth( nick, userhost, handle, channel, args )
        search( nick, channel, args, :search_wordsmyth )
    end

    def google_count( term_array )
      terms = CGI.escape( term_array.join( ' ' ) )
      doc = Hpricot( open( "http://www.google.com/search?q=#{terms}" ) )
      doc.at( '#ssb//b[3]' ).inner_text.gsub( ',', '' ).to_i
    end

    def number_with_delimiter( number, delimiter="," )
      number.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
    end

    def googlefight( nick, userhost, handle, channel, args )
      a = args.split( /,/ )
      if a.size != 2
        a = args.split( /\bv(?:ersu)?s(?:\.|\b)/ )
        if a.size != 2
          a = args.split( /\s+/, 2 )
        end
      end

      if a.size != 2
        put( "#{nick}: !googlefight <term(s)> [vs | ,] <term(s)>", channel )
      else
        a.collect! { |t| t.strip }
        count1 = google_count( a[ 0 ] )
        count2 = google_count( a[ 1 ] )
        ratio1 = ( count2 != 0 ) ? count1.to_f / count2 : 99
        ratio2 = ( count1 != 0 ) ? count2.to_f / count1 : 99
        ratio = [ ratio1, ratio2 ].max
        verb = GOOGLEFIGHT_VERBS.find { |x| ratio > x[ 0 ] }[ 1 ]
        c1 = number_with_delimiter( count1 )
        c2 = number_with_delimiter( count2 )

        if count1 > count2
          msg = "#{a[0]} #{verb} #{a[1]}! (#{c1} to #{c2})"
        else
          msg = "#{a[1]} #{verb} #{a[0]}! (#{c2} to #{c1})"
        end
        put( "#{nick}: #{msg}", channel )
      end
    end

    def meme( nick, userhost, handle, channel, args )
      n = 1
      if args.to_s.to_i > 0
        n = args.to_s.to_i
      end

      memes = open( "http://meme.boxofjunk.ws/moar.txt" ).readlines
      memes[ 0...n ].each do |meme|
        put meme, channel
      end
    end

    def downforme( nick, userhost, handle, channel, args )
      site = args.to_s.downcase[ /([a-z0-9.-]+)($|\/)/, 1 ]
      doc = Hpricot( open( "http://downforeveryoneorjustme.com/#{site}" ) )
      put( "#{nick}: [#{site}] " + doc.at( 'div#container' ).children.select{ |e| e.text? }.join( ' ' ).gsub( /\s+/, ' ' ).strip, channel )
    end

    def splitput( channel, text )
        text.scan( /.{1,400}/ ) do |text_part|
            $reby.putserv "PRIVMSG #{channel} :#{text_part}"
        end
    end

    def put( message, destination = @channel )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end

    def search( nick, channel, args, engine = ENGINE_GOOGLE )
        num_results = 1
        @channel = channel

        args_array = args.split( /\s+/ )

        if args_array.length < 1
            $reby.putserv "PRIVMSG #{channel} :!google [number of results] <search terms>"
            return
        end
        if args_array[ 0 ].to_i.to_s == args_array[ 0 ]
            # A number of results has been specified
            num_results = args_array[ 0 ].to_i
            if num_results > MAX_RESULTS
                num_results = MAX_RESULTS
            end
            arg = args_array[ 1..-1 ].join( "+" )
            unescaped_arg = args_array[ 1..-1 ].join( " " )
        else
            arg = args_array.join( "+" )
            unescaped_arg = args_array.join( " " )
        end

        arg = CGI.escape( arg )
        $reby.log "arg: #{arg}"

        case engine
            when ENGINE_GOOGLE
                max_results = num_results
                open( "http://www.google.com/search?q=#{ CGI.escape( args ) }&safe=active" ) do |html|
                    text = html.read

                    File.open( "websearch.last", "w" ) { |f| f.puts text }

                    counter = 0
                    text.scan /<a href="?([^"]+)" class=l.*?>(.+?)<\/a>/m do |match|
                        url, title = match
                        title.gsub!( /<.+?>/, "" )
                        ua = unescaped_arg.gsub( /-?site:\S+/, '' ).strip
                        put "[#{ua}]: #{url} - #{title}"
                        counter += 1
                        if counter >= max_results
                            break
                        end
                    end

                    if counter == 0
                        put "(no results)"
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
                # open( "http://en.wikipedia.org/w/wiki.phtml?search=#{ arg }" ) do |html|
                    # soup = BeautifulSoup.new( html.read )
#
                    # heading_tag = soup.find( 'h1', :attrs => { 'class' => 'firstHeading' } )
                    # if heading_tag
                        # title = heading_tag.string
                        # case title
                            # when 'Main_Page'
                                # $reby.putserv "PRIVMSG #{channel} :No wikipedia entries found for '#{arg}'."
                            # when 'Search'
                                # count = -2
                                # soup.find_all( 'a', :attrs => { 'href' => %r{^/wiki/} } ).each do |a|
                                    # if count >= 0
                                        # $reby.putserv "PRIVMSG #{channel} :[#{arg}] http://en.wikipedia.org#{a['href']}"
                                    # end
                                    # count += 1
                                    # if count >= num_results
                                        # break
                                    # end
                                # end
                            # else
                                # $reby.putserv "PRIVMSG #{channel} :[#{arg}] http://en.wikipedia.org/wiki/#{title}"
                        # end
                    # end
                # end
            when ENGINE_GEOSHELL_WIKI
                open( "http://docs.geoshell.org/dosearchsite.action?searchQuery.queryString=#{ arg }" ) do |html|
                    text = html.read
                    counter = 0
                    text.scan( /<a href="(\/display[^"]+).+?<br\/>.+?(<span.+?)<\/td>/m ) do |url,desc|
                        d = desc.gsub( /<[^>]+>/, "" )
                        $reby.putserv "PRIVMSG #{channel} :[#{arg}] http://docs.geoshell.org#{url} - #{d}"
                        counter += 1
                        if counter >= max_results
                            break
                        end
                    end
                    if counter == 0
                        $reby.putserv "PRIVMSG #{channel} :[#{args}] No results."
                    end
                end
            when :search_glossary
                index = num_results
                open( "http://www.google.com/search?q=define%3A+#{arg}" ) do |html|
                    text = html.read
                    if text =~ /No definitions were found for/
                        $reby.putserv "PRIVMSG #{channel} :No definitions found for #{arg}."
                    else
                        definition_text = text[ /<ul.*?>(.+)<\/ul>/m, 1 ]

                        if definition_text != nil
                            definitions = definition_text.scan( /li>\s*([^<>]+?)</ )
                            counter = 1
                            definitions.each do |defn|
                                if index <= counter
                                    $reby.putserv "PRIVMSG #{channel} :" + CGI.unescapeHTML( defn.to_s )
                                    break
                                end
                                counter += 1
                            end
                        end
                    end
                end
            when :search_wordsmyth
                # open( "http://www.wordsmyth.net/live/home.php?script=search&matchent=#{arg}&matchtype=exact" ) do |html|
                    # parse_wordsmyth( html.read, channel )
                # end
        end

    end

    # Broken; Soup is not 1.9-ready.
    def parse_wordsmyth( text, channel )
        soup = BeautifulSoup.new( text )

        not_found_p = soup.find( Proc.new { |el|
            el.respond_to?( :name ) &&
            el.name == 'p' &&
            el.find_text( /Sorry, we could not find/ )
        } )
        if not_found_p
            suggestions = []
            not_found_p.find_all( 'a' ).each do |a|
                suggestions << a.string
            end

            output = '(no results)'
            if not suggestions.empty?
                output << " Close matches: #{suggestions.join( ', ' )}"
            end

            splitput channel, output

            return
        end

        maintable = soup.find( 'table', :attrs => { 'cellspacing'=>'0', 'border'=>"0", 'cellpadding'=>"2", 'width'=>"100%", 'bgcolor' => nil } )

        wordtag = maintable.find( 'div', { :attrs => { 'class' => 'headword' } } )
        if wordtag
            word = wordtag.contents[ 0 ]
        end

        # Iterate through all <tr>s, find relevant bits.
        output = ""
        maintable.next_parsed_items do |tr|
            next if not tr.respond_to?( :name ) or tr.name != 'tr'

            main_td = tr.find( 'td', :attrs => { 'width' => '70%' } )
            middle_td = tr.find( 'td', :attrs => { 'width' => '5%', 'valign' => 'baseline' } )

            # Part of Speech

            if tr[ 'bgcolor' ] == '#DDDDFF'
                pos = main_td.span.string
                if not output.empty?
                    splitput channel, output
                end
                output = "#{word} - [#{pos}]"
            end

            if tr[ 'bgcolor' ] == '#FFFFFF'
                # Pronunciation

                prontag = tr.find( 'div', :attrs => { 'class' => 'pron' } )
                if prontag
                    syllabification = []
                    prontag.each do |syllable|
                        if syllable.respond_to? :string and syllable.string
                            syllable_class = syllable[ 'class' ]
                            if syllable_class
                                stress_level = syllable_class[ /(\d)/, 1 ].to_i
                                case stress_level
                                    when 1
                                        stress = "'"
                                    when 2
                                        stress = '"'
                                    else
                                        stress = ''
                                end
                                syllabification << stress + syllable.string
                            else
                                syllabification << syllable.string
                            end
                        end
                    end
                    output << " (" + syllabification.join( ' ' ) + ")"
                end

                # Definition

                if main_td
                    def_span = main_td.find( 'span', :attrs => { 'style' => 'font-weight: normal;' } )
                    if def_span
                        output << "  " + middle_td.span.string + " " + def_span.string
                    end
                end
            end
        end
        if not output.empty?
            splitput channel, output
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
                    st = search_term.gsub( /-?site:\S+/, '' )
                    $reby.puthelp "PRIVMSG #{channel} :[#{st}] #{segment}"
                end
                $reby.puthelp "PRIVMSG #{channel} :#{output}"
                counter += 1
                if counter >= max_results
                    break
                end
            end

            if counter == 0
                st = search_term.gsub( /-?site:\S+/, '' )
                $reby.puthelp "PRIVMSG #{channel} :[#{st}] No results found."
            end
        end
    end
end

$websearch = WebSearch.new
