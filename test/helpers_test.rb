# rubocop:disable Metrics/LineLength,Metrics/MethodLength
require 'test_helper'
require_relative '../lib/timezone_finder/helpers'

def random_point
  # tzwhere does not work for points with more latitude!
  [rand(-180.0...180.0), rand(-84.0...84)]
end

def list_of_random_points(length)
  Array.new(length).map { random_point }
end

class HelpersTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  # tests if a point pX(x,y) is Left|On|Right of an infinite line from p1 to p2
  #     Return: -1 for pX left of the line from! p1 to! p2
  #             0 for pX on the line [is not needed]
  #             1 for pX  right of the line
  #             this approach is only valid because we already know that y lies within ]y1;y2]
  def test_position_to_line
    p_test_cases = [
      # [x,y],
      [-1, 1],
      [0, 1],
      [1, 1],
      [-1, 0],
      [0, 0],
      [1, 0],
      [-1, -1],
      [0, -1],
      [1, -1]
    ]

    p1p2_test_cases = [
      [-1, 1, -1, 1],
      [1, -1, 1, -1],
      [-1, 1, 1, -1],
      [1, -1, -1, 1]
    ]

    expected_results = [
      [-1, -1, 0, -1, 0, 1, 0, 1, 1],
      [1, 1, 0, 1, 0, -1, 0, -1, -1],
      [0, -1, -1, 1, 0, -1, 1, 1, 0],
      [0, 1, 1, -1, 0, 1, -1, -1, 0]
    ]

    n = 0
    p1p2_test_cases.each do |x1, x2, y1, y2|
      i = 0
      p_test_cases.each do |x, y|
        assert_equal(expected_results[n][i], TimezoneFinder::Helpers.position_to_line(x, y, x1, x2, y1, y2))
        i += 1
      end
      n += 1
    end
  end

  def test_inside_polygon
    p_test_cases = [
      # [x,y],
      [-1, 1],
      [0, 1],
      [1, 1],
      [-1, 0],
      [0, 0],
      [1, 0],
      [-1, -1],
      [0, -1],
      [1, -1],

      # on the line test cases
      # [-0.5, 0.5],
      # [0, 0.5],
      # [-0.5, 0],
      # [0.5, 0],
    ]

    polygon_test_cases = [
      [[0.5, -0.5, -0.5, 0.5], [0.5, 0.5, -0.5, -0.5]]
    ]

    expected_results = [
      [false, false, false, false, true, false, false, false, false]
    ]

    n = 0
    polygon_test_cases.each do |coords|
      i = 0
      p_test_cases.each do |x, y|
        assert_equal(expected_results[n][i], TimezoneFinder::Helpers.inside_polygon(x, y, coords))
        i += 1
      end
      n += 1
    end
  end

  def test_distance_computation # rubocop:disable Metrics/AbcSize
    def km2rad(km)
      km.fdiv(6371)
    end

    def km2deg(km)
      TimezoneFinder::Helpers.degrees(km2rad(km))
    end

    p_test_cases = [
      # [x,y],
      [0, 1],
      [1, 0],
      [0, -1],
      [-1, 0],

      # on the line test cases
      # [-0.5, 0.5],
      # [0, 0.5],
      # [-0.5, 0],
      # [0.5, 0],
    ]

    p1_lng_rad = TimezoneFinder::Helpers.radians(0.0)
    p1_lat_rad = TimezoneFinder::Helpers.radians(0.0)

    p_test_cases.each do |x, y|
      result = TimezoneFinder::Helpers.distance_to_point_on_equator(TimezoneFinder::Helpers.radians(x), TimezoneFinder::Helpers.radians(y), p1_lng_rad)
      assert_equal(1, km2deg(result))
      hav_result = TimezoneFinder::Helpers.haversine(TimezoneFinder::Helpers.radians(x), TimezoneFinder::Helpers.radians(y), p1_lng_rad, 0)
      assert_equal(1.0, km2deg(hav_result))
    end

    (0...1000).each do |_i|
      rnd_point = random_point
      lng_rnd_point2 = random_point[0]
      hav_result = TimezoneFinder::Helpers.degrees(TimezoneFinder::Helpers.haversine(TimezoneFinder::Helpers.radians(rnd_point[0]), TimezoneFinder::Helpers.radians(rnd_point[1]), lng_rnd_point2, 0))
      result = TimezoneFinder::Helpers.degrees(TimezoneFinder::Helpers.distance_to_point_on_equator(TimezoneFinder::Helpers.radians(rnd_point[0]), TimezoneFinder::Helpers.radians(rnd_point[1]), lng_rnd_point2))
      assert_in_delta(result, hav_result, 0.000001)
    end

    x_coords = [0.5, -0.5, -0.5, 0.5]
    y_coords = [0.5, 0.5, -0.5, -0.5]
    points = [
      x_coords.map { |x| TimezoneFinder::Helpers.coord2int(x) },
      y_coords.map { |y| TimezoneFinder::Helpers.coord2int(y) }
    ]
    trans_points = [
      x_coords.map { nil },
      y_coords.map { nil }
    ]

    x_rad = TimezoneFinder::Helpers.radians(1.0)
    y_rad = TimezoneFinder::Helpers.radians(0.0)

    puts(km2deg(TimezoneFinder::Helpers.haversine(x_rad, y_rad, p1_lng_rad, p1_lat_rad)))
    assert_equal(1, km2deg(TimezoneFinder::Helpers.haversine(x_rad, y_rad, p1_lng_rad, p1_lat_rad)))

    distance_exact = TimezoneFinder::Helpers.distance_to_polygon_exact(x_rad, y_rad, x_coords.length, points, trans_points)
    puts(km2deg(distance_exact))
    assert_equal(0.5, km2deg(distance_exact))
    puts('=====')
    distance = TimezoneFinder::Helpers.distance_to_polygon(x_rad, y_rad, x_coords.length, points)
    puts(km2deg(distance))
    assert_in_delta(Math.sqrt(2) / 2, km2deg(distance), 0.00001)
  end
end
