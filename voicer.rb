# voicer.rb 

# Gives voice to those in the channel as they speak.
# Removes voice from them if they haven't spoken for some time.

# By Pistos - irc.freenode.net#geobot

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require "thread"

class Voicer
    # Time in minutes before devoicing someone for idleness.
    IDLE_TIME = 20
    CHANNEL = "#geoshell"
    # Time in minutes between devoice checks.
    CHECK_INTERVAL = 2
    # Add bot names to this list, if you like.
    IGNORED = [
        "",
        "*",
        "MathetesUnloved",
        "linker",
        "Gherkins",
        "Mathetes",
        "GeoBot",
        "SixtYNinE"
    ]
    
    def initialize
        @last_spoke_time = Hash.new
        @idle_seconds = IDLE_TIME * 60
        @mutex = Mutex.new
        
        #$reby.bind( "pubm", "-", "#{CHANNEL} *", "heardSpeech", "$voicer" )
        $reby.bind( "pub", "-", "!voicer", "voiceTest", "$voicer" )
        $reby.bind( "raw", "-", "PRIVMSG", "sawPRIVMSG", "$voicer" )
        
        act
    end
    
    def giveVoice( nick, channel = CHANNEL )
        #$reby.putserv "MODE #{channel} +v #{who}"
        #$reby.putlog "Voicing #{nick} in #{channel}..."
        $reby.putserv "PRIVMSG ChanServ :voice #{channel} #{nick}"
    end
    
    def takeVoice( nick, channel = CHANNEL )
        #$reby.putserv "MODE #{channel} -v #{nick}"
        #$reby.putlog "Devoicing #{nick} in #{channel}..."
        $reby.putserv "PRIVMSG ChanServ :voice #{channel} -#{nick}"
    end
    
    def voiceTest( nick, userhost, handle, channel, args )
        giveVoice( args.to_s, channel )
        takeVoice( args.to_s, channel )
    end
    
    def act
        @mutex.synchronize do
            now = Time.now
            devoiced = Array.new
            @last_spoke_time.each do |speaker,time|
                if now - time > @idle_seconds
                    # Idle too long!  Devoice.
                    #who = $reby.hand2nick( speaker, CHANNEL )
                    who = speaker
                    if who != ""
                        takeVoice( who )
                        $reby.log "devoiced after #{now - time} seconds."
                    end
                    devoiced.push speaker
                end
            end
            devoiced.each do |speaker|
                @last_spoke_time.delete speaker
            end
            
            $reby.timer( CHECK_INTERVAL, "act", "$voicer" )
        end    
    end
    
    def processActivity( nick, channel )
        if not IGNORED.include?( nick )
            if @last_spoke_time[ nick ] == nil
                giveVoice( nick )
            end
            @last_spoke_time[ nick ] = Time.now
        end
            
    end
    
    def heardSpeech( nick, userhost, handle, channel, args )
        if channel == CHANNEL
            processActivity( nick, channel )
        else
            #$reby.log "Voicer: #{channel} != #{CHANNEL}"
        end
    end
    
    def sawPRIVMSG( from, keyword, text )
        from = from.to_s
        delimiter_index = from.index( "!" )
        if delimiter_index != nil
            nick = from[ 0...delimiter_index ]
            channel, speech = text.split( " :", 2 )
            if channel == CHANNEL
                processActivity( nick, channel )
            elsif not $reby.isbotnick( channel )
                $reby.log "Bad channel: '#{channel}' (#{channel.class}) !~ '#{CHANNEL}'"
            end
        else
            $reby.log "[voicer] No nick?  '#{from}' (#{from.index( '!' )})"
        end
    end
end

$voicer = Voicer.new