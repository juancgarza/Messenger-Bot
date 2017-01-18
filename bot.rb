require 'facebook/messenger'
require 'httparty'
require 'json'
include Facebook::Messenger
# NOTE: ENV variables should be set directly in terminal for testing on localhost

# Subcribe bot to your page
Facebook::Messenger::Subscriptions.subscribe(access_token: ENV["ACCESS_TOKEN"])

API_URL = 'https://maps.googleapis.com/maps/api/geocode/json?address='.freeze

IDIOMS = {
  not_found: 'There were no results. Ask again please.',
  ask_location: 'Enter destination',
  unknown_command: "Sorry , didn't recognize you're command.",
  menu_greeting: "What do you want to look up? "
}
MENU_REPLIES =[
  {
    content_type: 'text',
    title: 'Coordinates',
    payload: 'COORDINATES'

  },
{
  content_type: 'text',
  title: 'Full Address',
  payload: 'FULL_ADDRESS'
  }]



def wait_for_user_input
  Bot.on :message do |message|
    case message.text
    when /coord/i , /gps/i
      message.reply(text: IDIOMS[:ask_location])
      process_coordinates
    when /full add/i
      message.reply(text: IDIOMS[:ask_location])
      show_full_address
    when /full ad/i
      message.reply(text:"It's spelled address, anyway..Enter destination")
      show_full_address
  end
end
end
def handle_api_request
  Bot.on :message do |message|
    puts "Received '#{message.inspect}' from '#{message.sender}' "
    parsed_response = get_parsed_response(API_URL , message.text)
    unless parsed_response
      message.reply(text: IDIOMS[:not_found])
      wait_for_user_input
      return
    end
    message.type #let's user know we're doing something
    yield(parsed_response,message)
    wait_for_user_input
  end
end

def process_coordinates
handle_api_request do |api_response,message|
    coord = extract_coordinates(api_response)
    message.reply(text:"Latitude #{coord['lat']} Longitude #{coord['lng']}")
  end
end

def show_full_address
  handle_api_request do |api_response,message|
    full_address = extract_full_address(api_response)
    message.reply(text: full_address)
  end
end

#Talk to API
def get_parsed_response(url,query)
  response =HTTParty.get(url + query)
  parsed = JSON.parse(response.body)
  parsed['status'] != 'ZERO_RESULTS' ? parsed : nil
end

def extract_full_address(parsed)
  parsed['results'].first['formatted_address']
end

def extract_coordinates(parsed)
  parsed['results'].first['geometry']['location']
end

def say(recipient_id, text , quick_replies = nil)
  message_options = {
    recipient:{ id: recipient_id } ,
    message: { text: text }
  }
  if quick_replies
    message_options[:message][:quick_replies] = quick_replies
  end
  Bot.deliver(message_options, access_token: ENV['ACCESS_TOKEN'])
end

def wait_for_any_input
  Bot.on :message do |message|
    show_replies_menu(message.sender['id'],MENU_REPLIES)
end
end

def show_replies_menu(id,quick_replies)
  say(id ,IDIOMS[:menu_greeting],quick_replies)
  wait_for_command
end

wait_for_user_input
