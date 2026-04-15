#!/usr/bin/env ruby
# Script Name: testthreads.rb
# ID: SCR-ID-20260329033034-20645B8RQD
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: testthreads

cpuinfo = File.read("/proc/cpuinfo")

# Count total logical threads
logical_threads = cpuinfo.scan(/^processor\s+:/).size

# Extract unique physical core IDs (core_id + physical_id)
core_ids = cpuinfo.scan(/^physical id\s+:\s+(\d+).*?^core id\s+:\s+(\d+)/m)
unique_cores = core_ids.uniq.size

puts "Detected Physical Cores: #{unique_cores}"
puts "Detected Logical Threads: #{logical_threads}"

# You can now set your workload accordingly:
puts "Suggested max thread count for full load: #{logical_threads}"
puts "Suggested safe physical core usage: #{unique_cores}"
