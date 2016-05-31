# rubocop:disable Metrics/ClassLength,Metrics/MethodLength,Metrics/LineLength
# rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/ParameterLists
# rubocop:disable Style/PredicateName,Style/Next,Style/AndOr
# rubocop:disable Lint/Void
require_relative 'helpers'
require_relative 'timezone_names'

module TimezoneFinder
  # This class lets you quickly find the timezone of a point on earth.
  # It keeps the binary file with the timezonefinder open in reading mode to enable fast consequent access.
  # In the file currently used there are two shortcuts stored per degree of latitude and one per degree of longitude
  # (tests evaluated this to be the fastest setup when being used with numba)
  class TimezoneFinder
    def initialize
      # open the file in binary reading mode
      @binary_file = open(File.join(File.dirname(__FILE__), 'timezone_data.bin'), 'rb')

      # for more info on what is stored how in the .bin please read the comments in file_converter
      # read the first 2byte int (= number of polygons stored in the .bin)
      @nr_of_entries = @binary_file.read(2).unpack('S>')[0]

      # set addresses
      # the address where the shortcut section starts (after all the polygons) this is 34 433 054
      @shortcuts_start = @binary_file.read(4).unpack('L>')[0]

      @nr_val_start_address = 2 * @nr_of_entries + 6
      @adr_start_address = 4 * @nr_of_entries + 6
      @bound_start_address = 8 * @nr_of_entries + 6
      # @poly_start_address = 40 * @nr_of_entries + 6
      @poly_start_address = 24 * @nr_of_entries + 6
      @first_shortcut_address = @shortcuts_start + 259_200

      ObjectSpace.define_finalizer(self, self.class.__del__)
    end

    def self.__del__
      proc do
        @binary_file.close
      end
    end

    def id_of(line = 0)
      # ids start at address 6. per line one unsigned 2byte int is used
      @binary_file.seek((6 + 2 * line))
      @binary_file.read(2).unpack('S>')[0]
    end

    def ids_of(iterable)
      id_array = [0] * iterable.length

      i = 0
      iterable.each do |line_nr|
        @binary_file.seek((6 + 2 * line_nr))
        id_array[i] = @binary_file.read(2).unpack('S>')[0]
        i += 1
      end

      id_array
    end

    def shortcuts_of(lng = 0.0, lat = 0.0)
      # convert coords into shortcut
      x = (lng + 180).floor.to_i
      y = ((90 - lat) * 2).floor.to_i

      # get the address of the first entry in this shortcut
      # offset: 180 * number of shortcuts per lat degree * 2bytes = entries per column of x shortcuts
      # shortcuts are stored: (0,0) (0,1) (0,2)... (1,0)...
      @binary_file.seek(@shortcuts_start + 720 * x + 2 * y)

      nr_of_polygons = @binary_file.read(2).unpack('S>')[0]

      @binary_file.seek(@first_shortcut_address + 1440 * x + 4 * y)
      @binary_file.seek(@binary_file.read(4).unpack('L>')[0])
      Helpers.fromfile(@binary_file, true, 2, nr_of_polygons)
    end

    def polygons_of_shortcut(x = 0, y = 0)
      # get the address of the first entry in this shortcut
      # offset: 180 * number of shortcuts per lat degree * 2bytes = entries per column of x shortcuts
      # shortcuts are stored: (0,0) (0,1) (0,2)... (1,0)...
      @binary_file.seek(@shortcuts_start + 720 * x + 2 * y)

      nr_of_polygons = @binary_file.read(2).unpack('S>')[0]

      @binary_file.seek(@first_shortcut_address + 1440 * x + 4 * y)
      @binary_file.seek(@binary_file.read(4).unpack('L>')[0])
      Helpers.fromfile(@binary_file, true, 2, nr_of_polygons)
    end

    def coords_of(line = 0)
      @binary_file.seek((@nr_val_start_address + 2 * line))
      nr_of_values = @binary_file.read(2).unpack('S>')[0]

      @binary_file.seek(@adr_start_address + 4 * line)
      @binary_file.seek(@binary_file.read(4).unpack('L>')[0])

      # return [Helpers.fromfile(@binary_file, false, 8, nr_of_values),
      #         Helpers.fromfile(@binary_file, false, 8, nr_of_values)]

      [Helpers.fromfile(@binary_file, false, 4, nr_of_values),
       Helpers.fromfile(@binary_file, false, 4, nr_of_values)]
    end

    # @profile
    # This function searches for the closest polygon in the surrounding shortcuts.
    # Make sure that the point does not lie within a polygon (for that case the algorithm is simply wrong!)
    # Note that the algorithm won't find the closest polygon when it's on the 'other end of earth'
    # (it can't search beyond the 180 deg lng border yet)
    # this checks all the polygons within [delta_degree] degree lng and lat
    # Keep in mind that x degrees lat are not the same distance apart than x degree lng!
    # :param lng: longitude of the point in degree
    # :param lat: latitude in degree
    # :param delta_degree: the 'search radius' in degree
    # :return: the timezone name of the closest found polygon or None
    def closest_timezone_at(lng, lat, delta_degree = 1)
      if lng > 180.0 or lng < -180.0 or lat > 90.0 or lat < -90.0
        fail "The coordinates are out ouf bounds: (#{lng}, #{lat})"
      end

      # the maximum possible distance is pi = 3.14...
      min_distance = 4
      # transform point X into cartesian coordinates
      current_closest_id = nil
      central_x_shortcut = (lng + 180).floor.to_i
      central_y_shortcut = ((90 - lat) * 2).floor.to_i

      polygon_nrs = []

      # there are 2 shortcuts per 1 degree lat, so to cover 1 degree two shortcuts (rows) have to be checked
      # the highest shortcut is 0
      top = [central_y_shortcut - 2 * delta_degree, 0].max
      # the lowest shortcut is 360 (= 2 shortcuts per 1 degree lat)
      bottom = [central_y_shortcut + 2 * delta_degree, 360].min

      # the most left shortcut is 0
      left = [central_x_shortcut - delta_degree, 0].max
      # the most right shortcut is 360 (= 1 shortcuts per 1 degree lng)
      right = [central_x_shortcut + delta_degree, 360].min

      # select all the polygons from the surrounding shortcuts
      (left..right).each do |x|
        (top..bottom).each do |y|
          polygons_of_shortcut(x, y).each do |p|
            polygon_nrs << p if polygon_nrs.index(p).nil?
          end
        end
      end

      polygons_in_list = polygon_nrs.length

      return nil if polygons_in_list == 0

      # initialize the list of ids
      ids = polygon_nrs.map { |x| id_of(x) }

      # if all the polygons in this shortcut belong to the same zone return it
      first_entry = ids[0]
      return TIMEZONE_NAMES[first_entry] if ids.count(first_entry) == polygons_in_list

      # stores which polygons have been checked yet
      already_checked = [false] * polygons_in_list

      pointer = 0
      polygons_checked = 0

      while polygons_checked < polygons_in_list
        # only check a polygon when its id is not the closest a the moment!
        if already_checked[pointer] or ids[pointer] == current_closest_id
          # go to the next polygon
          polygons_checked += 1

        else
          # this polygon has to be checked
          coords = coords_of(polygon_nrs[pointer])
          nr_points = coords[0].length
          empty_array = [[0.0] * nr_points] * 2
          distance = Helpers.distance_to_polygon(lng, lat, nr_points, coords, empty_array)

          already_checked[pointer] = true
          if distance < min_distance
            min_distance = distance
            current_closest_id = ids[pointer]
            # whole list has to be searched again!
            polygons_checked = 1
          end
        end
        pointer = (pointer + 1) % polygons_in_list
      end

      # the the whole list has been searched
      TIMEZONE_NAMES[current_closest_id]
    end

    # this function looks up in which polygons the point could be included
    # to speed things up there are shortcuts being used (stored in the binary file)
    # especially for large polygons it is expensive to check if a point is really included,
    # so certain simplifications are made and even when you get a hit the point might actually
    # not be inside the polygon (for example when there is only one timezone nearby)
    # if you want to make sure a point is really inside a timezone use 'certain_timezone_at'
    # :param lng: longitude of the point in degree (-180 to 180)
    # :param lat: latitude in degree (90 to -90)
    # :return: the timezone name of the matching polygon or None
    def timezone_at(lng = 0.0, lat = 0.0)
      if lng > 180.0 or lng < -180.0 or lat > 90.0 or lat < -90.0
        fail "The coordinates are out ouf bounds: (#{lng}, #{lat})"
      end

      possible_polygons = shortcuts_of(lng, lat)

      # x = longitude  y = latitude  both converted to 8byte int
      x = Helpers.coord2int(lng)
      y = Helpers.coord2int(lat)

      nr_possible_polygons = possible_polygons.length

      return nil if nr_possible_polygons == 0

      return TIMEZONE_NAMES[id_of(possible_polygons[0])] if nr_possible_polygons == 1

      # initialize the list of ids
      ids = possible_polygons.map { |p| id_of(p) }

      # if all the polygons belong to the same zone return it
      first_entry = ids[0]
      if ids.count(first_entry) == nr_possible_polygons
        return TIMEZONE_NAMES[first_entry]
      end

      # otherwise check if the point is included for all the possible polygons
      (0...nr_possible_polygons).each do |i|
        polygon_nr = possible_polygons[i]

        # get the boundaries of the polygon = (lng_max, lng_min, lat_max, lat_min)
        # self.binary_file.seek((@bound_start_address + 32 * polygon_nr), )
        @binary_file.seek((@bound_start_address + 16 * polygon_nr))
        boundaries = Helpers.fromfile(@binary_file, false, 4, 4)
        # only run the algorithm if it the point is withing the boundaries
        unless x > boundaries[0] or x < boundaries[1] or y > boundaries[2] or y < boundaries[3]

          if Helpers.inside_polygon(x, y, coords_of(polygon_nr))
            return TIMEZONE_NAMES[ids[i]]
          end
        end
      end
      nil
    end

    # this function looks up in which polygon the point certainly is included
    # this is much slower than 'timezone_at'!
    # :param lng: longitude of the point in degree
    # :param lat: latitude in degree
    # :return: the timezone name of the polygon the point is included in or None
    def certain_timezone_at(lng = 0.0, lat = 0.0)
      if lng > 180.0 or lng < -180.0 or lat > 90.0 or lat < -90.0
        fail "The coordinates are out ouf bounds: (#{lng}, #{lat})"
      end

      possible_polygons = shortcuts_of(lng, lat)

      # x = longitude  y = latitude  both converted to 8byte int
      x = Helpers.coord2int(lng)
      y = Helpers.coord2int(lat)

      possible_polygons.each do |polygon_nr|
        # get boundaries
        @binary_file.seek((@bound_start_address + 16 * polygon_nr))
        boundaries = Helpers.fromfile(@binary_file, false, 4, 4)
        unless x > boundaries[0] or x < boundaries[1] or y > boundaries[2] or y < boundaries[3]
          if Helpers.inside_polygon(x, y, coords_of(polygon_nr))
            fail id_of(polygon_nr) if id_of(polygon_nr) >= 424
            return TIMEZONE_NAMES[id_of(polygon_nr)]
          end
        end
      end
      nil
    end
  end
end
