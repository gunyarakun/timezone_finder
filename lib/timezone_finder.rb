require_relative 'timezone_finder/timezone_finder'
require_relative 'timezone_finder/gem_version'

module TimezoneFinder
  class CoordinatesOutOfBoundsError < StandardError
    def initialize(lng, lat)
      super "The coordinates are out ouf bounds: (#{lng}, #{lat})"
    end
  end

  def self.create
    TimezoneFinder.new
  end
end
