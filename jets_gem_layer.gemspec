# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jets_gem_layer/version'

Gem::Specification.new do |spec|
  spec.name          = 'jets_gem_layer'
  spec.version       = JetsGemLayer::VERSION
  spec.authors       = ['DocGo Engineering']
  spec.license       = 'MIT'
  spec.required_ruby_version = '~> 3.2'

  spec.summary       = 'Rake tasks to automate building a Lambda Layer for Ruby on Jets projects'
  spec.description   = 'This gem provides Rake tasks to create and publish an AWS Lambda Layer from project gems ' \
                       'and their linked libraries. Designed for use with Ruby on Jets 5.'
  spec.homepage      = 'https://github.com/ambulnzllc/jets_gem_layer'
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_dependency 'jets', '~> 5.0'
  spec.add_dependency 'rake'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
