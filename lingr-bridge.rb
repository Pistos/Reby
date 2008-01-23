require '/misc/svn/reby/api_client.rb'

class LingrBridge
    IRC_CHANNEL = "#ramaze"
    LINGR_ROOM = 'ramaze'
    LINGR_NICK = '#ramaze'
    IGNORED = [
        "",
        "*",
        "Mathetes",
    ]
    LINGR_KEY = "10e6b842efa8460bb8a441bb9a2039b3"
    LINGR_HOSTNAME = 'www.lingr.com'
    
    def initialize
        @c = Lingr::ApiClient.new( LINGR_KEY, 0, LINGR_HOSTNAME )
        @c.create_session( 'automaton' )
        
        enter_room
        set_nickname
        
        $reby.bind( "raw", "-", "PRIVMSG", "sawPRIVMSG", "$lingr" )
    end
    
    def log( message )
        $reby.log "[lingr] #{message}"
    end
    
    def sawPRIVMSG( from, keyword, text )
        from = from.to_s
        delimiter_index = from.index( "!" )
        if delimiter_index != nil
            nick = from[ 0...delimiter_index ]
            channel, speech = text.split( " :", 2 )
            if channel == IRC_CHANNEL and not IGNORED.include?( nick )
                resp = @c.say( @ticket, "<#{nick}> #{speech}" )
                log "say failed : #{resp[:response].inspect}" if ! resp[ :succeeded ]
            end
        else
            log "[voicer] No nick?  '#{from}' (#{from.index( '!' )})"
        end
    end
    
    # Lingr stuff
    
    def enter_room
        resp = @c.enter_room( LINGR_ROOM )
        if resp[ :succeeded ]
            @ticket = resp[:response]["ticket"]
            @counter = resp[:response]["room"]["counter"] if resp[:response]["room"]["counter"]
            @me = resp[:response]["occupant_id"]
            @roster = {}
            @high_counter = 0
            @room_observe_thread = Thread.new { room_observe_loop( LINGR_ROOM ) }
            update_room_status resp[:response]
        else
            log "enter failed : #{resp[:response].inspect}"
        end
    end
    
    def set_nickname( nick = LINGR_NICK )
        resp = @c.set_nickname( @ticket, nick )
        log "set_nickname failed : #{resp[:response].inspect}" if ! resp[ :succeeded ]
    end
    
    def room_observe_loop( name )
      log "Starting observe loop for room #{name}"
      while true
        resp = @c.observe_room @ticket, @counter
        if resp[:succeeded]
          @counter = resp[:response]["counter"] if resp[:response]["counter"]
          update_room_status( resp[:response] )
        else
          log "observe failed : #{resp[:response].inspect}"
        end
      end
    end
    
    def update_room_status( response )
      updated = false

      if response["messages"] and response["messages"].length > 0
        response["messages"].each do |m|
          next if m["id"] and m["id"].to_i <= @high_counter
          
          text = m["text"]
          type = m["type"]

          if type == 'user' or type == 'private'
            occupant_id = m["occupant_id"]
            if occupant_id != @me or type == 'private'
              updated = true
              nickname = m["nickname"]
              if type == 'private'
                log "PRIVATE MESSAGE from #{nickname}: #{text}"
              else
                $reby.putserv "PRIVMSG #{IRC_CHANNEL} :[lingr] <#{nickname}> #{text}"
              end
            end
          elsif type.index('system:') == 0
            updated = true
            log "SYSTEM: #{text}"
          else
            log "unknown message type: #{type}, #{text}"
          end
          
          @high_counter = m["id"].to_i if m["id"]
        end
      end

      roster_present = !response["occupants"].nil?
      new_roster = {}

      observers = 0
      named = 0

      if roster_present
        response["occupants"].each do |o|
          new_roster[o["id"]] = o["nickname"]
          if !o["nickname"].nil?
            named += 1
          else
            observers += 1
          end
        end

        if roster_present and @roster != new_roster
          updated = true
          @roster = new_roster
        end
      end

      updated
    end
end

$lingr = LingrBridge.new