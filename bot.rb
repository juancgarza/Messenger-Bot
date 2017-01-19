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

  Bot.on :postback do |postback|
    sender_id = postback.sender['id']
    case postback.payload
    when 'START' then show_replies_menu(postback.sender['id'], MENU_REPLIES)
    when 'COORDINATES'
      say(sender_id, IDIOMS[:ask_location], [{ content_type: 'location' }])
      show_coordinates(sender_id)
    when 'FULL_ADDRESS'
      say(sender_id, IDIOMS[:ask_location], [{ content_type: 'location' }])
      show_full_address(sender_id)
    when 'LOCATION'
      lookup_location(sender_id)
    end
  end


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


def wait_for_command
  Bot.on :message do |message|
    puts "Received '#{message.inspect}' from #{message.sender}" # debug only
    sender_id = message.sender['id']
    case message.text
    when /coord/i, /gps/i
      message.reply(text: IDIOMS[:ask_location])
      show_coordinates(sender_id)
    when /full ad/i # we got the user even the address is misspelled
      message.reply(text: IDIOMS[:ask_location])
      show_full_address(sender_id)
    else
      message.reply(text: IDIOMS[:unknown_command])
      show_replies_menu(sender_id, MENU_REPLIES)
    end
  end
end


def handle_api_request
  Bot.on :message do |message|
    parsed_response = get_parsed_response(API_URL, message.text)
    message.type # let user know we're doing something
    if parsed_response
      yield(parsed_response, message)
      wait_for_any_input
    else
      message.reply(text: IDIOMS[:not_found])
      # meta-programming voodoo to call the callee
      callee = Proc.new { caller_locations.first.label }
      callee.call
    end
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
# Set call to action button when user is about to address bot
# for the first time.
Facebook::Messenger::Thread.set({
  setting_type: 'call_to_actions',
  thread_state: 'new_thread',
  call_to_actions: [
    {
      payload: 'START'
    }
  ]
}, access_token: ENV['ACCESS_TOKEN'])

# Create persistent menu
Facebook::Messenger::Thread.set({
  setting_type: 'call_to_actions',
  thread_state: 'existing_thread',
  call_to_actions: [
    {
      type: 'postback',
      title: 'Get coordinates',
      payload: 'COORDINATES'
    },
    {
      type: 'postback',
      title: 'Get full address',
      payload: 'FULL_ADDRESS'
    }
  ]
}, access_token: ENV['ACCESS_TOKEN'])

# Set greeting (for first contact)
Facebook::Messenger::Thread.set({
  setting_type: 'greeting',
  greeting: {
    text: 'Coordinator welcomes you!'
  },
}, access_token: ENV['ACCESS_TOKEN'])


wait_for_any_input
