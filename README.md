# timezone\_finder

[![Build Status](https://travis-ci.org/gunyarakun/timezone_finder.svg?branch=master)](https://travis-ci.org/gunyarakun/timezone_finder)
[![Gem Version](https://badge.fury.io/rb/timezone_finder.svg)](https://badge.fury.io/rb/timezone_finder)
![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)

**NOTE:** version 1.5.7 is incompatible with version 1.5.6 because the argument were changed into named arguments following the original Python version's change.

This is a fast and lightweight pure ruby project with no runtime dependency for looking up the corresponding
timezone for a given lat/lng on earth entirely offline.

This project is derived from
[timezonefinder](https://pypi.python.org/pypi/timezonefinder)
([github](https://github.com/MrMinimal64/timezonefinder)).

The underlying timezone data is based on work done by [Eric Muller](http://efele.net/maps/tz/world/).

Timezones at sea and Antarctica are not yet supported (because somewhat
special rules apply there).

## Installation

in your terminal simply:

```sh
gem install timezone_finder
```

(you might need to run this command as administrator)

## Usage

### Basics:

```ruby
require 'timezone_finder'
tf = TimezoneFinder.create
```

#### timezone\_at():

This is the default function to check which timezone a point lies within.
If no timezone has been found, `nil` is being returned.

**PLEASE NOTE:** This approach is optimized for speed and the common case to only query points within a timezone.
The last possible timezone in proximity is always returned (without checking if the point is really included).
So results might be misleading for points outside of any timezone.

```ruby
longitude = 13.358
latitude = 52.5061
puts tf.timezone_at(lng: longitude, lat: latitude)
# = Europe/Berlin
```

#### certain\_timezone\_at()

This function is for making sure a point is really inside a timezone. It is slower, because all polygons (with shortcuts in that area)
are checked until one polygon is matched.

```ruby
puts tf.certain_timezone_at(lng: longitude, lat: latitude)
# = Europe/Berlin
```

#### Proximity algorithm

Only use this when the point is not inside a polygon, because the approach otherwise makes no sense.
This returns the closest timezone of all polygons within +-1 degree lng and +-1 degree lat (or nil).

```ruby
longitude = 12.773955
latitude = 55.578595
puts tf.closest_timezone_at(lng: longitude, lat: latitude)
# = Europe/Copenhagens
```

#### Other options:

To increase search radius even more, use the `delta_degree`-option:

```ruby
puts tf.closest_timezone_at(lng: longitude, lat: latitude, delta_degree: 3)
# = Europe/Copenhagens
```

This checks all the polygons within +-3 degree lng and +-3 degree lat.
I recommend only slowly increasing the search radius, since computation time increases quite quickly
(with the amount of polygons which need to be evaluated) and there might be many polygons within a couple degrees.

Also keep in mind that x degrees lat are not the same distance apart than x degree lng (earth is a sphere)!
So to really make sure you got the closest timezone increase the search radius until you get a result,
then increase the radius once more and take this result. (should only make a difference in really rare cases)

With `exact_computation=true` the distance to every polygon edge is computed (way more complicated), instead of just evaluating the distances to all the vertices.
 This only makes a real difference when polygons are very close.

With `return_distances=true` the output looks like this:

[ 'tz_name_of_the_closest_polygon',[ distances to every polygon in km], [tz_names of every polygon]]

Note that some polygons might not be tested (for example when a zone is found to be the closest already).
To prevent this use `force_evaluation=true`.

```ruby
longitude = 42.1052479
latitude = -16.622686
puts tf.closest_timezone_at(lng: longitude, lat: latitude, delta_degree: 2,
                            exact_computation: true, return_distances: true, force_evaluation: true)
# = ["uninhabited",
#     [238.1846260648566, 267.91867468894895, 207.43831938964382, 209.6790144988556, 228.4213564154256, 80.66907784731693, 217.1092486625455, 293.54672523493076, 304.527493783916],
#     ["Africa/Maputo", "Africa/Maputo", "Africa/Maputo", "Africa/Maputo", "Africa/Maputo", "uninhabited", "Indian/Antananarivo", "Indian/Antananarivo", "Indian/Antananarivo"]
#   ]
```

## Developer

### Using the conversion tool:

Make sure you installed the GDAL framework (that's for converting .shp shapefiles into .json)
Change to the directory of the timezone\_finder package (location of ``file_converter.rb``) in your terminal and then:

```sh
wget http://efele.net/maps/tz/world/tz_world.zip
# on mac: curl "http://efele.net/maps/tz/world/tz_world.zip" -o "tz_world.zip"
unzip tz_world
ogr2ogr -f GeoJSON -t_srs crs:84 tz_world.json ./world/tz_world.shp
rm ./world/ -r
rm tz_world.zip
```

There has to be a tz\_world.json (of approx. 100MB) in the folder together with the ``file_converter.rb`` now.
Then you should run the converter by:

```sh
ruby file_converter.rb
```

this converts the .json into the needed .bin (overwriting the old version!) and updating the used timezone names.

## Known Issues

The original author MrMinimal64 ran tests for approx. 5M points and these are no mistakes he found.

## Contact

If you notice that the tz data is outdated, encounter any bugs, have
suggestions, criticism, etc. feel free to **open an Issue**, **add a Pull Requests** on Git.

## Credits

Thanks to [MrMinimal64](https://github.com/MrMinimal64) for developing the original version and giving me some advices.

## License

``timezone_finder`` is distributed under the terms of the MIT license
(see LICENSE.txt).
