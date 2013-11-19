require 'sinatra'
require 'json'
require 'redis'

post '/cloud-event/register' do
  address, name, location, timezone = params.values_at(:address, :name, :location, :timezone)

  device = {
    'address' => address,
    'name' => name,
    'location' => location,
    'timezone' => timezone
  }
  db.hset('devices', address, JSON.dump(device))

  204
end

post '/cloud-event/deregister' do
  address, name = params.values_at(:address, :name)

  db.hdel('devices', address)

  204
end

post '/cloud-event/announce' do
  address, version = params.values_at(:address, :version)

  device = JSON.parse(db.hget('devices', address))
  device.merge!(:version => version)
  db.hset('devices', address, JSON.dump(device))

  204
end

post '/cloud-event/add-owner' do
  address, name, email = params.values_at(:address, :name, :email)

  user = {
    'name' => name,
    'email' => email
  }
  db.hset('users', email, JSON.dump(user))
  db.sadd("ownerships:#{address}", email)

  204
end

post '/cloud-event/remove-owner' do
  address, name, email = params.values_at(:address, :name, :email)

  user = {
    'name' => name,
    'email' => email
  }
  db.srem("ownerships:#{address}", email)

  204
end

post '/device-event/counter' do
  address, name, format, payload = params.values_at(:address, :name, :format, :payload)
  title, value = JSON.parse(payload)

  db.hset('counts', address, value)

  204
end

get '/' do
  erb :index, :locals => { :devices => devices, :counts => counts }
end

helpers do

  def db
    @db ||= Redis.new
  end

  def counts
    db.hgetall('counts')
  end

  def devices
    @devices ||= load_from_json_hash('devices')
  end

  def load_from_json_hash(key)
    Hash[db.hgetall(key).map { |k,v| [k, JSON.parse(v)] }]
  end
end
