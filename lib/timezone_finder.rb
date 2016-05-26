require_relative 'timezone_finder/timezone_finder'
require_relative 'timezone_finder/gem_version'

module TimezoneFinder
  def self.create
    TimezoneFinder.new
  end
end
