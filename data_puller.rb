require 'csv'
require 'aws-sdk-v1'
require 'active_support/all'

queue_names = ["spi-production", "neat_scan_spi-production", "mobile_spi-production", "freemium_spi-production"]

cw = AWS::CloudWatch.new
metrics = cw.metrics

queue_metrics = queue_names.flat_map { |q| metrics.with_dimension("QueueName", q).with_metric_name("NumberOfMessagesSent").to_a }

statistics = queue_metrics.flat_map {|m| m.statistics(start_time: 14.days.ago, end_time:  Time.now, statistics: ['Sum'], period: 60 * 60).to_a }

sums = statistics.each_with_object({}) do |s,acc|
  acc[s[:timestamp]] ||= 0
  acc[s[:timestamp]] += s[:sum]
end

csv = sums.each_with_object({}) do |(timestamp,sum),acc|
  weekday = timestamp.wday
  hour = timestamp.hour
  acc[weekday] ||= {}
  acc[weekday][hour] ||= 0
  acc[weekday][hour] += sum.to_i
end

CSV.open("results.csv", "w") do |c|
  c << ["day", "hour", "count"]
  csv.each do |day,hours|
    hours.each do |hour,sum|
      c << [day, hour, sum]
    end
  end
end

weekdays = sums.each_with_object({}) do |(time,sum),acc|
  next if time.sunday? || time.saturday?
  hour = time.hour
  acc[hour] ||= []
  acc[hour] << sum.to_i
end

CSV.open("weekdays.csv", "w") do |c|
  c << ["hour", "count"]
  weekdays.each do |line|
    c << [line.first, line.second.inject{ |sum, el| sum + el }.to_f / line.second.size]
  end
end

weekends = sums.each_with_object({}) do |(time,sum),acc|
  next unless time.sunday? || time.saturday?
  hour = time.hour
  acc[hour] ||= []
  acc[hour] << sum.to_i
end

CSV.open("weekends.csv", "w") do |c|
  c << ["hour", "count"]
  weekends.each do |line|
    c << [line.first, line.second.inject{ |sum, el| sum + el }.to_f / line.second.size]
  end
end
