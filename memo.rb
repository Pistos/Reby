# memo.rb 

# Basic public memo system.
# Delivers messages when recipient is seen to be active in the channel.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'm4dbi'

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
        $reby.bind( "pub", "-", "!memo", "record_memo", "$reby_memo" )
        @dbh = DBI.connect( "DBI:Pg:reby-memo", "memo", "memo" )
    end
    
    def put( message, destination = @channel )
        $reby.putserv "PRIVMSG #{destination} :#{message}"
    end
    
    def splitput( text, dest )
        text.scan( /.{1,400}/ ) do |text_part|
            put text_part, dest
        end
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
            age = memo[ 'sent_age' ].gsub( /\.\d+$/, '' )
            case age
                when /^00:00:(\d+)/
                    age = "#{$1} seconds"
                when /^00:(\d+):(\d+)/
                    age = "#{$1}m #{$2}s"
                else
                    age.gsub( /^(.*)(\d+):(\d+):(\d+)/, "\\1 \\2h \\3m \\4s" )
            end
            splitput "#{nick}: [#{age} ago] <#{memo['sender']}> #{memo['message']}", dest
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
    
    def record_memo( nick, userhost, handle, channel, args )
        @channel = channel
        sender = nick
        recipient, message = args.split( /\s+/, 2 )
        
        if sender and recipient and message and not recipient.empty? and not message.empty?
            if recipient =~ %r{^/(.*)/$}
                recipient_regexp = Regexp.new $1
                @dbh.do(
                    "INSERT INTO memos ( sender, recipient_regexp, message ) VALUES ( ?, ?, ? )",
                    sender,
                    recipient_regexp.source,
                    message
                )
                put "#{nick}: Memo recorded for /#{recipient_regexp.source}/."
            else
                if memos_for( recipient ).size >= MAX_MEMOS_PER_PERSON
                    put "The inbox of #{recipient} is full."
                else
                    @dbh.do(
                        "INSERT INTO memos ( sender, recipient, message ) VALUES ( ?, ?, ? )",
                        sender,
                        recipient,
                        message
                    )
                    put "#{nick}: Memo recorded for #{recipient}."
                end
            end
        else
            put "#{nick}: !memo <recipient> <message>"
        end
    end
    
    def memos_for( recipient )
        @dbh.select_all(
            %{
                SELECT
                    m.*,
                    age( NOW(), m.time_sent )::TEXT AS sent_age
                FROM
                    memos m
                WHERE
                    (
                        m.recipient = ?
                        OR ? ~ m.recipient_regexp
                    )
                    AND m.time_told IS NULL
            },
            recipient,
            recipient
        )
    end
end

$reby_memo = MemoManager.new