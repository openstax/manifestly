# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manifestly/version'

Gem::Specification.new do |spec|
  spec.name          = "manifestly"
  spec.version       = Manifestly::VERSION
  spec.authors       = ["JP Slavinsky"]
  spec.email         = ["jps@kindlinglabs.com"]

  spec.summary       = %q{Manage multi-site deploy manifests}
  spec.homepage      = "https://github.com/openstax/manifestly"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'thor'
  spec.add_dependency 'rainbow'
  spec.add_dependency 'command_line_reporter'
  spec.add_dependency 'git'

  spec.add_development_dependency 'byebug'
  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
