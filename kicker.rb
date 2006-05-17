# kicker.rb

# Kicks people based on public PRIVMSG regexps.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

class Kicker
    CHANNELS = [
        "#mathetes",
    ]
    WATCHLIST = {
        'scry' => [
            {
                :regexps => [
                    /^(\S+): chamber \d of \d => \*BANG\*/
                ],
                :reasons => [
                    'You just shot yourself!',
                    'Suicide is never the answer.',
                    'If you wanted to leave, you could have just said so...',
                    "Good thing these aren't real bullets...",
                ],
                :exempted => [
                    'Specimen',
                ],
            },
        ],
        /.+/ => [
            {
                :regexps => [
                    /\banus\b/,
                    /\bcock\b/,
                    /\bfag\b/,
                    /\bgive me head\b/,
                    /\bnigga\b/,
                    /\bnigger\b/,
                    /\btits\b/,
                    /\btitties\b/,
                    /\bturds?\b/,
                    /\bmy wang\b/,
                    /anal sex/,
                    /asshole/,
                    /my balls/,
                    /bitch/,
                    /blow ?job/,
                    /cunt/,
                    /dick/,
                    /dumbass/,
                    /fag/,
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
                ],
                :reasons => [
                    'Watch your language.',
                    'Watch your mouth.',
                    'Go wash your mouth out with soap.',
                    'Keep it clean.',
                    "Don't be vulgar.",
                    'No foul language.',
                    'No vulgarity.',
                ],
            }
        ],
    }
    
    def initialize
        $reby.bind( "raw", "-", "PRIVMSG", "sawPRIVMSG", "$kicker" )
    end
    
    def sawPRIVMSG( from, keyword, text )
        catch :kicked do
            from = from.to_s
            delimiter_index = from.index( "!" )
            if delimiter_index != nil
                nick = from[ 0...delimiter_index ]
                channel, speech = text.split( " :", 2 )
                if CHANNELS.include?( channel )
                    WATCHLIST.each do |watch_nick, watchlist|
                        if watch_nick === nick
                            watchlist.each do |watch|
                                watch[ :regexps ].each do |r|
                                    if r =~ speech
                                        victim = $1 || nick
                                        if not watch[ :exempted ] or not watch[ :exempted ].include?( victim )
                                            reasons = watch[ :reasons ]
                                            $reby.putkick(
                                                channel,
                                                [ victim ],
                                                '{' + 
                                                    reasons[ rand( reasons.size ) ] +
                                                '}'
                                            )
                                            throw :kicked
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            else
                $reby.log "[kicker] No nick?  '#{from}' (#{from.index( '!' )})"
            end
        end
    end
end

$kicker = Kicker.new