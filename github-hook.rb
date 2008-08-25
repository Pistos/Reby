# This listens for connections from the github-hook server,
# which is running independently, receiving POSTs from github.com.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'eventmachine'
require 'json'
require 'nice-inspect'
require 'open-uri'
require 'cgi'

module GitHubHookServer
  
  # Mapping of repo names to interested channels
  REPOS = {
    'better-benchmark' => [ '#mathetes', '#ruby-pro' ],
    'diakonos' => [ '#mathetes', '#ruby-pro' ],
    'github' => [ '#mathetes' ],
    'linistrac' => [ '#mathetes', '#ramaze', '#ruby-pro' ],
    'm4dbi' => [ '#mathetes', '#ruby-dbi', '#ruby-pro' ],
    'nagoro' => [ '#mathetes', '#ramaze' ],
    'ramaze' => [ '#mathetes', '#ramaze', '#ruby-pro' ],
    'ramaze-book' => [ '#mathetes', '#ramaze' ],
    'ruby-dbi' => [ '#mathetes', '#ruby-dbi', '#ruby-pro' ],
    'sociar' => [ '#ramaze' ],
    'weewar-ai' => [ '#mathetes' ],
    'zepto-url' => [ '#mathetes', '#ramaze', '#ruby-pro' ],
  }
  
  def say( message, destination = "#mathetes" )
    $reby.putserv "PRIVMSG #{destination} :#{message}"
  end
  
  def say_rev( rev, message, destination )
    @seen = Hash.new
    s = ( @seen[ destination ] ||= Hash.new )
    if not s[ rev ]
      say( message, destination )
      s[ rev ] = true
    end
  end
  
  def receive_data( data )
    hash = JSON.parse( data )
    
    if hash[ 'ref' ] =~ %r{/(master|development)$}
      repo = hash[ 'repository' ][ 'name' ]
      owner = hash[ 'repository' ][ 'owner' ][ 'name' ]
      channels = REPOS[ repo ]
        
      hash[ 'commits' ].each do |cdata|
        author = cdata[ 'author' ][ 'name' ]
        message = cdata[ 'message' ].gsub( /\s+/, ' ' )[ 0..384 ]
        url = URI.parse( 'http://zep.purepistos.net/zep/1?uri=' + CGI.escape( cdata[ 'url' ] ) ).read
        text = "[github] <#{author}> #{message} [#{repo}] #{url}"
        
        if channels.nil? or channels.empty?
          say "Unknown repo: '#{repo}'", '#mathetes'
          say text, '#mathetes'
        else
          channels.each do |channel|
            say_rev cdata[ 'id' ], text, channel
          end
        end
      end
    end
    
    close_connection
  end
end

class GitHubHookReceiver
  def initialize
    @thread = Thread.new do
      EventMachine::run do
        EventMachine::start_server '127.0.0.1', 9005, GitHubHookServer
      end
    end
  end
end

$receiver = GitHubHookReceiver.new