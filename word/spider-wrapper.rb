#!/usr/bin/env ruby

def runOnce( word = nil )
    return if word != nil and word.length < 4
    puts
    puts " --- Restarting Spider ----------------------------------------"
    puts 
    return system( "ruby spider-words.rb #{word}" )
end

result = nil
if ARGV.length > 0
    start_at = ARGV[ 1 ]
    File.foreach( ARGV[ 0 ] ) do |line|
        word = line.strip
        next if word !~ /^[a-z-]{4,}$/
        if start_at != nil
            if word != start_at
                next
            else
                start_at = nil
            end
        end
        result = runOnce( word )
        exit_code = $? >> 8
        if ! result && ( exit_code != 2 ) && exit_code != 0
            break
        end
    end
else
    exit_code = 0
    while result || ( exit_code == 2 ) || ( exit_code == 0 )
        result = runOnce
        exit_code = $? >> 8
    end
end
puts "End.  exit code: #{$?}"