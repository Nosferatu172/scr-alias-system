#!/usr/bin/env ruby
# Script Name: weather.rb
# ID: SCR-ID-20260329033038-N57PST8THW
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: weather
 
require 'net/http'
require 'json'
require 'uri'

# Replace with your own OpenWeatherMap API key
API_KEY = 'your_api_key_here'
CITY = 'London'  # Change the city name to your location

# Build the URL for the API request
url = URI.parse("http://api.openweathermap.org/data/2.5/weather?q=#{CITY}&appid=#{API_KEY}&units=metric")

# Make the API request
response = Net::HTTP.get_response(url)

# Check if the response is successful
if response.is_a?(Net::HTTPSuccess)
  # Parse the response JSON
  weather_data = JSON.parse(response.body)

  # Extract and display weather information
  temperature = weather_data['main']['temp']
  description = weather_data['weather'][0]['description']
  humidity = weather_data['main']['humidity']
  wind_speed = weather_data['wind']['speed']

  puts "Weather in #{CITY}:"
  puts "Temperature: #{temperature}°C"
  puts "Description: #{description.capitalize}"
  puts "Humidity: #{humidity}%"
  puts "Wind speed: #{wind_speed} m/s"
else
  puts "Error: Unable to fetch weather data."
end
