require 'Sinatra'


# Note: ENV variables should be set directly in terminal for testing on localhost

# Talk to facebook
get '/webhook' do
  params['hub.challenge'] if ENV["VERIFY_TOKEN"] == params['hub.verify_token']
end

get "/" do
  "Nothing to see here."
end
