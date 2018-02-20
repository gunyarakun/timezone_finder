module TimezoneFinder
  class Helpers
    # tests if a point pX(x,y) is Left|On|Right of an infinite line from p1 to p2
    #     Return: -1 for pX left of the line from! p1 to! p2
    #             0 for pX on the line [is not needed]
    #             1 for pX  right of the line
    #             this approach is only valid because we already know that y lies within ]y1;y2]
    def self.position_to_line(x, y, x1, x2, y1, y2)
      if x1 < x2
        # p2 is further right than p1
        if x > x2
          # pX is further right than p2,
          if y1 > y2
            return -1
          else
            return 1
          end
        end

        if x < x1
          # pX is further left than p1
          if y1 > y2
            # so it has to be right of the line p1-p2
            return 1
          else
            return -1
          end
        end

        x1gtx2 = false

      else
        # p1 is further right than p2
        if x > x1
          # pX is further right than p1,
          if y1 > y2
            # so it has to be left of the line p1-p2
            return -1
          else
            return 1
          end
        end

        if x < x2
          # pX is further left than p2,
          if y1 > y2
            # so it has to be right of the line p1-p2
            return 1
          else
            return -1
          end
        end

        # TODO: is not return also accepted
        if x1 == x2 && x == x1
          # could also be equal
          return 0
        end

        # x1 greater than x2
        x1gtx2 = true
      end

      # x is between [x1;x2]
      # compute the x-intersection of the point with the line p1-p2
      # delta_y cannot be 0 here because of the condition 'y lies within ]y1;y2]'
      # NOTE: bracket placement is important here (we are dealing with 64-bit ints!). first divide then multiply!
      delta_x = ((y - y1) * (x2 - x1).fdiv(y2 - y1)) + x1 - x

      if delta_x > 0
        if x1gtx2
          if y1 > y2
            return 1
          else
            return -1
          end

        else
          if y1 > y2
            return 1
          else
            return -1
          end
        end

      elsif delta_x == 0
        return 0

      else
        if x1gtx2
          if y1 > y2
            return -1
          else
            return 1
          end

        else
          if y1 > y2
            return -1
          else
            return 1
          end
        end
      end
    end

    def self.inside_polygon(x, y, coords)
      wn = 0
      i = 0
      y1 = coords[1][0]
      # TODO: why start with both y1=y2= y[0]?
      coords[1].each do |y2|
        if y1 < y
          if y2 >= y
            x1 = coords[0][i - 1]
            x2 = coords[0][i]
            # print(long2coord(x), long2coord(y), long2coord(x1), long2coord(x2), long2coord(y1), long2coord(y2),
            #       position_to_line(x, y, x1, x2, y1, y2))
            if position_to_line(x, y, x1, x2, y1, y2) == -1
              # point is left of line
              # return true when its on the line?! this is very unlikely to happen!
              # and would need to be checked every time!
              wn += 1
            end
          end
        else
          if y2 < y
            x1 = coords[0][i - 1]
            x2 = coords[0][i]
            if position_to_line(x, y, x1, x2, y1, y2) == 1
              # point is right of line
              wn -= 1
            end
          end
        end

        y1 = y2
        i += 1
      end

      y1 = coords[1][-1]
      y2 = coords[1][0]
      if y1 < y
        if y2 >= y
          x1 = coords[0][-1]
          x2 = coords[0][0]
          if position_to_line(x, y, x1, x2, y1, y2) == -1
            # point is left of line
            wn += 1
          end
        end
      else
        if y2 < y
          x1 = coords[0][-1]
          x2 = coords[0][0]
          if position_to_line(x, y, x1, x2, y1, y2) == 1
            # point is right of line
            wn -= 1
          end
        end
      end
      wn != 0
    end

    def self.all_the_same(pointer, length, id_list)
      # List mustn't be empty or Null
      # There is at least one

      element = id_list[pointer]
      pointer += 1

      while pointer < length
        return -1 if element != id_list[pointer]
        pointer += 1
      end

      element
    end

    def self.cartesian2rad(x, y, z)
      [Math.atan2(y, x), Math.asin(z)]
    end

    def self.radians(x)
      x * Math::PI / 180.0
    end

    def self.degrees(x)
      x * 180.0 / Math::PI
    end

    def self.cartesian2coords(x, y, z)
      [degrees(Math.atan2(y, x)), degrees(Math.asin(z))]
    end

    def self.x_rotate(rad, point)
      # Attention: this rotation uses radians!
      # x stays the same
      sin_rad = Math.sin(rad)
      cos_rad = Math.cos(rad)
      [point[0], point[1] * cos_rad + point[2] * sin_rad, point[2] * cos_rad - point[1] * sin_rad]
    end

    def self.y_rotate(rad, point)
      # y stays the same
      # this is actually a rotation with -rad (use symmetry of sin/cos)
      sin_rad = Math.sin(rad)
      cos_rad = Math.cos(rad)
      [point[0] * cos_rad + point[2] * sin_rad, point[1], point[2] * cos_rad - point[0] * sin_rad]
    end

    def self.coords2cartesian(lng_rad, lat_rad)
      [Math.cos(lng_rad) * Math.cos(lat_rad), Math.sin(lng_rad) * Math.cos(lat_rad), Math.sin(lat_rad)]
    end

    # uses the simplified haversine formula for this special case (lat_p1 = 0)
    # :param lng_rad: the longitude of the point in radians
    # :param lat_rad: the latitude of the point
    # :param lng_rad_p1: the latitude of the point1 on the equator (lat=0)
    # :return: distance between the point and p1 (lng_rad_p1,0) in km
    # this is only an approximation since the earth is not a real sphere
    def self.distance_to_point_on_equator(lng_rad, lat_rad, lng_rad_p1)
      # 2* for the distance in rad and * 12742 (mean diameter of earth) for the distance in km
      12_742 * Math.asin(Math.sqrt(Math.sin(lat_rad / 2.0)**2 + Math.cos(lat_rad) * Math.sin((lng_rad - lng_rad_p1) / 2.0)**2))
    end

    # :param lng_p1: the longitude of point 1 in radians
    # :param lat_p1: the latitude of point 1 in radians
    # :param lng_p2: the longitude of point 1 in radians
    # :param lat_p2: the latitude of point 1 in radians
    # :return: distance between p1 and p2 in km
    # this is only an approximation since the earth is not a real sphere
    def self.haversine(lng_p1, lat_p1, lng_p2, lat_p2)
      # 2* for the distance in rad and * 12742(mean diameter of earth) for the distance in km
      12_742 * Math.asin(Math.sqrt(Math.sin((lat_p1 - lat_p2) / 2.0)**2 + Math.cos(lat_p2) * Math.cos(lat_p1) * Math.sin((lng_p1 - lng_p2) / 2.0)**2))
    end

    # :param lng_rad: lng of px in radians
    # :param lat_rad: lat of px in radians
    # :param p0_lng: lng of p0 in radians
    # :param p0_lat: lat of p0 in radians
    # :param pm1_lng: lng of pm1 in radians
    # :param pm1_lat: lat of pm1 in radians
    # :param p1_lng: lng of p1 in radians
    # :param p1_lat: lat of p1 in radians
    # :return: shortest distance between pX and the polygon section (pm1---p0---p1) in radians
    def self.compute_min_distance(lng_rad, lat_rad, p0_lng, p0_lat, pm1_lng, pm1_lat, p1_lng, p1_lat)
      # rotate coordinate system (= all the points) so that p0 would have lat_rad=lng_rad=0 (=origin)
      # z rotation is simply substracting the lng_rad
      # convert the points to the cartesian coorinate system
      px_cartesian = coords2cartesian(lng_rad - p0_lng, lat_rad)
      p1_cartesian = coords2cartesian(p1_lng - p0_lng, p1_lat)
      pm1_cartesian = coords2cartesian(pm1_lng - p0_lng, pm1_lat)

      px_cartesian = y_rotate(p0_lat, px_cartesian)
      p1_cartesian = y_rotate(p0_lat, p1_cartesian)
      pm1_cartesian = y_rotate(p0_lat, pm1_cartesian)

      # for both p1 and pm1 separately do:

      # rotate coordinate system so that this point also has lat_p1_rad=0 and lng_p1_rad>0 (p0 does not change!)
      rotation_rad = Math.atan2(p1_cartesian[2], p1_cartesian[1])
      p1_cartesian = x_rotate(rotation_rad, p1_cartesian)
      lng_p1_rad = Math.atan2(p1_cartesian[1], p1_cartesian[0])
      px_retrans_rad = cartesian2rad(*x_rotate(rotation_rad, px_cartesian))

      # if lng_rad of px is between 0 (<-point1) and lng_rad of point 2:
      # the distance between point x and the 'equator' is the shortest
      # if the point is not between p0 and p1 the distance to the closest of the two points should be used
      # so clamp/clip the lng_rad of px to the interval of [0; lng_rad p1] and compute the distance with it
      temp_distance = distance_to_point_on_equator(px_retrans_rad[0], px_retrans_rad[1],
                                                   [[px_retrans_rad[0], lng_p1_rad].min, 0].max)

      # ATTENTION: vars are being reused. p1 is actually pm1 here!
      rotation_rad = Math.atan2(pm1_cartesian[2], pm1_cartesian[1])
      p1_cartesian = x_rotate(rotation_rad, pm1_cartesian)
      lng_p1_rad = Math.atan2(p1_cartesian[1], p1_cartesian[0])
      px_retrans_rad = cartesian2rad(*x_rotate(rotation_rad, px_cartesian))

      [
        temp_distance,
        distance_to_point_on_equator(px_retrans_rad[0], px_retrans_rad[1],
                                     [[px_retrans_rad[0], lng_p1_rad].min, 0].max)
      ].min
    end

    def self.int2coord(int32)
      int32.fdiv(10**7)
    end

    def self.coord2int(double)
      (double * 10**7).to_i
    end

    def self.distance_to_polygon_exact(lng_rad, lat_rad, nr_points, points, trans_points)
      # transform all points (long long) to coords
      (0...nr_points).each do |i|
        trans_points[0][i] = radians(int2coord(points[0][i]))
        trans_points[1][i] = radians(int2coord(points[1][i]))
      end

      # check points -2, -1, 0 first
      pm1_lng = trans_points[0][0]
      pm1_lat = trans_points[1][0]

      p1_lng = trans_points[0][-2]
      p1_lat = trans_points[1][-2]
      min_distance = compute_min_distance(lng_rad, lat_rad, trans_points[0][-1], trans_points[1][-1], pm1_lng, pm1_lat,
                                          p1_lng, p1_lat)

      index_p0 = 1
      index_p1 = 2
      (0...(((nr_points / 2.0) - 1).ceil.to_i)).each do |_i|
        p1_lng = trans_points[0][index_p1]
        p1_lat = trans_points[1][index_p1]

        min_distance = [min_distance,
                        compute_min_distance(lng_rad, lat_rad, trans_points[0][index_p0], trans_points[1][index_p0],
                                             pm1_lng, pm1_lat, p1_lng, p1_lat)].min

        index_p0 += 2
        index_p1 += 2
        pm1_lng = p1_lng
        pm1_lat = p1_lat
      end

      min_distance
    end

    def self.distance_to_polygon(lng_rad, lat_rad, nr_points, points)
      min_distance = 40_100_000

      (0...nr_points).each do |i|
        min_distance = [min_distance, haversine(lng_rad, lat_rad, radians(int2coord(points[0][i])),
                                                radians(int2coord(points[1][i])))].min
      end

      min_distance
    end

    # Ruby original
    # like numpy.fromfile
    def self.fromfile(file, unsigned, byte_width, count)
      if unsigned
        case byte_width
        when 2
          unpack_format = 'S<*'
        end
      else
        case byte_width
        when 4
          unpack_format = 'l<*'
        when 8
          unpack_format = 'q<*'
        end
      end

      unless unpack_format
        raise "#{unsigned ? 'unsigned' : 'signed'} #{byte_width}-byte width is not supported in fromfile"
      end

      file.read(count * byte_width).unpack(unpack_format)
    end
  end
end
