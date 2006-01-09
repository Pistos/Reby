# spell.rb 

# Confirms spelling of words, and suggests possible corrections.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

class String
    def escapeQuotes
        temp = ""
        each_byte do |b|
            if b == 39
                temp << 39
                temp << 92
                temp << 39
            end
            temp << b
        end
        
        return temp
    end
end

class Spell
    MAX_WORD_LENGTH = 50
    NUM_SUGGESTIONS = 15
    
    def initialize
        $reby.bind( "pub", "-", "!spell", "check", "$spell" )
    end
    
    def check( nick, userhost, handle, channel, args_ )
        args = args_.to_a
        language = "en"
        word = nil
        $reby.log( "args: '#{args}' (#{args.class})" )
        case args.length
            when 0
                retval = "!spell [language code] word"
            when 1
                word = args[ 0 ]
            else
                $reby.log( "#{args[ 0 ]} (#{args[ 0 ].class})" )
                $reby.log( "#{args[ 1 ]} (#{args[ 1 ].class})" )
                lang = args[ 0 ].downcase
                word = args[ 1 ]
                case lang
                    when "en", "de", "fr", "pt", "es", "it"
                        language = lang
                end
        end
        if word != nil
            if word.length > MAX_WORD_LENGTH
                retval = "That's not a real word!  :P"
            else
                #aspell = `echo #{word.escapeQuotes} | /usr/local/bin/aspell -a --sug-mode=bad-spellers --personal=/Users/mtidwell/.aspell.en.pws"`
                aspell = `echo '#{word.escapeQuotes}' | aspell -d #{language} -a --sug-mode=bad-spellers`
            
                list = aspell.split( ":" )
                result = list[ 0 ]
   
                if result =~ /\*$/
                    retval = "#{word} is spelled correctly."
                else
                    words = list[ 1 ].strip.split( "," )
                    retval = "'#{word}' is probably one of: #{words[ 0, NUM_SUGGESTIONS ].join( ', ' )}"
                end
            end
            
        end
        
        $reby.putserv( "PRIVMSG #{channel} :#{retval}" )
    end    
end

$spell = Spell.new