# This is not a standalone Ruby script; it is meant to be run
# from Reby (reby.conf).

# "Unowned" methods can be defined, just be careful about namespace conflicts,
# and also consider whether the Reby class has a method of the same name.
def test( nick, userhost, handle, channel, text )
    if text.class == Array
        text2 = text.toTclList
        text2.sub!( /^\{/, "" )
        text2.sub!( /\}$/, "" )
        text2 = text2.gsub( /\{/, "\\{" ).gsub( /\}/, "\\}" )
    else
        text2 = text
    end
    $reby.putserv "PRIVMSG #{channel} :Test called: #{nick}, #{userhost}, #{handle}, #{channel}, #{text2}."
end
$reby.bind( "pub", "-", "!reby", "test" )

def countus( nick, userhost, handle, channel, text )
    num = $reby.countusers
    $reby.putserv "PRIVMSG #{channel} :#{num} (#{num.class})"
end
$reby.bind( "pub", "-", "!countusers", "countus" )

class SampleRebyClass
    def initialize
    end
    def anotherTest( nick, userhost, handle, channel, text )
        $reby.putserv "PRIVMSG #{channel} :#{text}"
    end
    def chanlist( nick, userhost, handle, channel, text )
        listing = ""
        $reby.chanlist( channel ).each do |member|
            listing += member + " "
        end
        $reby.putserv "PRIVMSG #{channel} :#{listing}"
    end
    def ided( nick, userhost, handle, channel, text )
        name = text.to_s
        if $reby.checkIfIdentified( name )
            $reby.putserv "PRIVMSG #{channel} :#{name} has identified."
        else
            $reby.putserv "PRIVMSG #{channel} :#{name} has not identified."
        end
        $reby.putserv "PRIVMSG #{channel} :#{name} --> done."
    end
end
$sample = SampleRebyClass.new
$reby.bind( "pub", "-", "!reby2", "anotherTest", "$sample" )
$reby.bind( "pub", "-", "!chanlist", "chanlist", "$sample" )
$reby.bind( "pub", "-", "!ided", "ided", "$sample" )

return_id = $reby.evalTcl( "countusers" )
puts "Got back: " + $reby.getReturnValue( return_id )
