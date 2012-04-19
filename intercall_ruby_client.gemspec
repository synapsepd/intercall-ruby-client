$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "intercall_ruby_client/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "intercall_ruby_client"
  s.version     = IntercallRubyClient::VERSION
  s.authors     = ["Adam Saegebarth"]
  s.email       = ["adams@synapse.com"]
  s.homepage    = "https://github.com/synapsepd"
  s.summary     = "A client for the Intercall Owner API"
  s.description = s.summary

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_development_dependency "rake"
  s.add_development_dependency "savon", "~> 0.9.9"
  s.add_development_dependency "redis"
  s.add_development_dependency "synapse_redis_logger"
  s.add_development_dependency "rspec",    "~> 2.5.0"
  s.add_development_dependency "settingslogic"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
end