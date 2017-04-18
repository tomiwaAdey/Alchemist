require "bundler"
Bundler.require
require 'date'

require_relative 'config'

module Library
  CONTENT = 1
  TYPE = 2
  IMAGE = 3
  SHORTEN = 4
  MARKED = 6

  def clean_value(val)
    val.to_s.strip.downcase
  end

  def select_content(type)
    # Creates a session. This will prompt the credential via command line for the
    # first time and save it to config.json file for later usages.
    session = GoogleDrive::Session.from_config("gdrive_config.json")
    sheet = session.spreadsheet_by_key($GOOGLESHEETKEY).worksheets[0]

    # Select rows where type is the type entered by user
    rows_of_type = (2..sheet.num_rows).select {|row| clean_value(sheet[row, TYPE]) === clean_value(type) }

    #Find the one where marked is true if any
    marked = rows_of_type.find { |row| clean_value(sheet[row, MARKED]) === clean_value("TRUE")  }

    #Choose the next row after the market row if there's a marked row for that content type
    if !marked.nil?
      selected_index = rows_of_type.index(marked)
      selected_row = rows_of_type[selected_index + 1] || rows_of_type[0]
    else
      selected_row = rows_of_type[0]
    end

    #Clear marked = true for any rows of the content type
    clear_rows_of_type(rows_of_type, sheet)

    #Mark selected row
    sheet[selected_row, MARKED] = "TRUE"
    sheet.save

    return { "content" => sheet[selected_row, CONTENT], "image" => sheet[selected_row, IMAGE], "shorten" => sheet[selected_row, SHORTEN]}
  end

  def clear_rows_of_type(rows_of_type, sheet)
    rows_of_type.each do |row|
      if clean_value(sheet[row, MARKED]) === clean_value("TRUE")
        sheet[row, MARKED] = ''
        sheet.save
      end
    end
  end
end

module Buffer
  class Client
    include Library
    attr_accessor :access_token

    def initialize(access_token)
      @access_token = access_token
      url = "https://api.bufferapp.com/1/"
      @connection = Faraday.new(url: url) do |faraday|
        faraday.request :url_encoded
        faraday.response :logger
        faraday.adapter Faraday.default_adapter
      end
    end

    #Get the id of a buffer profile
    def get_profile_id(id)
      JSON.parse(@connection.get('/1/profiles.json', { access_token: @access_token }).body)[id]['id']
    end

    #Create update on buffer
    def create_update(content, profile_id)
      options = {
        profile_ids: [profile_id],
      }
      # If content text is present, add it to the array
      if !clean_value(content['content']).empty?
        options['text'] = content['content']
      end
      #Only If shorten is set to false
      if clean_value(content['shorten']) === clean_value("FALSE")
        options['shorten'] = false
      end
      #If content photo is present, add to the array
      if !clean_value(content['image']).empty?
        options['media']['photo'] = content['image']
      end
      options['access_token'] = @access_token
      @connection.post('/1/updates/create.json', options )
    end

    def schedule_post(type, profile_ids = [0])
      profile_ids.each do |pid|
        with_error_handling do
          #Get profile id
          profile_id = get_profile_id(pid)

          #Select content
          content = select_content(type)

          #Update buffer with content
          create_update(content, profile_id)
        end
      end
    end

    def with_error_handling
    	yield
    rescue => e
    	return e
    end

  end

end

def add_to_buffer
  #Get today's date
  date_today = Time.now.strftime("%A")

  #Initialize Buffer
  client = Buffer::Client.new($ACCESSTOKEN)

  #This is where you scedule your posts
  #Remember Buffer's free account limits you to just 10 scheduled post per account
  if date_today === "Monday"
    client.schedule_post('Funny',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('General',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('Link to My Blog',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
  elsif date_today === "Tuesday"
    client.schedule_post('Funny',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('General',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('Link to Other Content',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
  elsif date_today === "Wednesday"
    client.schedule_post('Funny',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('General',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('Link to My Blog',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
  elsif date_today === "Thursday"
    client.schedule_post('Funny',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('General',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('Link to Other Content',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
  elsif date_today === "Friday"
    client.schedule_post('Funny',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('General',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('Link to My Blog',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
  elsif date_today === "Saturday"
    client.schedule_post('Funny',[$TWITTER ,$FACEBOOK])
    client.schedule_post('Link to Other Content',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
  elsif date_today === "Sunday"
    client.schedule_post('Funny',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('General',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
    client.schedule_post('Link to My Blog',[$TWITTER, $FACEBOOK, $GOOGLEPLUS])
  end

end

#Use cron job - everyday
add_to_buffer
