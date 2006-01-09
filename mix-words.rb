#!/usr/bin/env ruby

# Randomizes the order of the lines of a file.

exit if ARGV.length < 1
lines = IO.readlines( ARGV[ 0 ] )

while lines.length > 0
    puts lines.delete_at( rand( lines.length ) )
end