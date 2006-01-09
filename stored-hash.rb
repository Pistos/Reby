#!/usr/bin/env ruby

# A Hash which is automatically marshalled to disk on every change.
# Be careful to synchronize properly when using this class in a multithreaded
# situation.

require 'thread'

class StoredHash
    attr_reader :hash
    
    def initialize( filename, default_value = nil )
        @filename = filename
        if FileTest.exist?( @filename )
            # Read instance from file.
            File.open( filename ) do |f|
                @hash = Marshal.load( f )
            end
        else
            @hash = Hash.new( default_value )
        end
    end
    
    # Writes the hash out to file.
    def sync
        File.open( @filename, "w" ) do |f|
            Marshal.dump( @hash, f )
        end
    end
    private :sync
    
    def ==( other )
        return ( @hash == other.hash )
    end
    
    def []( key )
        return @hash[ key ]
    end
    
    def []=( key, value )
        retval = nil
        retval = ( @hash[ key ] = value )
        sync
        return retval
    end
    
    def clear
        @hash.clear
        sync
        return self
    end
    
    def default
        return @hash.default
    end
    def default=( new_default )
        @hash.default = new_default
        sync
        return self
    end
    
    def delete( key )
        retval = @hash.delete( key )
        sync
        return retval
    end
    
    def delete_if
        @hash.delete_if do |key,value|
            yield( key, value )
        end
        sync
        return self
    end
    
    def each
        @hash.each do |key,value|
            yield( key, value )
        end
        return self
    end
    
    def each_key
        @hash.each_key do |key|
            yield( key )
        end
        return self
    end
    
    def each_pair
        @hash.each do |key,value|
            yield( key, value )
        end
        return self
    end
    
    def each_value
        @hash.each_value do |value|
            yield( value )
        end
        return self
    end
    
    def empty?
        return @hash.empty?
    end
   
    def has_key?( key )
        return @hash.has_key?( key )
    end
    
    def has_value?( value )
        return @hash.has_value?( value )
    end
    
    def include?( key )
        return @hash.include?( key )
    end
    
    def index( value )
        return @hash.index( value )
    end
    
    def key?( key )
        return @hash.key?( key )
    end
    
    def keys
        return @hash.keys
    end
    
    def length
        return @hash.length
    end
    
    def member?( key )
        return @hash.member?( key )
    end
    
    def shift
        retval = @hash.shift
        sync
        return retval
    end
    
    def size
        return @hash.size
    end
    
    def to_a
        return @hash.to_a
    end
    
    def to_s
        return @hash.to_s
    end
    
    def value?( value )
        return @hash.value?( value )
    end
    
    def values
        return @hash.values
    end
end