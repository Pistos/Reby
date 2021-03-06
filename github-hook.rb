# This listens for connections from the github-hook server,
# which is running independently, receiving POSTs from github.com.

# By Pistos - irc.freenode.net#mathetes

# This is not a standalone Ruby script; it is meant to be run from Reby
# (http://purepistos.net/eggdrop/reby).

require 'json'
require 'nice-inspect'
require 'open-uri'
require 'cgi'

module GitHubHookServer

  # Mapping of repo names to interested channels
  REPOS = {
    'better-benchmark'        => [ '#mathetes', ],
    'buildmybike'             => [ '#ramaze', ],
    'diakonos'                => [ '#mathetes', ],
    'dk-git'                  => [ '#mathetes', ],
    'dk-selector'             => [ '#mathetes', ],
    'firewatir-enhancements'  => [ '#mathetes', '#watir' ],
    'ffi-tk'                  => [ '#ver', ],
    'firewatir-enhancements'  => [ '#mathetes', '#watir' ],
    'github'                  => [ '#mathetes' ],
    'hoptoad-notifier-ramaze' => [ '#mathetes', '#ramaze' ],
    'innate'                  => [ '#mathetes', '#ramaze', ],
    'linistrac'               => [ '#mathetes', '#ramaze', ],
    'm4dbi'                   => [ '#mathetes', '#ruby-dbi', ],
    'nanoc'                   => [ '#nanoc', ],
    'nagoro'                  => [ '#mathetes', '#ramaze' ],
    'Ramalytics'              => [ '#mathetes', '#ramaze' ],
    'Reby'                    => [ '#mathetes', ],
    'ramaze'                  => [ '#mathetes', '#ramaze', ],
    'ramaze-book'             => [ '#mathetes', '#ramaze' ],
    'ramaze-proto'            => [ '#mathetes', '#ramaze' ],
    'ramaze.net'              => [ '#ramaze', ],
    'ramaze-wiki-pages'       => [ '#mathetes', '#ramaze' ],
    'ruby-dbi'                => [ '#mathetes', '#ruby-dbi', ],
    'rvm'                     => [ '#rvm', ],
    'selfmarks'               => [ '#mathetes', ],
    'sociar'                  => [ '#ramaze' ],
    'ver'                     => [ '#ver' ],
    'watir-mirror'            => [ '#mathetes', '#watir' ],
    'weewar-ai'               => [ '#mathetes' ],
    'zepto-url'               => [ '#mathetes', '#ramaze', ],
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
    $reby.log "DATA RECEIVED"
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
        text = "[\00300github\003] [\00303#{repo}\003] <\00307#{author}\003> #{message} #{url}"

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
          say "[\00300github\003] [\00303#{repo}\003] #{commits.size} commits by: \00307#{authors.join( ', ' )}\003  #{first_url}", channel
        end
      end

    end

    close_connection
  end
end

class GitHubHookReceiver
  def initialize
    @thread = Thread.new do
      loop do
        EventMachine::run do
          EventMachine::start_server '127.0.0.1', 9005, GitHubHookServer
        end
        $reby.log "*** EventMachine died; restarting ***"
      end
    end
  end
end

$receiver = GitHubHookReceiver.new