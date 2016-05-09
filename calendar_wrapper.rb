require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'sinatra'
require 'logger'
require 'json'

enable :sessions

CREDENTIAL_STORE_FILE = "#{$0}-oauth2.json"

def logger; settings.logger end

def api_client; settings.api_client; end

def calendar_api; settings.calendar; end

def user_credentials
  # Build a per-request oauth credential based on token stored in session
  # which allows us to use a shared API client.
  @authorization ||= (
    auth = api_client.authorization.dup
    auth.redirect_uri = to('/oauth2callback')
    auth.update_token!(session)
    auth
  )
end

configure do
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG

  client = Google::APIClient.new(
    :application_name => 'Ruby Calendar sample',
    :application_version => '1.0.0')

  file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
  if file_storage.authorization.nil?
    client_secrets = Google::APIClient::ClientSecrets.load
    client.authorization = client_secrets.to_authorization
    client.authorization.scope = 'https://www.googleapis.com/auth/calendar'
  else
    client.authorization = file_storage.authorization
  end

  # Since we're saving the API definition to the settings, we're only retrieving
  # it once (on server start) and saving it between requests.
  # If this is still an issue, you could serialize the object and load it on
  # subsequent runs.
  calendar = client.discovered_api('calendar', 'v3')

  set :logger, logger
  set :api_client, client
  set :calendar, calendar
end

before do
  # Ensure user has authorized the app
  unless user_credentials.access_token || request.path_info =~ /\A\/oauth2/
    redirect to('/oauth2authorize')
  end
end

after do
  # Serialize the access/refresh token to the session and credential store.
  session[:access_token] = user_credentials.access_token
  session[:refresh_token] = user_credentials.refresh_token
  session[:expires_in] = user_credentials.expires_in
  session[:issued_at] = user_credentials.issued_at

  file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
  file_storage.write_credentials(user_credentials)
end

get '/oauth2authorize' do
  # Request authorization
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
  redirect to('/')
end

get '/' do
  current_time = DateTime.now
  day_end = (Date.today+1)
  g_events = api_client.execute(:api_method => calendar_api.events.list,
                              :parameters => {'calendarId' => 'cheppers.com_2d32353038373534353337@resource.calendar.google.com',
                                              'timeMin' => current_time.rfc3339,
                                              'timeMax' => day_end.rfc3339,
                                              'timeZone' => 'Europe/Budapest',
                                              'singleEvents' => true,
                                              'orderBy' => 'startTime'
                                              },
                              :authorization => user_credentials)
  g_events = JSON.parse(g_events.data.to_json)
  next_events = g_events['items'].map do |e|
    {
      name: e['summary'],
      start: DateTime.rfc3339(e['start']['dateTime']),
      end: DateTime.rfc3339(e['end']['dateTime'])
    }
  end
  current_event = nil
  if next_events.first[:start] > current_time
    current_event = {
      name: 'Available',
      end: next_events.first[:start]
    }
  else
    current_event = next_events.shift
  end
  calendar_name = g_events['summary']
  @ws_json = {room_name: calendar_name, current_event: current_event, next_events: next_events}
  erb :dashboard
end

get '/calendars' do
  # Fetch list of events on the user's default calandar
  result = api_client.execute(:api_method => calendar_api.calendar_list.list,
                              :authorization => user_credentials)
  [result.status, {'Content-Type' => 'application/json'}, result.data.to_json]
end
