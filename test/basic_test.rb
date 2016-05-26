require 'test/unit'
require_relative '../lib/timezonefinder'

class BasicTest < Test::Unit::TestCase
  INSIDE_POINTS = {
    # invalid cause this is no zone so also no ID (-52.9883809, 29.6183884): '',
    [-44.7402611, 70.2989263] => 'America/Godthab',
    [-4.8663325, 40.0663485] => 'Europe/Madrid',
    [-60.968888, -3.442172] => 'America/Manaus',
    [14.1315716, 2.99999] => 'Africa/Douala',
    [14.1315716, 0.2350623] => 'Africa/Brazzaville',
    [-71.9996885, -52.7868679] => 'America/Santiago',
    [-152.4617352, 62.3415036] => 'America/Anchorage',
    [37.0720767, 55.74929] => 'Europe/Moscow',
    [103.7069307, 1.3150701] => 'Asia/Singapore',
    [12.9125913, 50.8291834] => 'Europe/Berlin',
    [-106.1706459, 23.7891123] => 'America/Mazatlan',
    # [-110.29080, 35.53587] => 'America/Phoenix',
    [33, -84] => 'uninhabited',
  }.freeze

  def setup
    @tf = TimezoneFinder.create
  end

  def test_timezone_at
    INSIDE_POINTS.each do |k, v|
      assert_equal(v, @tf.timezone_at(*k))
    end
  end

  def test_certain_timezone_at
    INSIDE_POINTS.each do |k, v|
      assert_equal(v, @tf.certain_timezone_at(*k))
    end
  end

  OUTSIDE_POINTS = {
    [12.773955, 55.578595] => 'Europe/Copenhagen',
    [12.773955, 55.578595, 1] => 'Europe/Copenhagen',
  }.freeze

  def test_closest_timezone_at
    OUTSIDE_POINTS.each do |k, v|
      assert_equal(v, @tf.closest_timezone_at(*k))
    end
  end
end
