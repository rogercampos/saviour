# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'saviour/version'

Gem::Specification.new do |spec|
  spec.name          = "saviour"
  spec.version       = Saviour::VERSION
  spec.authors       = ["Roger Campos"]
  spec.email         = ["roger@itnig.net"]
  spec.description   = %q{Simple active record file uplading handler}
  spec.summary       = %q{Simple active record file uplading handler}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 3.0"
  spec.add_dependency "activesupport", ">= 3.0"
  spec.add_dependency "fog-aws"
  spec.add_dependency "mime-types"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "sqlite3"
end
