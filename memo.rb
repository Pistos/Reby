# memo.rb 

# Basic public memo system.
# Delivers messages when recipient is seen to be active in the channel.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'dbi'

class MemoManager
    # Add bot names to this list, if you like.
    IGNORED = [
        "",
        "*",
        "Gherkins",
        "Mathetes",
        "GeoBot",
        "scry",
    ]
    MAX_MEMOS_PER_PERSON = 20
    PUBLIC_READING_THRESHOLD = 2
    
    def initialize
        $reby.bind( "raw", "-", "PRIVMSG", "saw_PRIVMSG", "$reby_memo" )
        $reby.bind( "pub", "-", "!memo", "memo_command", "$reby_memo" )
        @dbh = DBI.connect( "DBI:Pg:reby-memo", "memo", "memo" )
    end
    
    def splitput( text, dest )
        text.scan( /.{1,400}/ ) do |text_part|
            put text_part, dest
        end
    end
    
    def put( message, destination = @channel )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end
    
    def process_activity( nick, channel )
        return if IGNORED.include?( nick )
        
        memos = memos_for( nick )
        if memos.size <= PUBLIC_READING_THRESHOLD
            dest = channel
        else
            dest = nick
        end
        
        memos.each do |memo|
            t = memo[ 'time_sent' ].to_time.strftime( "%b %d %H:%M" )
            splitput "#{nick}: [#{t}] <#{memo['sender']}> #{memo['message']}", dest
            @dbh.do(
                "UPDATE memos SET time_told = NOW() WHERE id = ?",
                memo[ 'id' ]
            )
        end
    end
    
    def saw_PRIVMSG( from, keyword, text )
        from = from.to_s
        delimiter_index = from.index( "!" )
        if delimiter_index != nil
            nick = from[ 0...delimiter_index ]
            channel, speech = text.split( " :", 2 )
            process_activity( nick, channel )
        else
            $reby.log "[memo] No nick?  '#{from}' (#{from.index( '!' )})"
        end
    end
    
    def memo_command( nick, userhost, handle, channel, args_ )
        @channel = channel
        command, args = args_.split( /\s+/, 2 )
        case command
            when /^(s|t)/
                recipient, message = args.split( /\s+/, 2 )
                if memos_for( nick ).size >= MAX_MEMOS_PER_PERSON
                    put "The inbox of #{recipient} is full."
                else
                    send_memo( nick, recipient, message )
                    put "#{nick}: Memo sent to #{recipient}."
                end
        end
    end
    
    def send_memo( sender, recipient, message )
        @dbh.do(
            "INSERT INTO memos ( sender, recipient, message ) VALUES ( ?, ?, ? )",
            sender,
            recipient,
            message
        )
    end
    
    def memos_for( recipient )
        @dbh.select_all(
            "SELECT * FROM memos WHERE recipient = ? AND time_told IS NULL",
            recipient
        )
    end
end

$reby_memo = MemoManager.new