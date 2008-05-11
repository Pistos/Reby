# This listens for connections from the github-hook server,
# which is running independently, receiving POSTs from github.com.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'eventmachine'
require 'json'

module GitHubHookServer
  def say( message, destination = "#ramaze" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end
  
  def receive_data( data )
    hash = JSON.parse( data )
    hash[ 'commits' ].each do |rev,data|
      author = data[ 'author' ][ 'name' ]
      message = data[ 'message' ]
      say "[github] <#{author}> #{message}"
    end
    close_connection
  end
end

class GitHubHookReceiver
  def initialize
    @thread = Thread.new do
      Thread.new do
        EventMachine::run do
          EventMachine::start_server '127.0.0.1', 9005, GitHubHookServer
        end
      end
    end
  end
end

$receiver = GitHubHookReceiver.new