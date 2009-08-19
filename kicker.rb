# kicker.rb

# Kicks people based on public PRIVMSG regexps.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

class Kicker
  CHANNELS = [
    "#mathetes",
    '#christian',
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
      },
    ],
    /.+/ => [
      # {
        # :regexps => [
          # %r{http://TheBibleGeek\.org},
          # %r{http://webulite\.com},
        # ],
        # :reasons => [
          # "You've mentioned that URL enough times.  Please restrict further advertisement of it to private messages.  Thank you.",
        # ],
      # },
      {
        :regexps => [
          /\bkicktest\b/i,

          /\banus\b/i,
          /\bcock\b/i,
          /\bfag\b/i,
          /\bgive me head\b/i,
          /\bnigga\b/i,
          /\bnigger\b/i,
          /\btits\b/i,
          /\btitties\b/i,
          /\bturds?\b/i,
          /\bmy wang\b/i,
          /anal sex/i,
          /asshole/i,
          /my balls/i,
          /bitch/i,
          /blow ?job/i,
          /cunt/i,
          /dick/i,
          /dumbass/i,
          /fuck/i,
          /masturbat/i,
          /oral sex/i,
          /orgasm/i,
          /penis/i,
          /pussy/i,
          /pussies/i,
          /shit/i,
          /suck my/i,
          /vagina/i,
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
        :exempted => [
          'Pistos',
          'Grace',
          'scry',
          'Gherkins',
          'MathetesUnloved',
          'SpyBot',
        ]
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
        if CHANNELS.find { |c| c.downcase == channel.downcase }
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