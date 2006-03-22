#!/usr/bin/env ruby

command = Time.now.strftime( "pg_dump -f /home/geobot/backups/word-db-%Y-%m-%d.sql -C -O -U postgres word" )
puts command
`#{command}`