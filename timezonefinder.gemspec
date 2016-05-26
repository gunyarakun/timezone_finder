# -*- encoding: utf-8 -*-
require File.expand_path('../lib/timezonefinder/gem_version', __FILE__)

Gem::Specification.new do |s|
  s.name     = 'timezonefinder'
  s.version  = TimezoneFinder::VERSION
  s.license  = 'MIT'
  s.email    = 'tasuku-s-github@titech.ac'
  s.homepage = 'https://github.com/gunyarakun/timezonefinder'
  s.authors  = ['Tasuku SUENAGA a.k.a. gunyarakun']

  s.summary     = 'Look up timezone from lat / long offline.'
  s.description = %(
    Python library to look up timezone from lat / long offline.
    Ported version of "timezonefinder" on PyPI.
  ).strip.gsub(/\s+/, ' ')

  s.files         = %w( README.md LICENSE ) + Dir['lib/**/*.rb']

  s.executables   = %w()
  s.require_paths = %w( lib )

  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = '1.6.2'
  if s.respond_to? :required_rubygems_version=
    s.required_rubygems_version = Gem::Requirement.new('>= 0')
  end
  s.required_ruby_version = '>= 2.2.0'
  s.specification_version = 3 if s.respond_to? :specification_version
end
