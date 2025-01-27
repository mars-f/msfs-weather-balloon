require_relative 'metar'
require_relative 'simconnect'

def print_diff(metar, obs)
  # METAR
  #   {"metar_id"=>684715125, "icaoId"=>"KGCK", "receiptTime"=>"2025-01-27 00:58:25", "obsTime"=>1737939240, "reportTime"=>"2025-01-27 01:00:00", "temp"=>-3.9, "dewp"=>-12.8, "wdir"=>100, "wspd"=>6, "wgst"=>nil, "visib"=>"10+", "altim"=>1026.2, "slp"=>1029.5, "qcField"=>4, "wxString"=>nil, "presTend"=>nil, "maxT"=>nil, "minT"=>nil, "maxT24"=>nil, "minT24"=>nil, "precip"=>nil, "pcp3hr"=>nil, "pcp6hr"=>nil, "pcp24hr"=>nil, "snow"=>nil, "vertVis"=>nil, "metarType"=>"METAR", "rawOb"=>"KGCK 270054Z 10006KT 10SM CLR M04/M13 A3030 RMK AO2 SLP295 T10391128", "mostRecent"=>1, "lat"=>37.9221, "lon"=>-100.723, "elev"=>877, "prior"=>3, "name"=>"Garden City Rgnl, KS, US", "clouds"=>[{"cover"=>"CLR", "base"=>nil}]}
  #
  # SimConnect
  #   {:time=>63873536423.109, :agl=>3.2614326097436788, :longitude=>0.66183069276231, :latitude=>-1.7579479711588502, :precip_rate=>0.0, :precip_state=>2.0, :pressure=>26.931893448416933, :temperature=>15.000696182250977, :visibility=>138600.0, :wind_direction=>269.9949645996094, :wind_velocity=>1.000000051576682, :in_cloud=>0.0}

  puts "Station: #{metar['icaoId']}"
  puts "%-12s%-12s%-12s" % %w[Measure METAR Simulator]
  puts

  fmt = "%-12s%-12.1f%-12.1f"

  puts fmt % ['temp', metar['temp'], obs[:temperature]]
  puts fmt % ['dewpoint', metar['dewp'], Float::NAN]
  puts fmt % ['wind_dir', metar['wdir'], obs[:wind_direction]]
  puts fmt % ['wind_speed', metar['wspd'], obs[:wind_velocity]]
  puts "%-12s%-12s%-12.0f" % ['visibility', metar['visib'], obs[:visibility]]
  puts fmt % ['altimeter', metar['altim'], obs[:pressure_qnh]]
  puts
end

setup_simconnect

stations = %w[cyyz kdtw kord]

stations.each do |station|
  metar = retrieve_metar(station)
  teleport(metar['lat'], metar['lon'])
  sleep(10)
  obs = observe_local_weather
  print_diff(metar, obs)
end

