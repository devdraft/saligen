# frozen_string_literal: true

require_relative 'lib/devdraft'

Gem::Specification.new do |spec|
  spec.name          = 'devdraft-sdk'
  spec.version       = Devdraft::VERSION
  spec.authors       = ['devdraft']
  spec.email         = ['engineering@devdraft.ai']

  spec.summary       = 'Ruby SDK for DevDraft API with production-ready features'
  spec.description   = 'Production-ready Ruby SDK for DevDraft API with built-in support for authentication, retries, pagination, and error handling'
  spec.homepage      = 'https://github.com/yourorg/yourapi-ruby'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/yourorg/yourapi-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/yourorg/yourapi-ruby/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/yourorg/yourapi-ruby/issues'
  spec.metadata['documentation_uri'] = 'https://rubydoc.info/gems/yourapi'

  spec.files = Dir['lib/**/*.rb', 'README.md', 'LICENSE']
  spec.require_paths = ['lib']

  # No runtime dependencies - uses only standard library
  
  # Development dependencies
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'webmock', '~> 3.18'
end

