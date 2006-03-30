#!/usr/bin/env ruby

# Random number generator.
# Gives random numbers out based on data from www.random.org.
# Caches downloaded data, fetching only once per day at most.

require 'net/http'

class RandomDotOrg

    CACHE_FILE = "random.cache"
    CACHE_POINTER_FILE = "random.cache.pointer"
    FORCE_UPDATE = true
    DONT_FORCE_UPDATE = false
    CACHE_SIZE = 16384  # Number of bytes in the cache -- must be less than 16385
    
    def updateCacheFile
        success = false
        begin
            Net::HTTP.start( 'www.random.org', 80 ) do |http|
                http.read_timeout = 60 * 10  # 10 minute timeout
                path = "/cgi-bin/randbyte?nbytes=#{CACHE_SIZE}&format=hex"
                response = http.get( path )
                bytes_text = response.body.gsub( /\n/, "" )
                File.open( CACHE_FILE, "w" ) do |f|
                    f.puts bytes_text
                end
            end
            success = true
        rescue Exception
            $stderr.puts "(HTTP timeout)"
        end
        
        return success
    end
    
    def readCachePointer
        @cptr = 0
        begin
            if File.exist?( CACHE_POINTER_FILE )
                File.open( CACHE_POINTER_FILE ) do |f|
                    @cptr = f.gets.chomp.to_i
                end
            end
        rescue Exception
            # ignore
        end
    end
    
    def readCacheFile
        File.open( CACHE_FILE ) do |f|
            line = f.gets.chomp
            @bytes = line.split( /\s+/ ).collect { |b| b.to_i( 16 ) }
        end
    end
    
    def initialize( num_to_generate = 1, resolution = 2, force_update = DONT_FORCE_UPDATE )
        @num_to_generate = num_to_generate
        @resolution = resolution
        @divisor = ( 256**@resolution ).to_f
        
        if force_update
            update_cache = true
        else
            if File.exist?( CACHE_FILE )
                # Older than a day?
                update_cache = ( File.stat( CACHE_FILE ).mtime < Time.now - ( 60 * 60 * 24 ) )
            else
                update_cache = true
            end
        end
    
        updateCacheFile if update_cache
    
        readCachePointer
        readCacheFile
    end
    
    # Returns an array containing the generated values.
    def generate( ceiling = 1 )
        generated_numbers = Array.new
        while generated_numbers.length < @num_to_generate
            # Fill a local byte array from the cache.
            
            value = 0
            ( 0...@resolution ).each do |b|
                value += @bytes[ @cptr ] * ( 256**b )
                @cptr += 1
                if @cptr >= CACHE_SIZE
                    updateCacheFile
                    readCacheFile
                    @cptr = 0
                end
            end
            number = ( value / @divisor ) * ceiling
            if( ceiling > 1 )
                number = number.to_i
            end
            generated_numbers.push( number )
        end
        
        # Update cache pointer file.
        
        File.open( CACHE_POINTER_FILE, "w" ) do |f|
            f.puts @cptr
        end
        
        return generated_numbers
    end
    
end

