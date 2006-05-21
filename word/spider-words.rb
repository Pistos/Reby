#!/usr/bin/env ruby

# This script spiders the web for new words to add to the word.rb game.

require 'open-uri'
require 'rubygems'
require 'rubyful_soup'
require 'cgi'
require 'stored-array'
require 'word-ar-defs'

class String
    BAD_WORDS = {
        'en-ca' => [
            /\bass\b/,
            /\banus\b/,
            /\bbreasts\b/,
            /\bbutt\b/,
            /\bcock\b/,
            /\bfag\b/,
            /\bfart(?:s|ing)?\b/,
            /\bgive me head\b/,
            /\bhorny\b/,
            /\blick\b/,
            /\bnigga\b/,
            /\bnigger\b/,
            /\brape\b/,
            /\braped\b/,
            /\bslut\b/,
            /\btits\b/,
            /\btitties\b/,
            /\bturds?\b/,
            /\bmy wang\b/,
            /\bwhore\b/,
        ],
    }
    BAD_PARTIALS = {
        'en-ca' => [
            /anal sex/,
            /asshole/,
            /my balls/,
            /bitch/,
            /blow ?job/,
            /cunt/,
            /dick/,
            /dumbass/,
            /fag/,
            /fondl/,
            /fuck/,
            /masturbat/,
            /oral sex/,
            /orgasm/,
            /penis/,
            /pussy/,
            /pussies/,
            /shit/,
            /suck my/,
            /vagina/,
        ]
    }
    
    # Returns true or false.
    def is_foul( language = "en-ca" )
        words = BAD_WORDS[ language ]
        if words != nil
            words.each do |bw|
                if self =~ bw
                    return true
                end
            end
        end
        partials = BAD_PARTIALS[ language ]
        if partials != nil
            partials.each do |bp|
                if self =~ bp
                    return true
                end
            end
        end
            
        return false
    end
end

class Tag
    def string_contents
        definition = ''
        contents.each do |item|
            if item.respond_to? :string_contents
                definition << item.string_contents
            else
                definition << item
            end
        end
        return definition
    end
    
    def has_anchor_in_front?
        x = contents[ 0 ]
        if x != nil
            if x.respond_to? :contents
                y = x.contents[ 0 ]
                if y != nil
                    if y.name == 'a'
                        return true
                    end
                end
            end
        end
        return false
    end
end

class WordSpider
    attr_reader :die
    
    MIN_WORD_LENGTH = 4
    HIGH_QUEUE_LEVEL = 500
    NUM_CONNECTION_ATTEMPTS = 1
    MAX_AWARD = 1000 # gold
    SYLLABLE_SEPARATOR = "(?:&#183;|%middot|" + sprintf( "%c" % [ 183 ] ) + ")"
    
    ETYM_LANGS = {
        'Amer.Eng.' => 'American English',
        'American English' => 'American English',
        'Anglian' => 'Anglian',
        'Anglo-Fr.' => 'Anglo-French',
        'Anglo-French' => 'Anglo-French',
        'Anglo-L.' => 'Anglo-Latin',
        'Anglo-Latin' => 'Anglo-Latin',
        'Anglo-Norm.' => 'Anglo-Norman',
        'Anglo-Norman' => 'Anglo-Norman',
        'Ar.' => 'Arabic',
        'Arabic' => 'Arabic',
        'Assyr.' => 'Assyrian',
        'Assyrian' => 'Assyrian',
        'Celt.' => 'Celtic',
        'Celtic' => 'Celtic',
        'Dan.' => 'Danish',
        'Danish' => 'Danish',
        'Du.' => 'Dutch',
        'Dutch' => 'Dutch',
        'E.Fris.' => 'East Frisian',
        'East Frisian' => 'East Frisian',
        'Egypt.' => 'Egyptian',
        'Egyptian' => 'Egyptian',
        'Eng.' => 'English',
        'English' => 'English',
        'Fl.' => 'Flemish',
        'Flemish' => 'Flemish',
        'Fr.' => 'French',
        'French' => 'French',
        'Frank.' => 'Frankish',
        'Frankish' => 'Frankish',
        'Fris.' => 'Frisian',
        'Frisian' => 'Frisian',
        'Gallo-Romance' => 'Gallo-Romance',
        'Gallo-Roman' => 'Gallo-Roman',
        'Gael.' => 'Gaelic',
        'Gaelic' => 'Gaelic',
        'Gaul.' => 'Gaulish',
        'Gaulish' => 'Gaulish',
        'Ger.' => 'German',
        'German' => 'German',
        'Goth.' => 'Gothic',
        'Gothic' => 'Gothic',
        'Gk.' => 'Greek',
        'Greek' => 'Greek',
        'Gmc.' => 'Germanic',
        'Germanic' => 'Germanic',
        'Heb.' => 'Classical Hebrew',
        'Classical Hebrew' => 'Classical Hebrew',
        'Hung.' => 'Hungarian',
        'Hungarian' => 'Hungarian',
        'I.E.' => 'Indo-European',
        'Indo-European' => 'Indo-European',
        'Ir.' => 'Irish',
        'Irish' => 'Irish',
        'Iran.' => 'Iranian',
        'Iranian' => 'Iranian',
        'It.' => 'Italian',
        'Italian' => 'Italian',
        'Kentish' => 'Kentish',
        'L.' => 'Classical Latin',
        'Classical Latin' => 'Classical Latin',
        'Lith.' => 'Lithuanian',
        'Lithuanian' => 'Lithuanian',
        'L.L.' => 'Late Latin',
        'Late Latin' => 'Late Latin',
        'Low Ger.' => 'Low German',
        'Low German' => 'Low German',
        'M.Du.' => 'Middle Dutch',
        'Middle Dutch' => 'Middle Dutch',
        'M.E.' => 'Middle English',
        'Middle English' => 'Middle English',
        'Mercian' => 'Mercian',
        'M.Fr.' => 'Middle French',
        'Middle French' => 'Middle French',
        'M.H.G.' => 'Middle High German',
        'Middle High German' => 'Middle High German',
        'M.L.' => 'Medieval Latin',
        'Medieval Latin' => 'Medieval Latin',
        'M.L.G.' => 'Middle Low German',
        'Middle Low German' => 'Middle Low German',
        'Mod.Eng.' => 'Modern English',
        'Modern English' => 'Modern English',
        'Mod.Gk.' => 'Modern Greek',
        'Modern Greek' => 'Modern Greek',
        'Mod.L.' => 'Modern Latin',
        'Modern Latin' => 'Modern Latin',
        'N.Gmc.' => 'North Germanic',
        'North Germanic' => 'North Germanic',
        'Norm.' => 'Norman',
        'Norman' => 'Norman',
        'North Sea Gmc.' => 'North Sea Germanic',
        'North Sea Germanic' => 'North Sea Germanic',
        'Northumbrian' => 'Northumbrian',
        'O.Celt.' => 'Old Celtic',
        'Old Celtic' => 'Old Celtic',
        'O.C.S.' => 'Old Church Slavonic',
        'Old Church Slavonic' => 'Old Church Slavonic',
        'O.Dan.' => 'Old Danish',
        'Old Danish' => 'Old Danish',
        'O.Du.' => 'Old Dutch',
        'Old Dutch' => 'Old Dutch',
        'O.E.' => 'Old English',
        'Old English' => 'Old English',
        'O.Fr.' => 'Old French',
        'Old French' => 'Old French',
        'O.Fris.' => 'Old Frisian',
        'Old Frisian' => 'Old Frisian',
        'O.H.G.' => 'Old High German',
        'Old High German' => 'Old High German',
        'O.Ir.' => 'Old Irish',
        'Old Irish' => 'Old Irish',
        'O.It.' => 'Old Italian',
        'Old Italian' => 'Old Italian',
        'O.LowG.' => 'Old Low German',
        'Old Low German' => 'Old Low German',
        'O.N.' => 'Old Norse',
        'Old Norse' => 'Old Norse',
        'O.N.Fr.' => 'Old North French',
        'Old North French' => 'Old North French',
        'O.Pers.' => 'Old Persian',
        'Old Persian' => 'Old Persian',
        'O.Prov.' => 'Old Provençal',
        'Old Provençal' => 'Old Provençal',
        'O.Prus.' => 'Old Prussian',
        'Old Prussian' => 'Old Prussian',
        'O.S.' => 'Old Saxon',
        'Old Saxon' => 'Old Saxon',
        'Osc.' => 'Oscan',
        'Oscan' => 'Oscan',
        'O.Slav.' => 'Old Slavic',
        'Old Slavic' => 'Old Slavic',
        'O.Sp.' => 'Old Spanish',
        'Old Spanish' => 'Old Spanish',
        'O.Sw.' => 'Old Swedish',
        'Old Swedish' => 'Old Swedish',
        'Pers.' => 'Persian',
        'Persian' => 'Persian',
        'P.Gmc.' => 'Proto-Germanic',
        'Proto-Germanic' => 'Proto-Germanic',
        'Phoen.' => 'Phoenician',
        'Phoenician' => 'Phoenician',
        'PIE' => 'Proto-Indo-European',
        'Proto-Indo-European' => 'Proto-Indo-European',
        'Pol.' => 'Polish',
        'Polish' => 'Polish',
        'Port.' => 'Portuguese',
        'Portuguese' => 'Portuguese',
        'Prov.' => 'Provençal',
        'Provençal' => 'Provençal',
        'Russ.' => 'Russian',
        'Russian' => 'Russian',
        'Scand.' => 'Scandinavian',
        'Scandinavian' => 'Scandinavian',
        'Scot.' => 'Scottish',
        'Scottish' => 'Scottish',
        'Sem.' => 'Semitic',
        'Semitic' => 'Semitic',
        'Serb.' => 'Serbian',
        'Serbian' => 'Serbian',
        'Skt.' => 'Sanskrit',
        'Sanskrit' => 'Sanskrit',
        'Slav.' => 'Slavic',
        'Slavic' => 'Slavic',
        'Sp.' => 'Spanish',
        'Spanish' => 'Spanish',
        'Swed.' => 'Swedish',
        'Swedish' => 'Swedish',
        'Turk.' => 'Turkish',
        'Turkish' => 'Turkish',
        'Urdu' => 'Urdu',
        'V.L.' => 'Vulgar Latin',
        'Vulgar Latin' => 'Vulgar Latin',
        'W.Afr.' => 'West African',
        'West African' => 'West African',
        'W.Fris.' => 'West Frisian',
        'West Frisian' => 'West Frisian',
        'W.Gmc.' => 'West Germanic',
        'West Germanic' => 'West Germanic',
        'Wolof' => 'Wolof',
        'W.Saxon' => 'West Saxon',
        'West Saxon' => 'West Saxon',
    }
    
    def initialize( seed_word = nil, suggester = nil, num_to_spider = 500 )
        @seen_words = StoredArray.new( "seen-words.array" )
        @next_words = StoredArray.new( "spider-words.array" )
        if seed_word != nil
            @next_words << seed_word
        end
        puts "@next_words: #{@next_words.inspect}"
        @num_spidered = 0
        @num_to_spider = num_to_spider.to_i
        @etym_lang_regexp = ETYM_LANGS.keys.collect { |lang|
            Regexp.escape( lang )
        }
        
        @connection_attempts = 0
        ensureConnectedToDB
        
        if suggester != nil and not suggester.empty?
            @suggester = Player.find_by_nick( suggester )
            if @suggester != nil
                @suggester_id = @suggester.id
                @award = 0
            else
                $stderr.puts "No such player: '#{suggester}'"
            end
        end
    end
    
    def ensureConnectedToDB
        if ActiveRecord::Base.connected?
            $stderr.puts "(already connected)"
        else
            @connection_attempts += 1
            ActiveRecord::Base.establish_connection(
                :adapter  => "postgresql",
                :host     => "localhost",
                :username => "word",
                :password => "word",
                :database => "word_test"
            )
            if ! ActiveRecord::Base.connected? && @connection_attempts > NUM_CONNECTION_ATTEMPTS
                $stderr.puts "Too many failed DB connection attempts."
                @die = 2
            end
        end
    end
    
    def start
        while not @next_words.empty? and @num_spidered < @num_to_spider and not @die
            begin
                #@word = @next_words.delete_at( rand( @next_words.length ) )
                @word = @next_words.pop
                getWord
                if @next_words.size < HIGH_QUEUE_LEVEL
                    gatherRelated
                end
            rescue Exception => e
                if e.class == Interrupt
                    $stderr.puts "Aborted."
                    @die = 3
                else
                    $stderr.puts "! (#{e.class}) #{e.message}\n\t" + e.backtrace.join( "\n\t" )
                end
            end
        end
        
        ActiveRecord::Base.remove_connection
        
        puts
        puts "#{@num_spidered} words spidered."
        puts "@next_words: #{@next_words.join(' ')}"
    end
    
    def queueWord( word )
        begin
            if(
                not @seen_words.include?( word ) and
                not @next_words.include?( word ) and
                Word.find_by_word( word ).nil?
            )
                @next_words.insert( rand( @next_words.length ), word )
            end
        rescue ActiveRecord::StatementInvalid => e
            case e.message
                when /no connection to the server/
                    #$stderr.puts "No DB connection?  Attempting reconnect... (#{@connection_attempts})"
                    $stderr.puts "No DB connection?"
                    #ActiveRecord::Base.remove_connection
                    #ensureConnectedToDB
                    @die = 2
                else
                    raise e
            end
        end
    end

    def gatherRelated
        other_words = Array.new
        open( "http://dictionary.reference.com/search?q=#{@word}" ) do |html|
            soup = BeautifulSoup.new( html.read )
            
            soup.find_all( 'a', :attrs => { 'href' => /\/search\?q=[a-z]+/ } ).each do |a|
                a[ 'href' ] =~ /q=([a-z]+)$/
                other_word = $1
                if other_word != nil and other_word.length >= MIN_WORD_LENGTH and not other_word.is_foul
                    other_words << other_word
                end
            end
        end
        
        other_words.uniq!
        other_words.each do |word|
            queueWord( word )
        end
    end
    
    def getWord
        @seen_words << @word
        word_rec = nil
        catch( :problem ) do
            definition = ''
            part_of_speech = ''
            syllabification = nil
            etymology = ''
            
            open( "http://dictionary.reference.com/search?q=#{@word}" ) do |html2|
                soup2 = BeautifulSoup.new( html2.read )
                
                # Get syllabification
                
                catch( :found ) do
                    soup2.find_all( /^b$/ ).each do |b|
                        text = b.string
                        next if text.nil?
                        text.scan( /(?:^|\s)[a-z]+(?:#{SYLLABLE_SEPARATOR}[a-z]+)*(?:\s|$)/ ) do |subtext|
                            desyllabified_word = subtext.gsub( /#{SYLLABLE_SEPARATOR}/, '' )
                            if desyllabified_word == @word
                                syllabification = subtext.split( /#{SYLLABLE_SEPARATOR}/ )
                                throw :found
                            else
                                queueWord( desyllabified_word )
                            end
                        end
                        break
                    end
                end
                
                if syllabification.nil?
                    $stderr.puts "#{@word}\tno syllabification"
                    throw :problem
                end
            
                # Get Etymology
            
                open( "http://www.etymonline.com/index.php?term=#{@word}" ) do |html3|
                    soup3 = BeautifulSoup.new( html3.read )
                    dl = soup3.find( 'dl' )
                    if dl != nil
                        dl.find_all( 'dt' ).each do |dt|
                            if dt.a[ 'href' ] == "/index.php?term=#{@word}"
                                dd = dt.find_next_sibling( 'dd' )
                                dd.contents.each do |item|
                                    if item.is_a? NavigableString
                                        item.scan(
                                            /((?:^|(?:from(?: a)?|akin to|cf\.|of|as|related to) (?:(?:north|south|east|west)(?:east|west)?(?:ern)? +)?)(#{@etym_lang_regexp.join('|')}))/
                                        ) do |lang|
                                            full_lang = lang[ 0 ]
                                            actual_lang = lang[ 1 ]
                                            if ETYM_LANGS.keys.include?( actual_lang )
                                                etymology << full_lang << ' '
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if etymology.empty?
                    tag = soup2.find( 'hr' )
                    if tag != nil
                        tag = tag.next_sibling
                    end
                    while tag != nil
                        if tag.is_a? NavigableString
                            etymology << tag unless tag =~ /%\w+:/
                        elsif tag.name == "hr"
                            break
                        end
                        tag = tag.next_sibling
                    end
                    etymology.gsub!( /[\n]|[^\w\s]/, " " )
                    etymology.gsub!( /\s{2,}/, " " )
                    etymology.gsub!( /\b[Ss]ee\b/, "" )
                    etymology.strip!
                    etymology.gsub!( /\s*(after|diminuitive|earlier|of|from|perhaps|possibly|probably|variant)\W*$/i, "" )
                end
                
                if etymology.empty?
                    #$stderr.puts "#{@word}\tno etymology"
                    etymology = 'unknown'
                    #throw :problem
                end
                
                # Get part of speech and definition
                
                # Two sources: wordsmyth.net and dictionary.com.
                # Try one, then the other if first failed.
                
                open( "http://www.wordsmyth.net/live/home.php?script=search&matchent=#{@word}&matchtype=exact" ) do |html3|
                    soup3 = BeautifulSoup.new( html3.read )
                    
                    span = soup3.find( 'span', :attrs => { 'class' => 'fieldValue', 'style' => 'font-weight: normal;' } )
                    if span != nil
                        definition = span.string
                    end
                    
                    span = soup3.find( 'span', :attrs => { 'class' => 'fieldValue', 'style' => 'color: #CC0000; font-size: 95%;' } )
                    if span != nil
                        part_of_speech = span.string
                    else
                        part_of_speech = ''
                        td = soup3.find_all(
                            'td',
                            :attrs => {
                                'valign' => 'top',
                                'align' => 'left',
                                'width' => '70%'
                            }
                        )[ 1 ]
                        if not td.nil?
                            td.span.contents.each do |item|
                                if item.is_a? NavigableString
                                    part_of_speech << item
                                end
                            end
                        end
                    end
                end
                
                if definition.empty? or part_of_speech.empty?
                    tag = soup2.find( [ 'dd', 'li' ] )
                    if tag != nil and ! tag.has_anchor_in_front?
                        if tag.string
                            definition = tag.string
                        else
                            definition = tag.string_contents
                        end
                        definition.gsub!( /\n/, " " )
                        definition.strip!
                        
                        while tag != nil and tag.name != "td"
                            tag = tag.parent
                        end
                        if tag != nil and tag.i != nil
                            part_of_speech = tag.i.string
                        end
                    end
                    
                    if definition.empty?
                        def_tags = soup2.find_all( 'p' ).find_all { |p| p.contents[ 0 ] =~ /\\/ }
                        if not def_tags.empty?
                            defn = def_tags[ 0 ].string_contents
                            defn = defn[ /^(.+?)(?:--|$)/, 1 ].strip
                            if defn =~ /^\\(\S+?)\\, ([\w.]+?) \[((?:[A-Z][a-z]*\. )+).+\] (.+)$/
                                lm = Regexp.last_match
                                part_of_speech = lm[ 2 ]
                                if etymology == 'unknown'
                                    etymology = lm[ 3 ].strip
                                end
                                definition = lm[ 4 ].strip
                                syllables = lm[ 1 ]
                                syllabification = syllables.split( /\W+/ )
                            end
                        end
                    end
                end
            end
        
            if definition.empty?
                $stderr.puts "#{@word}\tno definition"
                throw :problem
            end
            
            if part_of_speech.empty?
                $stderr.puts "#{@word}\tno part of speech"
                throw :problem
            end
            
            while not @die
                begin
                    if @suggester_id != nil
                        puts "Noting suggestion of #{@word} by #{@suggester.nick}..."
                    end
                    word_rec = Word.create( {
                        :word => @word,
                        :num_syllables => syllabification.length,
                        :pos => part_of_speech,
                        :etymology => etymology,
                        :definition => definition,
                        :suggester => @suggester_id
                    } )
                    if @suggester != nil
                        @suggester.update_attribute( :money, @suggester.money + 10 )
                        @award += 10
                        if @award >= MAX_AWARD
                            @suggester = nil
                        end
                    end
                    $stdout.print "."; $stdout.flush
                    break
                rescue ActiveRecord::StatementInvalid => e
                    case e.message
                        when /no connection to the server/
                            #$stderr.puts "No DB connection?  Attempting reconnect... (#{@connection_attempts})"
                            $stderr.puts "No DB connection?"
                            #ActiveRecord::Base.remove_connection
                            #ensureConnectedToDB
                            @die = 2
                        when /duplicate key violates unique constraint "words_word_key"/
                            $stderr.puts "#{@word} already in DB?"
                            @suggester_id = nil
                            break
                        else
                            raise e
                    end
                end
            end
            
            @num_spidered += 1
        end
        @suggester_id = nil
    end
end


if $0 == __FILE__
    #puts "#{$0} [seed word] [suggester] [number of words to get]"
    #exit 1
        
    spider = WordSpider.new( ARGV[ 0 ], ARGV[ 1 ], ARGV[ 2 ] || 500 )
    spider.start
    
    if spider.die
        exit spider.die
    end
end

