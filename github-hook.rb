# This listens for connections from the github-hook server,
# which is running independently, receiving POSTs from github.com.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'eventmachine'
require 'json'

module GitHubHookServer
  
  # Mapping of repo names to interested channels
  REPOS = {
    'better-benchmark' => [ '#mathetes' ],
    'diakonos' => [ '#mathetes' ],
    'github' => [ '#mathetes' ],
    'linistrac' => [ '#mathetes', '#ramaze' ],
    'm4dbi' => [ '#mathetes', '#ruby-dbi' ],
    'nagoro' => [ '#mathetes', '#ramaze' ],
    'ramaze' => [ '#mathetes', '#ramaze' ],
    'ramaze-book' => [ '#mathetes', '#ramaze' ],
  }
  
  def say( message, destination = "#ramaze" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end
  
  def receive_data( data )
    hash = JSON.parse( data )
    repo = hash[ 'repository' ][ 'name' ]
    hash[ 'commits' ].each do |rev,cdata|
      author = cdata[ 'author' ][ 'name' ]
      message = cdata[ 'message' ]
      text = "[github] <#{author}> #{message} [#{repo}]"
      
      channels = REPOS[ repo ]
      
      if channels.nil? or channels.empty?
        say "Unknown repo: '#{repo}'", '#mathetes'
        say text, '#mathetes'
      else
        channels.each do |channel|
          say text, channel
        end
      end
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