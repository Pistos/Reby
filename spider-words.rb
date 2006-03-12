#!/usr/bin/env ruby

# This script spiders the web for new words to add to the word.rb game.

require 'open-uri'
require 'rubyful_soup'
require 'cgi'
require 'word-ar-defs'

words = Array.new

ActiveRecord::Base.establish_connection(
    :adapter  => "postgresql",
    :host     => "localhost",
    :username => "word",
    :password => "word",
    :database => "word"
)


[
    "2006/03",
    "2006/02",
    "2006/01",
    "2005/12",
    "2005/11",
    "2005/10",
    "2005/09",
    "2005/08",
    "2005/07",
    "2005/05",
    "2005/04",
    "2005/03",
    "2005/02",
    "2005/01",
    "2004/12",
    "2004/11",
    "2004/10",
    "2004/09",
    "2004/08",
    "2004/07",
    "2004/05",
    "2004/04",
    "2004/03",
    "2004/02",
    "2004/01",
    "2003/12",
    "2003/11",
    "2003/10",
    "2003/09",
    "2003/08",
    "2003/07",
    "2003/05",
    "2003/04",
    "2003/03",
    "2003/02",
    "2003/01",
    "2002/12",
    "2002/11",
    "2002/10",
    "2002/09",
    "2002/08",
    "2002/07",
    "2002/05",
    "2002/04",
    "2002/03",
    "2002/02",
    "2002/01",
    "2001/12",
    "2001/11",
    "2001/10",
    "2001/09",
    "2001/08",
    "2001/07",
    "2001/05",
    "2001/04",
    "2001/03",
    "2001/02",
    "2001/01",
    "2000/12",
    "2000/11",
    "2000/10",
    "2000/09",
    "2000/08",
    "2000/07",
    "2000/05",
    "2000/04",
    "2000/03",
    "2000/02",
    "2000/01",
].each do |yearmonth|
    open( "http://dictionary.reference.com/wordoftheday/archive/#{yearmonth}" ) do |html|
        $stderr.puts yearmonth
        
        soup = BeautifulSoup.new( html.read )
        
        soup.find_all( 'li' ).each do |li|
            word = li.a.string
            
            if word !~ /\s/
                words << word
            end
        end
    end
end
            
words.each do |word|
    #begin
        next if Word.find_by_word( word )
        $stderr.puts "** #{word}"
    
        definition = ''
        part_of_speech = ''
        
        dict_ref = URI.parse( "http://dictionary.reference.com/search?q=#{word}" ).read
        dict_lines = dict_ref.split( /\n/ )
        
        # Check for syllabification
        
        syllabification = nil
        dict_lines.each do |line2|
            if line2 =~ /<b>([a-z]+(?:&#183;[a-z]+)+)<\/b>/
                syllables = $1.split( /&#183;/ )
                if syllables.join( "" ) == word
                    syllabification = syllables
                    break
                end
            end
        end
        
        if syllabification.nil?
            $stderr.puts "No syllabification"
            next
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
                next
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
            next
        end
        
        if part_of_speech.empty?
            $stderr.puts "No part of speech"
            next
        end
        
        word_rec = Word.create( {
            :word => word,
            :num_syllables => syllabification.length,
            :pos => part_of_speech,
            :etymology => etymology,
            :definition => definition
        } )
        
        #puts "#{word}_#{syllabification.length}_#{part_of_speech}_#{etymology}_#{definition}"
        #$stdout.flush
    #rescue Exception => e
        #$stderr.puts "Exception while scraping for '#{word}': #{e.message}"
        #$stderr.puts e.backtrace.join( "\n\t" )
    #end
end