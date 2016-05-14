$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "synchro/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "synchro"
  s.version     = Synchro::VERSION
  s.authors     = ["dmcnelis"]
  s.email       = ["davemcnelis@gmail.com"]
  s.homepage    = ""
  s.summary     = "Synchro(nize) News Feeds."
  s.description = "Synchro(nize) News Feeds."

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f) }

  s.add_dependency 'rake', '~> 11.1.2' # A make-like build utility for Ruby
  s.add_dependency 'nokogiri', '~> 1.6.7' # HTML, XML, SAX, and Reader parser
  s.add_dependency 'open_uri_redirections', '~> 0.2.1' # OpenURI allow redirections between HTTP and HTTPS
  s.add_dependency 'redis', '~> 3.2.2' # Ruby client library for Redis
  s.add_dependency 'rubyzip', '~> 1.2.0' # Ruby zip

  s.add_development_dependency 'rspec', '~> 3.4.0' # Behaviour driven development
  s.add_development_dependency 'fakeredis', '~> 0.5.0' # Fake implementation of redis-rb
  s.add_development_dependency 'vcr', '~> 2.9.3' # Record test suite's HTTP interactions
  s.add_development_dependency 'webmock', '~> 1.21.0' # Stubbing and setting expectations on HTTP requests
  s.add_dependency 'awesome_print', "~> 1.6.1" # Pretty Print Ruby

end
