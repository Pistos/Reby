#!/usr/bin/env ruby
#
# sovietrussia.rb 

# A Reby script which makes the bot spit out Soviet Russia jokes based on in-channel chat.

# By Pistos - irc.freenode.net#mathetes

# This is script is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).
# But it can be run from the command line, as well.

begin
    require 'active_support'
rescue Exception
    #ignore
end
require 'open-uri'

class Constituent < Array
    attr_reader :kind, :remainder
    
    # parts is an array containing the space-separated parts of the parse
    def initialize( parts )
        @kind = parts[ 0 ][ /^\[(\S+)/, 1 ]
        unparsed = parts[ 1..-1 ]
        while unparsed != nil and part = unparsed.shift
            case part 
                when /^\[/
                    unparsed.unshift part
                    c = Constituent.new( unparsed )
                    push c
                    unparsed = c.remainder
                when /\]$/
                    break
                else
                    push part.downcase
            end
        end
        @remainder = unparsed
    end
    
    def to_s
        output = "[#{@kind} "
        each do |part|
            output << "#{part.to_s} "
        end
        output << "#{@kind}]"
    end
    
    def text
        output = ""
        each do |part|
            case part
                when String
                    output << "#{part} "
                when Constituent
                    output << "#{part.text} "
            end
        end
        return output
    end
    
    def in_soviet_russia
        agent = nil
        verb_phrase = nil
        
        catch( :found ) do
            each_with_index do |part,index|
                case part
                    when Constituent
                        if part.kind == "VP"
                            subpart = part[ 1 ]
                            if(
                                subpart and
                                subpart.class == Constituent and
                                subpart.kind == "NP" and
                                /^(?:you|we|us|i|me|they|them|it|he|she|him|her|this|that|those|these|\w*self|mathetes)\b/i !~ subpart.text.strip and
                                subpart.text.strip.length < SovietRussia::MAX_NP_LENGTH
                            )
                                agent = subpart
                                verb_phrase = part[ 0 ]
                                throw :found
                            end
                        end
                        
                        # Not found in this VP.  Check children.
                        agent, verb_phrase = part.in_soviet_russia
                        if agent and verb_phrase
                            throw :found
                        end
                end
            end
        end
        
        if agent
            agent, plural = agent.noun_adjust
        end
        if verb_phrase
            base_form, habitual_form = verb_phrase.inflect
            if base_form and habitual_form
                if plural
                    verb_phrase = base_form
                else
                    verb_phrase = habitual_form
                end
            else
                verb_phrase = nil
            end
        end
        if not verb_phrase
            #
        elsif verb_phrase =~ /^(?:is|was|are|were|be|has|have|mines|.)$/ or verb_phrase =~ /-/
            verb_phrase = nil
        end
        return [ agent, verb_phrase ]
    end
    
    def noun_adjust
        all_strings = true
        plural = false
        each do |part|
            case part
                when Constituent
                    all_strings = false
            end
        end
        if all_strings
            text.noun_adjust
        else
            each_with_index do |part,i|
                case part
                    when Constituent
                        result, pluralized = self[ i ].noun_adjust
                        self[ i ] = result
                        if i == 0
                            plural = pluralized
                        elsif pluralized
                            #$reby.log "plural, but index = #{i}"
                        end
                end
            end
            [ text, plural ]
        end
    end
end

class String
    def noun_adjust
        retval = self.strip
        plural = false
        if /^(?:an?|some|several|many|one|my|your|their|his|her|our) (.+)$/i =~ retval
            retval = $1.strip.pluralize
            plural = true
        else
            if retval.pluralize == retval
                plural = true
            end
        end
        [ retval, plural ]
    end
    
    def inflect
        self_ = self.strip.downcase
        base_form = nil
        habitual_form = nil
        begin
            open( "http://dictionary.reference.com/search?q=#{self_}" ) do |http|
                text = http.read
                if %r{.+American Heritage Dictionary.+?<table><tbody><tr><td><b>(.+?)</b>.+?<b>([^<]+)</b>\s*<br /}m =~ text
                    base_form = $1
                    habitual_form = $2
                    if not base_form.nil?
                        base_form.gsub!( '&#183;', '' )
                    end
                    if not habitual_form.nil?
                        habitual_form.gsub!( '&#183;', '' )
                    end
                end
            end
        rescue Exception => e
            $reby.log e.message
            $reby.log e.backtrace.join( "\n\t" )
        end
        if base_form and habitual_form
            [ base_form.strip, habitual_form.strip ]
        else
            [ nil, nil ]
        end
    end
end

module SovietRussia
    PARSER_BIN = '/misc/src/link-4.1b/parse'
    PARSER_DATA_DIR = '/misc/src/link-4.1b/data'
    WORD_COUNT_MINIMUM = 3
    MAX_NP_LENGTH = 40
    
    class NotInSovietRussiaException < Exception; end
    
    def process_in_sr( line )
        stimulus_path = 'stimulus.txt'
        File.open( stimulus_path, "w" ) do |f|
            f.puts "!verbosity=0"
            f.puts "!graphics"
            f.puts "!constituents=2"
            f.puts line
        end
    
        parse_result = `#{PARSER_BIN} #{PARSER_DATA_DIR}/4.0.dict -pp #{PARSER_DATA_DIR}/4.0.knowledge -c #{PARSER_DATA_DIR}/4.0.constituent-knowledge -a #{PARSER_DATA_DIR}/4.0.affix < #{stimulus_path} 2>/dev/null`
        parse_text = parse_result.split( "\n" )[ -1 ]
        $stderr.puts "parse_text: #{parse_text}"
        
        parse = Constituent.new( parse_text.split )
        
        $stderr.puts "parse: #{parse.inspect}"
        
        # [VP eat [NP cabbage NP] VP]
        agent, verb_phrase = parse.in_soviet_russia
        
        response = nil
        if agent and verb_phrase
            response = "HA!  In Soviet Russia, #{agent} #{verb_phrase} YOU!"
        else
            $stderr.puts "agent: #{agent}"
            $stderr.puts "vp: #{verb_phrase}"
            raise NotInSovietRussiaException.new( "That does not happen in Soviet Russia." )
        end
        
        return response
    end
end

class SovietRussiaProcessor
    include SovietRussia
    
    def initialize
    end
    
    def process( text )
        begin
            process_in_sr( text )
        rescue NotInSovietRussiaException => e
            e.message
        end
    end
end

class SovietRussiaReby
    include SovietRussia
    
    # Add bot names to this list, if you like.
    IGNORED = [ "", "*" ]
    MIN_SPACING = 30 * 60 # seconds
    
    def initialize
        $reby.bind( "raw", "-", "PRIVMSG", "sawPRIVMSG", "$sovietrussia" )
        $reby.bind( "pub", "-", "!sr", "soviet_russia", "$sovietrussia" )
        @auto = {
            '#mathetes' => true,
            '#mathetes-dev' => true,
            '#rendergods' => false,
            '#wordbattle' => true,
            '#chat-bots' => true,
        }
        @last_time = @auto.dup
        @last_time.each_key do |k|
            @last_time[ k ] = Time.now - MIN_SPACING
        end
    end
    
    def send( message, channel )
        $reby.putserv "PRIVMSG #{channel} :" + message
    end
    
    def sawPRIVMSG( from, keyword, text )
        if from =~ /^(.+?)!/
            nick = $1
            channel, speech = text.split( " :", 2 )
            channel.downcase!
            if @last_time[ channel ].nil? or ( 
                Time.now - @last_time[ channel ] > MIN_SPACING
            )
                if not IGNORED.include?( nick ) and @auto[ channel ]
                    speech.gsub!( /[\\{}()]/, '' )
                    if speech =~ /^\w/ and speech !~ /^mathetes/i
                        if speech.split.length >= WORD_COUNT_MINIMUM
                            begin
                                send( "#{nick}: " + process_in_sr( speech ), channel )
                                @last_time[ channel ] = Time.now
                            rescue NotInSovietRussiaException => e
                                if not @auto[ channel ]
                                    send( "#{nick}: #{e.message}", channel )
                                end
                                #$reby.log "agent: #{agent}"
                                #$reby.log "vp: #{verb_phrase}"
                                #$reby.log parse.to_s
                            end
                        end
                    end
                end
            else
                $reby.log "[soviet_russia] No nick?  '#{from}' !~ /^(.+?)!/"
            end
        end
    end
    
    def soviet_russia( nick, userhost, handle, channel, args )
        if args.split.length < 2
            case args.downcase
                when "on"
                    @auto[ channel ] = true
                    send "Soviet Russia mode activated in '#{channel}'.", channel
                when "off"
                    @auto[ channel ] = false
                    send "Soviet Russia mode deactivated in '#{channel}'.", channel
            end
        else
            old_auto = @auto[ channel ]
            @auto[ channel ] = false
            
            begin
                send( "#{nick}: " + process_in_sr( args.to_s ), channel )
            rescue NotInSovietRussiaException => e
                send( "#{nick}: #{e.message}", channel )
            end
            
            @auto[ channel ] = old_auto
        end
    end
end

if __FILE__ == $0
    # Command line
    processor = SovietRussiaProcessor.new
    while line = gets
        puts processor.process( line )
    end
else
    # Reby
    $sovietrussia = SovietRussiaReby.new
end
