module TimezoneFinder
  class Helpers
    def self.int2coord(int32)
      (int32 / 10**7).to_f
    end

    def self.coord2int(double)
      (double * 10**7).to_i
    end
  end
end
