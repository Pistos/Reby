#!/usr/bin/env ruby

# This script spiders the web for new words to add to the word.rb game.

require 'open-uri'

syl = 0

( "a".."z" ).each do |letter|
    
    tiscali_index = URI.parse( "http://www.tiscali.co.uk/reference/dictionaries/difficultwords/data/content_#{letter}.html" ).read
    tiscali_index.split( /\n/ ).each do |line|
        if line =~ /^<a href="(.+?)">([a-z]+)<\/a><br \/>$/
            url = $1
            word = $2
            
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
            
            next if syllabification == nil
            
            # Get Etymology
            
            etymology = nil
            dict_lines.each do |line2|
                if line2 =~ />\[([^<].+?)\]/
                    etym1 = $1
                    etym1.gsub!( /<TT>.+?<\/TT>/, " " )
                    etym1.gsub!( /<I>.+?<\/I>/, " " )
                    etym1.gsub!( /<B>.+?<\/B>/, " " )
                    etym1.gsub!( /<SUP>.+?<\/SUP>/, " " )
                    etym1.gsub!( /&nbsp;/, " " )
                    etym1.gsub!( /&#\d+;/, " " )
                    if etym1 =~ /[<>]/ or etym1 =~ /&[a-z]+;/
                        $stderr.puts "Warning: '#{word}' has HTML in etymology."
                    end
                    etymology = etym1
                end
            end
            
            next if etymology == nil
            
            # Get part of speech and definition
            
            tiscali_ref = URI.parse( "http://www.tiscali.co.uk" + url ).read
            if tiscali_ref != nil
                rest = tiscali_ref[ /mdhdr">#{word}<(.+)/m, 1 ]
                rest =~ /<i>(.+?)<\/i>(.+)/m
                part_of_speech = $1
                rest = $2
                if rest != nil
                    definition = rest[ /(.+?)</m, 1 ]
                    definition.gsub!( /\n/, " " )
                end
            end
            
            next if definition == nil or definition.length < 10
            
            #puts "#{word}: #{syllabification.join('-')}"
            #puts "#{part_of_speech} #{definition}"
            #puts etymology
            puts "#{word}_#{syllabification.length}_#{part_of_speech}_#{etymology}_#{definition}"
            $stdout.flush
        end
        
    end
end