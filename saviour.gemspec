require './lib/saviour/version'

Gem::Specification.new do |spec|
  spec.name          = "saviour"
  spec.version       = Saviour::VERSION
  spec.authors       = ["Roger Campos"]
  spec.email         = ["roger@rogercampos.com"]
  spec.description   = %q{File storage handler following active record model lifecycle}
  spec.summary       = %q{File storage handler following active record model lifecycle}
  spec.homepage      = "https://github.com/rogercampos/saviour"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.2.0"

  spec.add_dependency "activerecord", ">= 5.0"
  spec.add_dependency "activesupport", ">= 5.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "fog-aws"
  spec.add_development_dependency "mime-types"
  spec.add_development_dependency "get_process_mem"
end
