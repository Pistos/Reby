#!/usr/bin/env ruby

ps = `/bin/ps aux | /bin/egrep 'postgres: word word 127.0.0.1' | /bin/grep idle | /bin/grep -v grep`
pids = ps.scan( /postgres\s+(\d+)/ )

if pids.length > 0
    puts pids.join( ';' )
    puts `/bin/kill -s TERM #{pids.join( ' ' )} 2>&1`
end