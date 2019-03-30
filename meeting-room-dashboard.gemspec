Gem::Specification.new do |s|
  s.name          = 'meeting-room-dashboard'
  s.version       = '0.1'
  s.authors       = ['Cheppers']
  s.email         = ['']

  s.summary       = 'Meeting room dashboard.'
  s.description   = ''
  s.homepage      = 'https://cheppers.com'

  s.add_dependency 'puma', '~> 3.12'
  s.add_dependency 'faye-websocket', '~> 0.10'
  s.add_dependency 'sinatra', '~> 2.0'
  s.add_dependency 'google-api-client', '~> 0.28'
  s.add_dependency 'signet', '~> 0.11'
  s.add_dependency 'rufus-scheduler', '~> 3.5'
  s.add_dependency 'tzinfo-data', '~> 1'
end
