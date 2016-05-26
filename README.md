# timezone\_finder

[![Build Status](https://travis-ci.org/gunyarakun/timezone_finder.svg?branch=master)](https://travis-ci.org/gunyarakun/timezone_finder)
[![Gem Version](https://badge.fury.io/rb/timezone_finder.svg)](https://badge.fury.io/rb/timezone_finder)

This is a fast and lightweight ruby project to lookup the corresponding
timezone for a given lat/lng on earth entirely offline.

This project is derived from
[timezonefinder](https://pypi.python.org/pypi/timezonefinder)
([github](https://github.com/MrMinimal64/timezonefinder>)).

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

#### fast algorithm:

```ruby
# point = (longitude, latitude)
point = (13.358, 52.5061)
puts( tf.timezone_at(*point)
# = Europe/Berlin
```

#### To make sure a point is really inside a timezone (slower):

```ruby
puts( tf.certain_timezone_at(*point) )
# = Europe/Berlin
```

#### To find the closest timezone (slow):

```ruby
# only use this when the point is not inside a polygon!
# this checks all the polygons within +-1 degree lng and +-1 degree lat
point = (12.773955, 55.578595)
print( tf.closest_timezone_at(*point) )
# = Europe/Copenhagens
```

#### To increase search radius even more (very slow):

```ruby
# this checks all the polygons within +-3 degree lng and +-3 degree lat
# I recommend only slowly increasing the search radius
# keep in mind that x degrees lat are not the same distance apart than x degree lng!
print( tf.closest_timezone_at(lng=point[0],lat=point[1],delta_degree=3) )
# = Europe/Copenhagens
```

(to make sure you really got the closest timezone increase the search
radius until you get a result. then increase the radius once more and
take this result.)

## Developer

### Using the conversion tool:

Make sure you installed the GDAL framework (thats for converting .shp shapefiles into .json)
Change to the directory of the timezone_finder package (location of ``file_converter.rb``) in your terminal and then:

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

The original author MrMinimal64 ran tests for approx. 5M points and this are the mistakes he found:

All points in **Lesotho** are counted to the 'Africa/Johannesburg' timezone instead of 'Africa/Maseru'.
I am pretty sure this is because it is completely surrounded by South Africa and in the data the area of Lesotho is not excluded from this timezone.

Same for the small **usbekish enclaves** in **Kirgisitan** and some points in the **Arizona Dessert** (some weird rules apply here).

Those are mistakes in the data not my algorithms and in order to fix this he would need check for and then separately handle these special cases.
This would not only slow down the algorithms, but also make them ugly.

## Contact

If you notice that the tz data is outdated, encounter any bugs, have
suggestions, criticism, etc. feel free to **open an Issue**, **add a Pull Requests** on Git.

## License

``timezone_finder`` is distributed under the terms of the MIT license
(see LICENSE.txt).
