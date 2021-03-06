require 'rubygems'
require 'open-uri'
require 'csv'
require 'fileutils'
require 'json'

VDWEvent = Struct.new( 
  :day,
  :title, 
  :description, 
  :start_time, 
  :end_time, 
  :event_type, 
  :address, 
  :address_label, 
  :event_url, 
  :event_url_label, 
  :published, 
  :address_lat, 
  :address_long,
  :price
)

def markdownPostForEvent(event, priority)
  escapedTitled = event.title.gsub('"', '\"');
  escapedDescription = event.description.gsub('"', '\"');

  dayNumber = event.day.strftime("%d")
  dayOfWeek = event.day.strftime("%a")
  dayOfMonth = event.day.strftime("Sept %d")
  
  formattedTime = ""
  if event.start_time.to_s != ''
    formattedTime = event.start_time + (event.end_time.to_s == '' ? "" : " - " + event.end_time)
  end
  
  isPublished = (event.published == 'YES')  
  
  timestamp = event.day.strftime("%Y-%m-%d")
  cleanTitle = event.title.gsub(' ','_').gsub(/[^A-Za-z0-9_]/i, '').downcase
  slug = timestamp + "-" + cleanTitle

  content =  
  "---
dayOfWeek: #{dayOfWeek}
dayOfMonth: #{dayOfMonth}
title: \"#{escapedTitled}\"
description: \"#{escapedDescription}\"
startTime: #{event.start_time}
endTime: #{event.end_time}
type: #{event.event_type}
address: \"#{event.address}\"
addressLabel: #{event.address_label}
latitude: #{event.address_lat}
longitude: #{event.address_long}
eventUrl: #{event.event_url}
eventUrlLabel: #{event.event_url_label}
published: #{isPublished}
price: #{event.price}

category: event-#{dayNumber}
priority: #{priority}
slug: #{slug}
---
"
  return content
end

def readCSV(url)
  totalEvents = 0;
  csv = CSV.new(open(url))
  
  header = Array.new

  previousDay = "";
  priority = 0
  csv.each do |line|
    print '.'
    STDOUT.flush
    if priority == 0
      header = line
      priority += 1;
    else
      # todo: check for empty rows
      if line[header.index('Published')] == 'YES' && line[header.index('Address')].to_s != ''
        event = VDWEvent.new
        event.day = Date.strptime(line[header.index('Day')], "%m/%d/%Y")
        if event.day != previousDay
          priority = 1;
        end
        previousDay = event.day
        event.title = line[header.index('Title')].tr("\n"," ")
        event.description = line[header.index('Description')].tr("\n"," ")
        event.start_time = line[header.index('Start Time')]
        event.end_time = line[header.index('End Time')]
        event.event_type = line[header.index('Type')]
        event.address = line[header.index('Address')].tr("\n"," ")
        event.address_label = line[header.index('Address Label')]
        event.event_url = line[header.index('URL')]
        event.event_url_label = line[header.index('URL Label')]
        event.published = line[header.index('Published')]
        event.address_lat = line[header.index('Lat')]
        event.address_long = line[header.index('Long')]
        event.price = line[header.index('Price')]

        if event.address_lat.to_s == '' || event.address_long.to_s == ''
          google_api_key = "AIzaSyBQDsHDBRQtL2hZl9Jl7sg002VSokqvlZk"
          geocoder = JSON.parse(open("https://maps.googleapis.com/maps/api/geocode/json?address=#{URI::encode(event.address)}&key=#{google_api_key}").string)
          if geocoder && geocoder["results"].length > 0
            event.address_lat = geocoder["results"][0]["geometry"]["location"]["lat"]
            event.address_long = geocoder["results"][0]["geometry"]["location"]["lng"]
          end  
        end
        
        content = markdownPostForEvent(event, priority)

        formattedDate = event.day.strftime("%Y-%m-%d")
        cleanTitle = event.title.gsub(' ','_').gsub(/[^A-Za-z0-9_]/i, '').downcase
        slug = formattedDate + "-" + cleanTitle
        filename = ("_posts/#{slug}.md")
        File.write(filename, content)  
        priority += 1
        totalEvents += 1;
      end
    end
    
  end

  puts " #{totalEvents} events posted."
end

puts "Fetching events:"

csvURL = "https://docs.google.com/spreadsheets/d/1Sd6MkT_z-kTBtzozSb_6ZfJyO6TcgGzS0VTYavrzI7I/export?gid=0&format=csv"
# csvURL = "https://docs.google.com/spreadsheets/d/1zlSwKyHZ3ui-hNivaKdZIKINvn45fX3td0xvI4Hu0CU/export?gid=0&format=csv"

# remove all previous markdown files:
FileUtils.rm_rf(Dir.glob('_posts/*'))
readCSV(csvURL)
