#
# = api_client.rb
#
# Lingr API client
#
# $Revision$
# $Date$
#

$KCODE = 'u'
require 'jcode'
require 'net/http'
require 'cgi'

# Ruby client for the Lingr[http://www.lingr.com] API.  For more details and tutorials, see the 
# {Lingr API Reference}[http://wiki.lingr.com/dev/show/API+Reference] pages on the {Lingr Developer Wiki}[http://wiki.lingr.com].
#
# All methods return a hash with two keys:
# * :succeeded - <tt>true</tt> if the method succeeded, <tt>false</tt> otherwise
# * :response - a Hash version of the response document received from the server
#

module Lingr
  
  class ApiClient
    attr_accessor :api_key
    # 0 = quiet, 1 = some debug info, 2 = more debug info
    attr_accessor :verbosity
    attr_accessor :session
    attr_accessor :timeout

    def initialize(api_key, verbosity=0, hostname='www.lingr.com')
      @api_key = api_key
      @host = hostname
      @verbosity = verbosity
      @timeout = 120
    end

    # Create a new API session
    #
    def create_session(client_type='automaton')
      if @session
        p "already in a session", 1
        @error_info = nil
        return { :succeeded => false }
      end

      ret = do_api :post, 'session/create', { :api_key => @api_key, :client_type => client_type }, false
      @session = ret[:response]["session"] if ret[:succeeded]
      ret
    end
    
    # Verify a session id.  If no session id is passed, verifies the current session id for this ApiClient
    #
    def verify_session(session_id=nil)
      do_api :get, 'session/verify', { :session => session_id || @session }, false
    end

    # Destroy the current API session
    # 
    def destroy_session
      ret = do_api :post, 'session/destroy', { :session => @session }
      @session = nil
      ret
    end

    # Get a list of the currently hot rooms
    #
    def get_hot_rooms(count=nil)
      do_api :get, 'explore/get_hot_rooms', { :api_key => @api_key }.merge(count ? { :count => count} : {}), false
    end

    # Get a list of the newest rooms
    #
    def get_new_rooms(count=nil)
      do_api :get, 'explore/get_new_rooms', { :api_key => @api_key }.merge(count ? { :count => count} : {}), false
    end

    # Get a list of the currently hot tags
    #
    def get_hot_tags(count=nil)
      do_api :get, 'explore/get_hot_tags', { :api_key => @api_key }.merge(count ? { :count => count} : {}), false
    end

    # Get a list of all tags 
    #
    def get_all_tags(count=nil)
      do_api :get, 'explore/get_all_tags', { :api_key => @api_key }.merge(count ? { :count => count} : {}), false
    end

    # Search room name, description, and tags for keywords.  Keywords can be a String or an Array.
    #
    def search(keywords)
      do_api :get, 'explore/search', { :api_key => @api_key, :q => keywords.is_a?(Array) ? keywords.join(',') : keywords }, false
    end

    # Search room tags. Tagnames can be a String or an Array.
    #
    def search_tags(tagnames)
      do_api :get, 'explore/search_tags', { :api_key => @api_key, :q => tagnames.is_a?(Array) ? tagnames.join(',') : tagnames }, false
    end

    # Search archives. If room_id is non-nil, the search is limited to the archives of that room.
    #
    def search_archives(query, room_id=nil)
      params = { :api_key => @api_key, :q => query }
      params.merge!({ :id => room_id }) if room_id
      do_api :get, 'explore/search_archives', params, false
    end

    # Authenticate a user within the current API session
    #
    def login(email, password)
      do_api :post, 'auth/login', { :session => @session, :email => email, :password => password }
    end

    # Log out the currently-authenticated user in the session, if any
    #
    def logout
      do_api :post, 'auth/logout', { :session => @session }
    end

    # Get information about the currently-authenticated user
    #
    def get_user_info
      do_api :get, 'user/get_info', { :session => @session }
    end

    # Start observing the currently-authenticated user
    #
    def start_observing_user
      do_api :post, 'user/start_observing', { :session => @session }
    end

    # Observe the currently-authenticated user, watching for profile changes
    #
    def observe_user(ticket, counter)
      do_api :get, 'user/observe', { :session => @session, :ticket => ticket, :counter => counter }
    end

    # Stop observing the currently-authenticated user
    #
    def stop_observing_user(ticket)
      do_api :post, 'user/stop_observing', { :session => @session, :ticket =>ticket }
    end

    # Get information about a chatroom, including room description, current occupants, recent messages, etc.
    # 
    def get_room_info(room_id, counter=nil, password=nil)
      params = { :api_key => @api_key, :id => room_id }
      params.merge!({ :counter => counter }) if counter
      params.merge!({ :password => password }) if password
      do_api :get, 'room/get_info', params, false
    end

    # Create a chatroom
    #
    # options is a Hash containing any of the parameters allowed for room.create.  If the :image key is present 
    # in options, its value must be a hash with the keys :filename, :mime_type, and :io
    #
    def create_room(options)
      do_api :post, 'room/create', options.merge({ :session => @session })
    end
    
    # Change the settings for a chatroom
    #
    # options is a Hash containing any of the parameters allowed for room.create.  If the :image key is present 
    # in options, its value must be a hash with the keys :filename, :mime_type, and :io.  To change the id for 
    # a room, use the key :new_id
    #
    def change_settings(room_id, options)
      do_api :post, 'room/change_settings', options.merge({ :session => @session })
    end
    
    # Delete a chatroom
    #
    def delete_room(room_id)
      do_api :post, 'room/delete', { :id => room_id, :session => @session }
    end
    
    # Enter a chatroom
    #
    def enter_room(room_id, nickname=nil, password=nil, idempotent=false)
      params = { :session => @session, :id => room_id }
      params.merge!({ :nickname => nickname }) if nickname
      params.merge!({ :password => password }) if password
      params.merge!({ :idempotent => 'true' }) if idempotent
      do_api :post, 'room/enter', params
    end

    # Poll for messages in a chatroom
    #
    def get_messages(ticket, counter, user_messages_only=false)
      do_api :get, 'room/get_messages', { :session => @session, :ticket => ticket, :counter => counter, :user_messages_only => user_messages_only }
    end

    # Observe a chatroom, waiting for events to occur in the room
    #
    def observe_room(ticket, counter)
      do_api :get, 'room/observe', { :session => @session, :ticket => ticket, :counter => counter }
    end

    # Set your nickname in a chatroom
    #
    def set_nickname(ticket, nickname)
      do_api :post, 'room/set_nickname', { :session => @session, :ticket => ticket, :nickname => nickname }
    end

    # Say something in a chatroom.  If target_occupant_id is not nil, a private message
	# is sent to the indicated occupant.
    #
    def say(ticket, msg, target_occupant_id = nil)
      params = { :session => @session, :ticket => ticket, :message => msg }
      params.merge!({ :occupant_id => target_occupant_id}) if target_occupant_id
      do_api :post, 'room/say', params
    end

    # Exit a chatroom
    #
    def exit_room(ticket)
      do_api :post, 'room/exit', { :session => @session, :ticket => ticket }
    end

    private

    def do_api(method, path, parameters, require_session=true)
      if require_session and !@session
        p "not in a session", 1
        return { :succeeded => false }
      end

      response = json_to_hash(self.send(method, url_for(path), parameters.merge({ :format => 'json' })))
      ret = success?(response)
      if ret
        p "#{path} succeeded", 1
      else
        p "#{path} failed : #{(response and response['error']) ? response['error']['message'] : 'socket timeout'}", 0
      end

      { :succeeded => ret, :response => response }
    end

    def url_for(method)
      "http://#{@host}/#{@@PATH_BASE}#{method}"
    end

    def get(url, params)
      uri = URI.parse(url)
      path = uri.path
      q = params.inject("?") {|s, p| s << "#{p[0].to_s}=#{CGI.escape(p[1].to_s)}&"}.chop
      path << q if q.length > 0

      begin
        Net::HTTP.start(uri.host, uri.port) { |http| 
          http.read_timeout = @timeout
          req = Net::HTTP::Get.new(path)
          req.basic_auth(uri.user, uri.password) if uri.user
          parse_result http.request(req)
        }
      rescue Exception
        p "exception on HTTP GET: #{$!}", 2
        nil
      end
    end

    def post(url, params)
      if !params.find {|p| p[1].is_a?(Hash)}
        begin
          parse_result Net::HTTP.post_form(URI.parse(url), params)
        rescue Exception
          p "exception on HTTP POST: #{$!}", 2
          nil
        end
      else
        boundary = 'lingr-api-client'
        
        query = params.collect do |p|
          ret = "--#{boundary}\r\n"
          
          if p[1].is_a?(Hash)
            ret << "Content-Disposition: form-data; name=\"#{CGI::escape(p[0].to_s)}\"; filename=\"#{p[1][:filename]}\"\r\n" +
                     "Content-Transfer-Encoding: binary\r\n" +
                     "Content-Type: #{p[1][:mime_type]}\r\n" + 
                     "\r\n" + 
                     "#{p[1][:io].read}\r\n"
          else
            ret << "Content-Disposition: form-data; name=\"#{CGI::escape(p[0].to_s)}\"\r\n" + 
              "\r\n" + 
              "#{p[1]}\r\n"
          end
          
          ret
        end.join('') + "--#{boundary}--\r\n"
        
        uri = URI.parse(url)
        begin
          Net::HTTP.start(uri.host, uri.port) do |http|
              http.read_timeout = @timeout
              parse_result http.post2(uri.path, query, "Content-Type" => "multipart/form-data; boundary=#{boundary}")
          end
        rescue Exception
          p "exception on multipart POST: #{$!}", 2
          nil
        end
      end
    end

    def parse_result(result)
      return nil if !result || result.code != '200' || (!result['Content-Type'] || result['Content-Type'].index('text/javascript') != 0)
      result.body
    end

    def success?(response)
      return false if !response
      p response.inspect, 2
      response["status"] and response["status"] == 'ok'
    end

    def p(msg, level=0)
      puts msg if level <= @verbosity
    end

    def json_to_hash(json)
      return nil if !json
      return nil unless /^\s*\{\s*["']/m =~ json
      begin
        null = nil
        return eval(json.gsub(/(["'])\s*:\s*(['"0-9tfn\[{])/){"#{$1}=>#{$2}"}.gsub(/\#\{/, '\#{'))
      rescue SyntaxError
        p $!
        return nil
      else
        return nil
      end
    end

    @@PATH_BASE = 'api/'
  end
end
