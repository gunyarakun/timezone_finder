require 'test_helper'

class TimezoneFinderTest < Minitest::Test
  TEST_LOCATIONS = [
    [35.295953, -89.662186, 'Arlington, TN', 'America/Chicago'],
    [33.58, -85.85, 'Memphis, TN', 'America/Chicago'],
    [61.17, -150.02, 'Anchorage, AK', 'America/Anchorage'],
    [44.12, -123.22, 'Eugene, OR', 'America/Los_Angeles'],
    [42.652647, -73.756371, 'Albany, NY', 'America/New_York'],
    [55.743749, 37.6207923, 'Moscow', 'Europe/Moscow'],
    [34.104255, -118.4055591, 'Los Angeles', 'America/Los_Angeles'],
    [55.743749, 37.6207923, 'Moscow', 'Europe/Moscow'],
    [39.194991, -106.8294024, 'Aspen, Colorado', 'America/Denver'],
    [50.438114, 30.5179595, 'Kiev', 'Europe/Kiev'],
    [12.936873, 77.6909136, 'Jogupalya', 'Asia/Kolkata'],
    [38.889144, -77.0398235, 'Washington DC', 'America/New_York'],
    [59.932490, 30.3164291, 'St Petersburg', 'Europe/Moscow'],
    [50.300624, 127.559166, 'Blagoveshchensk', 'Asia/Yakutsk'],
    [42.439370, -71.0700416, 'Boston', 'America/New_York'],
    [41.84937, -87.6611995, 'Chicago', 'America/Chicago'],
    [28.626873, -81.7584514, 'Orlando', 'America/New_York'],
    [47.610615, -122.3324847, 'Seattle', 'America/Los_Angeles'],
    [51.499990, -0.1353549, 'London', 'Europe/London'],
    [51.256241, -0.8186531, 'Church Crookham', 'Europe/London'],
    [51.292215, -0.8002638, 'Fleet', 'Europe/London'],
    [48.868743, 2.3237586, 'Paris', 'Europe/Paris'],
    [22.158114, 113.5504603, 'Macau', 'Asia/Macau'],
    [56.833123, 60.6097054, 'Russia', 'Asia/Yekaterinburg'],
    [60.887496, 26.6375756, 'Salo', 'Europe/Helsinki'],
    [52.799992, -1.8524408, 'Staffordshire', 'Europe/London'],
    [5.016666, 115.0666667, 'Muara', 'Asia/Brunei'],
    [-41.466666, -72.95, 'Puerto Montt seaport', 'America/Santiago'],
    [34.566666, 33.0333333, 'Akrotiri seaport', 'Asia/Nicosia'],
    [37.466666, 126.6166667, 'Inchon seaport', 'Asia/Seoul'],
    [42.8, 132.8833333, 'Nakhodka seaport', 'Asia/Vladivostok'],
    [50.26, -5.051, 'Truro', 'Europe/London'],

    # test cases for hole handling:
    [41.0702284, 45.0036352, 'Aserbaid. Enklave', 'Asia/Baku'],
    [39.8417402, 70.6020068, 'Tajikistani Enklave', 'Asia/Dushanbe'],
    [47.7024174, 8.6848462, 'Busingen Ger', 'Europe/Busingen'],
    [46.2085101, 6.1246227, 'Genf', 'Europe/Zurich'],
    [-29.391356857138753, 28.50989829115889, 'Lesotho', 'Africa/Maseru'],
    [39.93143377877638, 71.08546583764965, 'usbekish enclave', 'Asia/Tashkent'],
    [40.0736177, 71.0411812, 'usbekish enclave', 'Asia/Tashkent'],
    [35.7396116, -110.15029571, 'Arizona Desert 1', 'America/Denver'],
    [36.4091869, -110.7520236, 'Arizona Desert 2', 'America/Phoenix'],
    [36.10230848, -111.1882385, 'Arizona Desert 3', 'America/Phoenix'],

    # Not sure about the right result:
    # [68.3597987,-133.745786, 'America', 'America/Inuvik'],

    [50.26, -9.051, 'Far off Cornwall', nil]
  ].freeze

  TEST_LOCATIONS_PROXIMITY = [
    [35.295953, -89.662186, 'Arlington, TN', 'America/Chicago'],
    [33.58, -85.85, 'Memphis, TN', 'America/Chicago'],
    [61.17, -150.02, 'Anchorage, AK', 'America/Anchorage'],
    [40.7271, -73.98, 'Shore Lake Michigan', 'America/New_York'],
    [51.032593, 1.4082031, 'English Channel1', 'Europe/London'],
    [50.9623651, 1.5732592, 'English Channel2', 'Europe/Paris'],
    [55.5609615, 12.850585, 'Oresund Bridge1', 'Europe/Stockholm'],
    [55.6056074, 12.7128568, 'Oresund Bridge2', 'Europe/Copenhagen']
  ].freeze

  def setup
    @tf = TimezoneFinder.create
  end

  def test_timezone_at
    TEST_LOCATIONS.each do |lat, lon, _loc, expected|
      assert_equal_or_nil(expected, @tf.timezone_at(lng: lon, lat: lat))
    end
  end

  def test_certain_timezone_at
    TEST_LOCATIONS.each do |lat, lon, _loc, expected|
      assert_equal_or_nil(expected, @tf.certain_timezone_at(lng: lon, lat: lat))
    end
  end

  def test_closest_timezone_at
    TEST_LOCATIONS_PROXIMITY.each do |lat, lon, _loc, expected|
      assert_equal_or_nil(expected, @tf.closest_timezone_at(lng: lon, lat: lat))
    end

    longitude = 42.1052479
    latitude = -16.622686
    assert_equal(
      # expected
      [
        'uninhabited',
        [
          238.1846260648566,
          267.91867468894895,
          207.43831938964382,
          209.6790144988556,
          228.4213564154256,
          80.66907784731693,
          217.1092486625455,
          293.54672523493076,
          304.527493783916
        ],
        [
          'Africa/Maputo',
          'Africa/Maputo',
          'Africa/Maputo',
          'Africa/Maputo',
          'Africa/Maputo',
          'uninhabited',
          'Indian/Antananarivo',
          'Indian/Antananarivo',
          'Indian/Antananarivo'
        ]
      ],
      # actual
      @tf.closest_timezone_at(
        lng: longitude, lat: latitude, delta_degree: 2,
        exact_computation: true, return_distances: true, force_evaluation: true
      )
    )
  end

  def test_that_it_has_a_version_number
    refute_nil ::TimezoneFinder::VERSION
  end

  def assert_equal_or_nil(expected, actual)
    # To avoid MiniTest 6 errors
    if expected.nil?
      assert_nil(actual)
    else
      assert_equal(expected, actual)
    end
  end
end
