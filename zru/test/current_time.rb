#!/usr/bin/env ruby
# Script Name: current_time.rb
# ID: SCR-ID-20260329033016-WIX919CR20
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: current_time
 
require 'colorize'
# Get the current time
current_time = Time.now

# Format the time (e.g., "2024-12-31 14:30:00")
formatted_time = current_time.strftime("%Y-%m-%d %H:%M:%S")

# Display the formatted time
puts "[----------------------------------------------------------------------------------------------]".colorize(:magenta)
puts "[ Current time: <-------------------------------------------> #{formatted_time} <----------> ]".colorize(:cyan)
puts "[----------------------------------------------------------------------------------------------]".colorize(:magenta)
