# sovietrussia.rb 

# A Reby script which makes the bot spit out Soviet Russia jokes based on in-channel chat.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

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
                            if subpart and subpart.class == Constituent and subpart.kind == "NP" and /^(?:i|you|we|me|they|them|it|he|she|him|her|us|this|that|those|these|\w*self)$/i !~ subpart.text.strip
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
        elsif verb_phrase =~ /^(?:is|are|be|has|have)$/
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
        if /^(?:an?|some|several|many|one) (.+)$/i =~ retval
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
                if /(?:\d+ results|1 result) for: <em>#{self_}<\/em>.+?American Heritage Dictionary.+?<TABLE><TR><TD><b>(.+?)<\/b>.+?<B> *(\S+) *<\/B><br \/>/m =~ text
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

class SovietRussia
    # Add bot names to this list, if you like.
    IGNORED = [ "", "*" ]
    PARSER_BIN = '/misc/src/link-4.1b/parse'
    PARSER_DATA_DIR = '/misc/src/link-4.1b/data'
    WORD_COUNT_MINIMUM = 3
    MIN_SPACING = 5 * 60 # seconds
    
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
                    if speech =~ /^\w/
                        if speech.split.length >= WORD_COUNT_MINIMUM
                            process( speech, channel, nick )
                        end
                    end
                end
            else
                $reby.log "[soviet_russia] No nick?  '#{from}' !~ /^(.+?)!/"
            end
        end
    end
    
    def process( line, channel, target = nil )
        stimulus_path = 'stimulus.txt'
        File.open( stimulus_path, "w" ) do |f|
            f.puts "!verbosity=0"
            f.puts "!graphics"
            f.puts "!constituents=2"
            f.puts line
        end
    
        parse_result = `#{PARSER_BIN} #{PARSER_DATA_DIR}/4.0.dict -pp #{PARSER_DATA_DIR}/4.0.knowledge -c #{PARSER_DATA_DIR}/4.0.constituent-knowledge -a #{PARSER_DATA_DIR}/4.0.affix < #{stimulus_path} 2>/dev/null`
        parse_text = parse_result.split( "\n" )[ -1 ]
        
        parse = Constituent.new( parse_text.split )
        
        # [VP eat [NP cabbage NP] VP]
        agent, verb_phrase = parse.in_soviet_russia
        
        if agent and verb_phrase
            if target
                target_str = target + ": "
            end
            send "#{target_str}HA!  In Soviet Russia, #{agent} #{verb_phrase} YOU!", channel
            @last_time[ channel ] = Time.now
        else
            if not @auto[ channel ]
                send "#{target_str}That doesn't happen in Soviet Russia.", channel
            end
            $reby.log "agent: #{agent}"
            $reby.log "vp: #{verb_phrase}"
            $reby.log parse.to_s
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
            process( args.to_s, channel, nick )
            @auto[ channel ] = old_auto
        end
    end
end

$sovietrussia = SovietRussia.new
