# frozen_string_literal: false

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number.gsub!(/[^0-9]/, '')
  if phone_number.length == 10 || phone_number.length == 11 && phone_number[0, 1] == '1'
    phone_number.delete_prefix('1').insert(3, '-').insert(-5, '-')
  else
    'Not given'
  end
end

def get_legislators(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  civic_info.representative_info_by_address(
    address: zip,
    levels: 'country',
    roles: %w[legislatorUpperBody legislatorLowerBody]
  ).officials
end

def legislators_by_zipcode(zip)
  get_legislators(zip)
rescue StandardError
  'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def save_reg_time_data(reg_times)
  CSV.open('reg_times.csv', 'wb') do |csv|
    csv << ['Time of Day', 'Number of Registrations']
    reg_times.each do |elem|
      csv << elem
    end
  end
end

def save_hash_data(filename, hash_data, header_data)
  CSV.open(filename, 'wb') do |csv|
    csv << header_data
    hash_data.each do |elem|
      csv << elem
    end
  end
end

def get_reg_time(reg_time)
  times_of_day = { 0..6 => 'EarlyHours', 7..11 => 'Morning',
                   12..14 => 'Lunchtime', 15..17 => 'Afternoon',
                   18..20 => 'Evening', 21..23 => 'LateEvening' }
  times_of_day.select { |time_range| time_range.include?(reg_time) }.values.first
end

puts 'EventManager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_times = Hash.new(0)
week_days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  reg_date = Date.strptime(row[1], '%m/%d/%y')
  reg_time = Time.strptime(row[1], '%m/%d/%y %k:%M').strftime('%k').to_i

  reg_times[get_reg_time(reg_time)] += 1
  week_days[reg_date.strftime('%A')] += 1

  zipcode = clean_zipcode(row[:zipcode])

  phone_number = clean_phone_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

save_hash_data('reg_times.csv', reg_times, ['Time of Day', 'Number of Registrations'])
save_hash_data('week_days.csv', week_days, ['Day of the Week', 'Number of Registrations'])
