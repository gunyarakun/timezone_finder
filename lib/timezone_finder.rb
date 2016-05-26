require_relative 'timezone_finder/timezone_finder'

module TimezoneFinder
  def self.create
    TimezoneFinder.new
  end
end
