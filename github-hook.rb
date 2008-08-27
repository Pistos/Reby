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
    @seen ||= Hash.new
    s = ( @seen[ destination ] ||= Hash.new )
    if not s[ rev ]
      say( message, destination )
      s[ rev ] = true
    end
  end
  
  def zepto_url( url )
    URI.parse( 'http://zep.purepistos.net/zep/1?uri=' + CGI.escape( url ) ).read
  end
  
  def receive_data( data )
    hash = JSON.parse( data )
    
    repo = hash[ 'repository' ][ 'name' ]
    owner = hash[ 'repository' ][ 'owner' ][ 'name' ]
    channels = REPOS[ repo ]
    
    commits = hash[ 'commits' ]
    
    if commits.size < 7
      
      # Announce each individual commit
      
      commits.each do |cdata|
        author = cdata[ 'author' ][ 'name' ]
        message = cdata[ 'message' ].gsub( /\s+/, ' ' )[ 0..384 ]
        url = zepto_url( cdata[ 'url' ] )
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
      
    else
      
      # Too many commits; say a summary only
      
      authors = commits.map { |c| c[ 'author' ][ 'name' ] }.uniq
      shas = commits.map { |c| c[ 'id' ] }
      first_url = zepto_url( commits[ 0 ][ 'url' ] )
      if channels and not channels.empty?
        channels.each do |channel|
          @seen ||= Hash.new
          s = ( @seen[ channel ] ||= Hash.new )
          shas.each do |sha|
            s[ sha ] = true
          end
          say "[github] #{commits.size} commits to #{repo} by: #{authors.join( ', ' )}  #{first_url}"
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