#!/usr/bin/env ruby

# This script spiders the web for new words to add to the word.rb game.

require 'open-uri'
require 'rubyful_soup'
require 'cgi'
require 'word-ar-defs'


class WordSpider
    
    def initialize( seed_word )
        @seen_words = Array.new
        @next_words = [ seed_word ]
        
        ActiveRecord::Base.establish_connection(
            :adapter  => "postgresql",
            :host     => "localhost",
            :username => "word",
            :password => "word",
            :database => "word"
        )
    end
    
    def start
        while not @next_words.empty?
            @word = @next_words.shift
            getWord
            if @next_words.size < 50
                gatherRelated
            end
        end
    end
    
    def gatherRelated
        other_words = Array.new
        open( "http://dictionary.reference.com/search?q=#{@word}" ) do |html|
            $stderr.puts @word
            
            soup = BeautifulSoup.new( html.read )
            
            soup.find_all( 'a', :attrs => { 'href' => /\/search\?q=[A-z]+/ } ).each do |a|
                a[ 'href' ] =~ /([A-z]+)$/
                other_word = $1
                if other_word != nil and not other_word.empty?
                    other_words << other_word
                end
            end
        end
        
        $stderr.puts other_words.join( '; ' )
        retval = nil
        other_words.each do |word|
            if not @seen_words.include?( word ) and Word.find_by_word( word ).nil?
                @next_words << word
                break
            end
        end
    end
    
    def getWord
        word = @word
        @seen_words << word
        catch( :problem ) do
            $stderr.puts "** #{word}"
        
            definition = ''
            part_of_speech = ''
            
            dict_ref = URI.parse( "http://dictionary.reference.com/search?q=#{word}" ).read
            dict_lines = dict_ref.split( /\n/ )
            
            # Check for syllabification
            
            syllabification = nil
            dict_lines.each do |line2|
                if line2 =~ /<b>([a-z]+(?:&#183;[a-z]+)*)<\/b>.* &nbsp;&nbsp;/
                    syllables = $1.split( /&#183;/ )
                    if syllables.join( "" ) == word
                        syllabification = syllables
                        break
                    end
                end
            end
            
            if syllabification.nil?
                $stderr.puts "No syllabification"
                throw :problem
            end
            
            # Get Etymology
            
            etymology = ''
            open( "http://dictionary.reference.com/search?q=#{word}" ) do |html2|
                soup2 = BeautifulSoup.new( html2.read )
                
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
                etymology.gsub!( /\s*(of|from)$/, "" )
                
                if etymology.empty?
                    $stderr.puts "No etymology"
                    throw :problem
                end
                
                # Get part of speech and definition
                
                # Two sources: wordsmyth.net and dictionary.com.
                # Try one, then the other if first failed.
                
                open( "http://www.wordsmyth.net/live/home.php?script=search&matchent=#{word}&matchtype=exact" ) do |html3|
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
                    tag = soup2.find( 'dd' )
                    if tag.nil?
                        tag = soup2.find( 'li', :attrs => { 'type' => 'a' } )
                    end
                    if tag.nil?
                        tag = soup2.find( 'li' )
                    end
                    if tag
                        definition = tag.string || ''
                        definition.gsub!( /\n/, " " )
                        
                        while tag != nil and tag.name != "td"
                            tag = tag.parent
                        end
                        if tag != nil
                            part_of_speech = tag.i.string
                        end
                    end
                    
                end
            end
        
            if definition.empty?
                $stderr.puts "No definition"
                throw :problem
            end
            
            if part_of_speech.empty?
                $stderr.puts "No part of speech"
                throw :problem
            end
            
            word_rec = Word.create( {
                :word => word,
                :num_syllables => syllabification.length,
                :pos => part_of_speech,
                :etymology => etymology,
                :definition => definition
            } )
        end
    end
end


if $0 == __FILE__
    if ARGV.length < 1
        puts "#{$0} <seed word>"
        exit 1
    end

    spider = WordSpider.new( ARGV[ 0 ] )
    spider.start
end

