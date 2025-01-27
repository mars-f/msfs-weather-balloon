# frozen_string_literal: true

require 'httparty'

# Docs at https://aviationweather.gov/data/api

def retrieve_metar(station_id)
  url = "https://aviationweather.gov/api/data/metar?ids=#{station_id}&format=json"
  HTTParty.get(url).parsed_response.first
end
