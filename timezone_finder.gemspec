lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'timezone_finder/gem_version'

Gem::Specification.new do |spec|
  spec.name          = 'timezone_finder'
  spec.version       = TimezoneFinder::VERSION
  spec.authors       = ['Tasuku SUENAGA a.k.a. gunyarakun']
  spec.email         = ['tasuku-s-github@titech.ac']

  spec.summary       = 'Look up timezone from lat / long offline.'
  spec.description   = %(
    A pure Ruby library to look up timezone from latitude / longitude offline.
    Ported version of 'timezonefinder' on PyPI.
  ).strip.gsub(/\s+/, ' ')
  spec.homepage      = 'https://github.com/gunyarakun/timezone_finder'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^test/})
  end
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop', '~> 0.52'
  spec.add_development_dependency 'simplecov', '~> 0.11'
end
