#!/usr/bin/env ruby

ps = `ps aux | egrep 'postgres: word word 127.0.0.1' | grep -v grep`
pids = ps.scan( /postgres\s+(\d+)/ )

if pids.length > 0
    puts pids.join( ';' )
    puts `kill -s TERM #{pids.join( ' ' )} 2>&1`
end