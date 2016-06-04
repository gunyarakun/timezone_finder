#!/usr/bin/env ruby
# rubocop:disable Metrics/ClassLength,Metrics/MethodLength,Metrics/LineLength
# rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/ParameterLists
# rubocop:disable Style/PredicateName,Style/Next
# rubocop:disable Lint/Void
require 'set'
require_relative 'helpers'

module TimezoneFinder
  class FileConverter
    # Don't change this setup or timezonefinder wont work!
    # different setups of shortcuts are not supported, because then addresses in the .bin
    # would need to be calculated depending on how many shortcuts are being used.
    # number of shortcuts per longitude
    NR_SHORTCUTS_PER_LNG = 1
    # shortcuts per latitude
    NR_SHORTCUTS_PER_LAT = 2

    def initialize
      @nr_of_lines = -1

      @all_tz_names = []
      @ids = []
      @boundaries = []
      @all_coords = []
      @all_lengths = []
      @amount_of_holes = 0
      @first_hole_id_in_line = []
      @related_line = []

      @all_holes = []
      @all_hole_lengths = []
    end

    # HELPERS:

    # TODO
    # :return:
    def update_zone_names(path = 'timezone_names.rb')
      puts('updating the zone names now')
      unique_zones = []
      @all_tz_names.each do |zone_name|
        unique_zones << zone_name if unique_zones.index(zone_name).nil?
      end

      unique_zones.sort!

      @all_tz_names.each do |zone_name|
        # the ids of the polygons have to be set correctly
        @ids << unique_zones.index(zone_name)
      end

      # write all unique zones into the file at path with the syntax of a ruby array

      file = open(path, 'w')
      file.write("module TimezoneFinder\n")
      file.write("  TIMEZONE_NAMES = [\n")
      unique_zones.each do |zone_name|
        file.write("    '#{zone_name}',\n")
      end

      file.write("  ].freeze\n")
      file.write("end\n")
      puts("Done\n\n")
    end

    def inside_polygon(x, y, x_coords, y_coords)
      def is_left_of(x, y, x1, x2, y1, y2)
        (x2 - x1) * (y - y1) - (x - x1) * (y2 - y1)
      end

      n = y_coords.length - 1

      wn = 0
      (0...n).each do |i|
        iplus = i + 1
        if y_coords[i] <= y
          # puts('Y1<=y')
          if y_coords[iplus] > y
            # puts('Y2>y')
            if is_left_of(x, y, x_coords[i], x_coords[iplus], y_coords[i], y_coords[iplus]) > 0
              wn += 1
              # puts('wn is:')
              # puts(wn)
            end
          end
        else
          # puts('Y1>y')
          if y_coords[iplus] <= y
            # puts('Y2<=y')
            if is_left_of(x, y, x_coords[i], x_coords[iplus], y_coords[i], y_coords[iplus]) < 0
              wn -= 1
              # puts('wn is:')
              # puts(wn)
            end
          end
        end
      end
      wn != 0
    end

    def parse_polygons_from_json(path = 'tz_world.json')
      f = open(path, 'r')
      puts 'Parsing data from .json'
      # file_line is the current line in the .json file being parsed. This is not the id of the Polygon!
      file_line = 0
      f.each_line do |row|
        # puts(row)
        tz_name_match = /"TZID":\s\"(?<name>.*)"\s\}/.match(row)
        # tz_name = /(TZID)/.match(row)
        # puts tz_name
        if tz_name_match
          tz_name = tz_name_match['name'].gsub('\\', '')
          @all_tz_names << tz_name
          @nr_of_lines += 1
          # puts tz_name

          actual_depth = 0
          counted_coordinate_pairs = 0
          encountered_nr_of_coordinates = []
          row.each_char do |char|
            if char == '['
              actual_depth += 1
            elsif char == ']'
              actual_depth -= 1
              if actual_depth == 2
                counted_coordinate_pairs += 1
              elsif actual_depth == 1
                encountered_nr_of_coordinates << counted_coordinate_pairs
                counted_coordinate_pairs = 0
              end
            end
          end

          if actual_depth != 0
            fail ArgumentError, "uneven number of brackets detected. Something is wrong in line #{file_line}"
          end

          coordinates = row.scan(/[-]?\d+\.?\d+/)

          sum = encountered_nr_of_coordinates.inject(0) { |a, e| a + e }
          if coordinates.length != sum * 2
            fail ArgumentError, "There number of coordinates is counten wrong: #{coordinates.length} #{sum * 2}"
          end
          # TODO: detect and store all the holes in the bin
          # puts coordinates

          # nr_floats = coordinates.length
          x_coords = []
          y_coords = []
          xmax = -180.0
          xmin = 180.0
          ymax = -90.0
          ymin = 90.0

          pointer = 0
          # the coordiate pairs within the first brackets [ [x,y], ..., [xn, yn] ] are the polygon coordinates
          # The last coordinate pair should be left out (is equal to the first one)
          (0...(2 * (encountered_nr_of_coordinates[0] - 1))).each do |n|
            if n.even?
              x = coordinates[pointer].to_f
              x_coords << x
              xmax = x if x > xmax
              xmin = x if x < xmin
            else
              y = coordinates[pointer].to_f
              y_coords << y
              ymax = y if y > ymax
              ymin = y if y < ymin
            end

            pointer += 1
          end

          @all_coords << [x_coords, y_coords]
          @all_lengths << x_coords.length
          # puts(x_coords)
          # puts(y_coords)

          @boundaries << [xmax, xmin, ymax, ymin]

          amount_holes_this_line = encountered_nr_of_coordinates.length - 1
          if amount_holes_this_line > 0
            # store how many holes there are in this line
            # store what the number of the first hole for this line is (for calculating the address to jump)
            @first_hole_id_in_line << @amount_of_holes
            # keep track of how many holes there are
            @amount_of_holes += amount_holes_this_line
            puts(tz_name)

            (0...amount_holes_this_line).each do |_i|
              @related_line << @nr_of_lines
              puts(@nr_of_lines)

              # puts(amount_holes_this_line)
            end
          end

          # for every encountered hole
          (1...(amount_holes_this_line + 1)).each do |i|
            x_coords = []
            y_coords = []

            # since the last coordinate was being left out,
            # we have to move the pointer 2 floats further to be in the hole data again
            pointer += 2

            # The last coordinate pair should be left out (is equal to the first one)
            (0...(2 * (encountered_nr_of_coordinates[i] - 1))).each do |n|
              if n.even?
                x_coords << coordinates[pointer].to_f
              else
                y_coords << coordinates[pointer].to_f
              end

              pointer += 1
            end

            @all_holes << [x_coords, y_coords]
            @all_hole_lengths << x_coords.length
          end
        end

        file_line += 1
      end

      # so far the nr_of_lines was used to point to the current polygon but there is actually 1 more polygons in total
      @nr_of_lines += 1

      puts("amount_of_holes: #{@amount_of_holes}")
      puts("amount of timezones: #{@nr_of_lines}")

      puts("Done\n\n")
    end

    def ints_of(line = 0)
      x_coords, y_coords = @all_coords[line]
      [x_coords.map { |x| Helpers.coord2int(x) }, y_coords.map { |y| Helpers.coord2int(y) }]
    end

    def compile_into_binary(path = 'tz_binary.bin')
      nr_of_floats = 0
      zone_ids = []
      shortcuts = {}

      def x_shortcut(lng)
        # puts lng if lng < -180 or lng >= 180
        # raise 'longitude out of bounds'
        ((lng + 180) * NR_SHORTCUTS_PER_LNG).floor
      end

      def y_shortcut(lat)
        # puts lat if lat < -90 or lat >= 90
        # raise 'this latitude is out of bounds'
        ((90 - lat) * NR_SHORTCUTS_PER_LAT).floor
      end

      def big_zone(xmax, xmin, ymax, ymin)
        # returns true if a zone with those boundaries could have more than 4 shortcuts
        (xmax - xmin) > (2.0 / NR_SHORTCUTS_PER_LNG) && (ymax - ymin) > (2.0 / NR_SHORTCUTS_PER_LAT)
      end

      def included_shortcut_row_nrs(max_lat, min_lat)
        (y_shortcut(max_lat)..y_shortcut(min_lat)).to_a
      end

      def included_shortcut_column_nrs(max_lng, min_lng)
        (x_shortcut(min_lng)..x_shortcut(max_lng)).to_a
      end

      def longitudes_to_check(max_lng, min_lng)
        output_list = []
        step = 1.0 / NR_SHORTCUTS_PER_LNG
        current = (min_lng * NR_SHORTCUTS_PER_LNG).ceil.fdiv(NR_SHORTCUTS_PER_LNG)
        last = (max_lng * NR_SHORTCUTS_PER_LNG).floor.fdiv(NR_SHORTCUTS_PER_LNG)

        while current < last
          output_list << current
          current += step
        end

        output_list << last
        output_list
      end

      def latitudes_to_check(max_lat, min_lat)
        output_list = []
        step = 1.0 / NR_SHORTCUTS_PER_LAT
        current = (min_lat * NR_SHORTCUTS_PER_LAT).ceil.fdiv(NR_SHORTCUTS_PER_LAT)
        last = (max_lat * NR_SHORTCUTS_PER_LAT).floor.fdiv(NR_SHORTCUTS_PER_LAT)
        while current < last
          output_list << current
          current += step
        end

        output_list << last
        output_list
      end

      # returns the x intersection from a horizontal line in y with the line from x1,y1 to x1,y2
      def compute_x_intersection(y, x1, x2, y1, y2)
        delta_y = y2 - y1
        return x1 if delta_y == 0
        ((y - y1) * (x2 - x1)).fdiv(delta_y) + x1
      end

      # returns the y intersection from a vertical line in x with the line from x1,y1 to x1,y2
      def compute_y_intersection(x, x1, x2, y1, y2)
        delta_x = x2 - x1
        return x1 if delta_x == 0
        ((x - x1) * (y2 - y1)).fdiv(delta_x) + y1
      end

      def x_intersections(y, x_coords, y_coords)
        # puts(x_coords.to_s)
        # puts(y)
        # puts(y_coords.to_s)

        intersects = []
        (0...(y_coords.length - 1)).each do |i|
          iplus1 = i + 1
          if y_coords[i] <= y
            # puts('Y1<=y')
            if y_coords[iplus1] > y
              # this was a crossing. compute the intersect
              # puts('Y2>y')
              intersects << compute_x_intersection(y, x_coords[i], x_coords[iplus1], y_coords[i], y_coords[iplus1])
            end
          else
            # puts('Y1>y')
            if y_coords[iplus1] <= y
              # this was a crossing. compute the intersect
              # puts('Y2<=y')
              intersects << compute_x_intersection(y, x_coords[i], x_coords[iplus1], y_coords[i], y_coords[iplus1])
            end
          end
        end
        intersects
      end

      def y_intersections(x, x_coords, y_coords)
        intersects = []
        (0...(y_coords.length - 1)).each do |i|
          iplus1 = i + 1
          if x_coords[i] <= x
            if x_coords[iplus1] > x
              # this was a crossing. compute the intersect
              intersects << compute_y_intersection(x, x_coords[i], x_coords[iplus1], y_coords[i], y_coords[iplus1])
            end
          else
            if x_coords[iplus1] <= x
              # this was a crossing. compute the intersect
              intersects << compute_y_intersection(x, x_coords[i], x_coords[iplus1], y_coords[i], y_coords[iplus1])
            end
          end
        end
        intersects
      end

      def compute_exact_shortcuts(xmax, xmin, ymax, ymin, line)
        shortcuts_for_line = Set.new

        # x_longs = binary_reader.x_coords_of(line)
        longs = ints_of(line)
        x_longs = longs[0]
        y_longs = longs[1]

        # y_longs = binary_reader.y_coords_of(line)
        y_longs << y_longs[0]
        x_longs << x_longs[0]

        step = 1.0 / NR_SHORTCUTS_PER_LAT
        # puts('checking the latitudes')
        latitudes_to_check(ymax, ymin).each do |lat|
          # puts(lat)
          # puts(coordinate_to_longlong(lat))
          # puts(y_longs)
          # puts(x_intersections(coordinate_to_longlong(lat), x_longs, y_longs))
          # raise
          intersects = x_intersections(Helpers.coord2int(lat), x_longs, y_longs).map do |x|
            Helpers.int2coord(x)
          end.sort
          # puts(intersects.to_s)

          nr_of_intersects = intersects.length
          if nr_of_intersects.odd?
            fail 'an uneven number of intersections has been accounted'
          end

          (0...nr_of_intersects).step(2).each do |i|
            possible_longitudes = []
            # collect all the zones between two intersections [in,out,in,out,...]
            iplus = i + 1
            intersection_in = intersects[i]
            intersection_out = intersects[iplus]
            if intersection_in == intersection_out
              # the polygon has a point exactly on the border of a shortcut zone here!
              # only select the top shortcut if it is actually inside the polygon (point a little up is inside)
              if inside_polygon(Helpers.coord2int(intersection_in), Helpers.coord2int(lat) + 1, x_longs,
                                y_longs)
                shortcuts_for_line.add([x_shortcut(intersection_in), y_shortcut(lat) - 1])
              end
              # the bottom shortcut is always selected
              shortcuts_for_line.add([x_shortcut(intersection_in), y_shortcut(lat)])

            else
              # add all the shortcuts for the whole found area of intersection
              possible_y_shortcut = y_shortcut(lat)

              # both shortcuts should only be selected when the polygon doesnt stays on the border
              middle = intersection_in + (intersection_out - intersection_in) / 2
              if inside_polygon(Helpers.coord2int(middle), Helpers.coord2int(lat) + 1, x_longs, y_longs)
                while intersection_in < intersection_out
                  possible_longitudes << intersection_in
                  intersection_in += step
                end

                possible_longitudes << intersection_out

                # the shortcut above and below of the intersection should be selected!
                possible_y_shortcut_min1 = possible_y_shortcut - 1
                possible_longitudes.each do |possible_x_coord|
                  shortcuts_for_line.add([x_shortcut(possible_x_coord), possible_y_shortcut])
                  shortcuts_for_line.add([x_shortcut(possible_x_coord), possible_y_shortcut_min1])
                end
              else
                # polygon does not cross the border!
                while intersection_in < intersection_out
                  possible_longitudes << intersection_in
                  intersection_in += step
                end

                possible_longitudes << intersection_out

                # only the shortcut above of the intersection should be selected!
                possible_longitudes.each do |possible_x_coord|
                  shortcuts_for_line.add([x_shortcut(possible_x_coord), possible_y_shortcut])
                end
              end
            end
          end
        end

        # puts('now all the longitudes to check')
        # same procedure horizontally
        step = 1.0 / NR_SHORTCUTS_PER_LAT
        longitudes_to_check(xmax, xmin).each do |lng|
          # puts(lng)
          # puts(coordinate_to_longlong(lng))
          # puts(x_longs)
          # puts(x_intersections(coordinate_to_longlong(lng), x_longs, y_longs))
          intersects = y_intersections(Helpers.coord2int(lng), x_longs, y_longs).map do |y|
            Helpers.int2coord(y)
          end.sort
          # puts(intersects)

          nr_of_intersects = intersects.length
          if nr_of_intersects.odd?
            fail 'an uneven number of intersections has been accounted'
          end

          possible_latitudes = []
          (0...nr_of_intersects).step(2).each do |i|
            # collect all the zones between two intersections [in,out,in,out,...]
            iplus = i + 1
            intersection_in = intersects[i]
            intersection_out = intersects[iplus]
            if intersection_in == intersection_out
              # the polygon has a point exactly on the border of a shortcut here!
              # only select the left shortcut if it is actually inside the polygon (point a little left is inside)
              if inside_polygon(Helpers.coord2int(lng) - 1, Helpers.coord2int(intersection_in), x_longs,
                                y_longs)
                shortcuts_for_line.add([x_shortcut(lng) - 1, y_shortcut(intersection_in)])
              end
              # the right shortcut is always selected
              shortcuts_for_line.add([x_shortcut(lng), y_shortcut(intersection_in)])

            else
              # add all the shortcuts for the whole found area of intersection
              possible_x_shortcut = x_shortcut(lng)

              # both shortcuts should only be selected when the polygon doesnt stays on the border
              middle = intersection_in + (intersection_out - intersection_in) / 2
              if inside_polygon(Helpers.coord2int(lng) - 1, Helpers.coord2int(middle), x_longs,
                                y_longs)
                while intersection_in < intersection_out
                  possible_latitudes << intersection_in
                  intersection_in += step
                end

                possible_latitudes << intersection_out

                # both shortcuts right and left of the intersection should be selected!
                possible_x_shortcut_min1 = possible_x_shortcut - 1
                possible_latitudes.each do |possible_latitude|
                  shortcuts_for_line.add([possible_x_shortcut, y_shortcut(possible_latitude)])
                  shortcuts_for_line.add([possible_x_shortcut_min1, y_shortcut(possible_latitude)])
                end

              else
                while intersection_in < intersection_out
                  possible_latitudes << intersection_in
                  intersection_in += step
                end
                # only the shortcut right of the intersection should be selected!
                possible_latitudes << intersection_out

                possible_latitudes.each do |possible_latitude|
                  shortcuts_for_line.add([possible_x_shortcut, y_shortcut(possible_latitude)])
                end
              end
            end
          end
        end

        shortcuts_for_line
      end

      def construct_shortcuts(shortcuts)
        puts('building shortcuts...')
        puts('currently in line:')
        line = 0
        @boundaries.each do |xmax, xmin, ymax, ymin|
          # xmax, xmin, ymax, ymin = boundaries_of(line=line)
          if line % 1000 == 0
            puts("line #{line}")
            # puts([xmax, xmin, ymax, ymin])
          end

          column_nrs = included_shortcut_column_nrs(xmax, xmin)
          row_nrs = included_shortcut_row_nrs(ymax, ymin)

          if big_zone(xmax, xmin, ymax, ymin)

            <<EOT
            puts("line #{line}")
            puts('This is a big zone! computing exact shortcuts')
            puts('Nr of entries before')
            puts(len(column_nrs) * row_nrs.length)

            puts('columns and rows before optimisation:')

            puts(column_nrs)
            puts(row_nrs)
EOT

            # This is a big zone! compute exact shortcuts with the whole polygon points
            shortcuts_for_line = compute_exact_shortcuts(xmax, xmin, ymax, ymin, line)
            # n += shortcuts_for_line.length

            <<EOT
            accurracy = 1000000000000
            while len(shortcuts_for_line) < 3 and accurracy > 10000000000
                shortcuts_for_line = compute_exact_shortcuts(line=i,accurracy)
                accurracy = (accurracy/10).to_i
            end
EOT
            min_x_shortcut = column_nrs[0]
            max_x_shortcut = column_nrs[-1]
            min_y_shortcut = row_nrs[0]
            max_y_shortcut = row_nrs[-1]
            shortcuts_to_remove = []

            # remove shortcuts from outside the possible/valid area
            shortcuts_for_line.each do |x, y|
              shortcuts_to_remove << [x, y] if x < min_x_shortcut
              shortcuts_to_remove << [x, y] if x > max_x_shortcut
              shortcuts_to_remove << [x, y] if y < min_y_shortcut
              shortcuts_to_remove << [x, y] if y > max_y_shortcut
            end

            shortcuts_to_remove.each do |s|
              shortcuts_for_line.delete(s)
            end

            <<EOT
            puts('and after:')
            puts(shortcuts_for_line.length)

            column_nrs_after = Set.new
            row_nrs_after = Set.new
            shortcuts_for_line.each do |x, y|
                column_nrs_after.add(x)
                row_nrs_after.add(y)
            end
            puts(column_nrs_after)
            puts(row_nrs_after)
            puts(shortcuts_for_line)
EOT

            if shortcuts_for_line.length > column_nrs.length * row_nrs.length
              fail 'there are more shortcuts than before now. there is something wrong with the algorithm!'
            end
            if shortcuts_for_line.length < 3
              fail 'algorithm not valid! less than 3 zones detected (should be at least 4)'
            end

          else

            shortcuts_for_line = []
            column_nrs.each do |column_nr|
              row_nrs.each do |row_nr|
                shortcuts_for_line << [column_nr, row_nr]

                # puts(shortcuts_for_line)
              end
            end
          end

          shortcuts_for_line.each do |shortcut|
            shortcuts[shortcut] = shortcuts.fetch(shortcut, []) + [line]
          end

          line += 1
          # puts('collected entries:')
          # puts(n)
        end
      end

      # test_length = 0
      @ids.each do |id|
        # test_length += 1
        zone_ids << id
      end

      # if test_length != @nr_of_lines
      #   raise ArgumentError, "#{test_length} #{@nr_of_lines} #{@ids.length}"
      # end

      @all_lengths.each do |length|
        nr_of_floats += 2 * length
      end

      start_time = Time.now
      construct_shortcuts(shortcuts)
      end_time = Time.now

      puts("calculating the shortcuts took: #{end_time - start_time}")

      # address where the actual polygon data starts. look in the description below to get more info
      polygon_address = (24 * @nr_of_lines + 12)

      # for every original float now 4 bytes are needed (int32)
      shortcut_start_address = polygon_address + 4 * nr_of_floats

      # write number of entries in shortcut field (x,y)
      nr_of_entries_in_shortcut = []
      shortcut_entries = []
      amount_filled_shortcuts = 0

      # count how many shortcut addresses will be written:
      (0...(360 * NR_SHORTCUTS_PER_LNG)).each do |x|
        (0...(180 * NR_SHORTCUTS_PER_LAT)).each do |y|
          begin
            this_lines_shortcuts = shortcuts.fetch([x, y])
            shortcut_entries << this_lines_shortcuts
            amount_filled_shortcuts += 1
            nr_of_entries_in_shortcut << this_lines_shortcuts.length
            # puts "(#{x}, #{y}, #{this_lines_shortcuts})"
          rescue KeyError
            nr_of_entries_in_shortcut << 0
          end
        end
      end

      amount_of_shortcuts = nr_of_entries_in_shortcut.length
      if amount_of_shortcuts != 64_800 * NR_SHORTCUTS_PER_LNG * NR_SHORTCUTS_PER_LAT
        puts(amount_of_shortcuts)
        fail ArgumentError, 'this number of shortcut zones is wrong'
      end

      puts("number of filled shortcut zones are: #{amount_filled_shortcuts} (=#{(amount_filled_shortcuts.fdiv(amount_of_shortcuts) * 100).round(2)}% of all shortcuts)")

      # for every shortcut S> and L> is written (nr of entries and address)
      shortcut_space = 360 * NR_SHORTCUTS_PER_LNG * 180 * NR_SHORTCUTS_PER_LAT * 6
      nr_of_entries_in_shortcut.each do |nr|
        # every line in every shortcut takes up 2bytes
        shortcut_space += 2 * nr
      end

      hole_start_address = shortcut_start_address + shortcut_space

      puts("The number of polygons is: #{@nr_of_lines}")
      puts("The number of floats in all the polygons is (2 per point): #{nr_of_floats}")
      puts("now writing file \"#{path}\"")
      output_file = open(path, 'wb')
      # write nr_of_lines
      output_file.write([@nr_of_lines].pack('S>'))
      # write start address of shortcut_data:
      output_file.write([shortcut_start_address].pack('L>'))

      # S> amount of holes
      output_file.write([@amount_of_holes].pack('S>'))

      # L> Address of Hole area (end of shortcut area +1) @ 8
      output_file.write([hole_start_address].pack('L>'))

      # write zone_ids
      zone_ids.each do |zone_id|
        output_file.write([zone_id].pack('S>'))
      end
      # write number of values
      @all_lengths.each do |length|
        output_file.write([length].pack('S>'))
      end

      # write polygon_addresses
      @all_lengths.each do |length|
        output_file.write([polygon_address].pack('L>'))
        # data of the next polygon is at the address after all the space the points take
        # nr of points stored * 2 ints per point * 4 bytes per int
        polygon_address += 8 * length
      end

      if shortcut_start_address != polygon_address
        # both should be the same!
        fail 'shortcut_start_address and polygon_address should now be the same!'
      end

      # write boundary_data
      @boundaries.each do |b|
        output_file.write(b.map { |c| Helpers.coord2int(c) }.pack('l>l>l>l>'))
      end

      # write polygon_data
      @all_coords.each do |x_coords, y_coords|
        x_coords.each do |x|
          output_file.write([Helpers.coord2int(x)].pack('l>'))
        end
        y_coords.each do |y|
          output_file.write([Helpers.coord2int(y)].pack('l>'))
        end
      end

      puts("position after writing all polygon data (=start of shortcut section): #{output_file.tell}")

      # [SHORTCUT AREA]
      # write all nr of entries
      nr_of_entries_in_shortcut.each do |nr|
        fail "There are too many polygons in this shortcuts: #{nr}" if nr > 300
        output_file.write([nr].pack('S>'))
      end

      # write  Address of first Polygon_nr  in shortcut field (x,y)
      # Attention: 0 is written when no entries are in this shortcut
      shortcut_address = output_file.tell + 259_200 * NR_SHORTCUTS_PER_LNG * NR_SHORTCUTS_PER_LAT
      nr_of_entries_in_shortcut.each do |nr|
        if nr == 0
          output_file.write([0].pack('L>'))
        else
          output_file.write([shortcut_address].pack('L>'))
          # each line_nr takes up 2 bytes of space
          shortcut_address += 2 * nr
        end
      end

      # write Line_Nrs for every shortcut
      shortcut_entries.each do |entries|
        entries.each do |entry|
          fail entry if entry > @nr_of_lines
          output_file.write([entry].pack('S>'))
        end
      end

      # [HOLE AREA, Y = number of holes (very few: around 22)]

      # '!H' for every hole store the related line
      i = 0
      @related_line.each do |line|
        fail ArgumentError, line if line > @nr_of_lines
        output_file.write([line].pack('S>'))
        i += 1
      end

      if i > @amount_of_holes
        fail ArgumentError, 'There are more related lines than holes.'
      end

      # 'S>'  Y times [H unsigned short: nr of values (coordinate PAIRS! x,y in int32 int32) in this hole]
      @all_hole_lengths.each do |length|
        output_file.write([length].pack('S>'))
      end

      # '!I' Y times [ I unsigned int: absolute address of the byte where the data of that hole starts]
      hole_address = output_file.tell + @amount_of_holes * 4
      @all_hole_lengths.each do |length|
        output_file.write([hole_address].pack('L>'))
        # each pair of points takes up 8 bytes of space
        hole_address += 8 * length
      end

      # Y times [ 2x i signed ints for every hole: x coords, y coords ]
      # write hole polygon_data
      @all_holes.each do |x_coords, y_coords|
        x_coords.each do |x|
          output_file.write([Helpers.coord2int(x)].pack('l>'))
        end
        y_coords.each do |y|
          output_file.write([Helpers.coord2int(y)].pack('l>'))
        end
      end

      last_address = output_file.tell
      hole_space = last_address - hole_start_address
      if shortcut_space != last_address - shortcut_start_address - hole_space
        fail ArgumentError, 'shortcut space is computed wrong'
      end
      polygon_space = nr_of_floats * 4

      puts("the polygon data makes up #{(polygon_space.fdiv(last_address) * 100).round(2)}% of the file")
      puts("the shortcuts make up #{(shortcut_space.fdiv(last_address) * 100).round(2) }% of the file")
      puts("the holes make up #{(hole_space.fdiv(last_address) * 100).round(2) }% of the file")

      puts('Success!')
    end

    <<EOT
Data format in the .bin:
IMPORTANT: all coordinates (floats) are converted to int32 (multiplied by 10^7). This makes computations much faster
and it takes lot less space, without loosing too much accuracy (min accuracy is 1cm still at the equator)

no of rows (= no of polygons = no of boundaries)
approx. 28k -> use 2byte unsigned short (has range until 65k)
'S>' = n

L> Address of Shortcut area (end of polygons+1) @ 2

S> amount of holes @6

L> Address of Hole area (end of shortcut area +1) @ 8

'S>'  n times [H unsigned short: zone number=ID in this line, @ 12 + 2* lineNr]

'S>'  n times [H unsigned short: nr of values (coordinate PAIRS! x,y in long long) in this line, @ 12 + 2n + 2* lineNr]

'L>'n times [ I unsigned int: absolute address of the byte where the polygon-data of that line starts,
@ 12 + 4 * n +  4*lineNr]



n times 4 int32 (take up 4*4 per line): xmax, xmin, ymax, ymin  @ 12 + 8n + 16* lineNr
'l>l>l>l>'


[starting @ 12+ 24*n = polygon data start address]
(for every line: x coords, y coords:)   stored  @ Address section (see above)
'l>' * amount of points

360 * NR_SHORTCUTS_PER_LNG * 180 * NR_SHORTCUTS_PER_LAT:
[atm: 360* 1 * 180 * 2 = 129,600]
129,600 times S>   number of entries in shortcut field (x,y)  @ Pointer see above


[SHORTCUT AREA]
360 * NR_SHORTCUTS_PER_LNG * 180 * NR_SHORTCUTS_PER_LAT:
[atm: 360* 1 * 180 * 2 = 129,600]
129,600 times S>   number of entries in shortcut field (x,y)  @ Pointer see above


Address of first Polygon_nr  in shortcut field (x,y) [0 if there is no entry] @  Pointer see above + 129,600
129,600 times L>

[X = number of filled shortcuts]
X times S> * amount Polygon_Nr    @ address stored in previous section


[HOLE AREA, Y = number of holes (very few: around 22)]

'S>' for every hole store the related line

'S>'  Y times [S unsigned short: nr of values (coordinate PAIRS! x,y in int32 int32) in this hole]

'L>' Y times [ L unsigned int: absolute address of the byte where the data of that hole starts]

Y times [ 2x i signed ints for every hole: x coords, y coords ]

EOT
  end
end

file_converter = TimezoneFinder::FileConverter.new
file_converter.parse_polygons_from_json('tz_world.json')
file_converter.update_zone_names('timezone_names.rb')
file_converter.compile_into_binary('timezone_data.bin')
