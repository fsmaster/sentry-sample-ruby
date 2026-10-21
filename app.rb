# ruby app.rb error   -> one error from the command line
# ruby app.rb serve   -> POST /trigger on :8080 (dashboard)
require "json"
require "sentry-ruby"
require "webrick"

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = ENV.fetch("SENTRY_ENVIRONMENT", "local")
  config.release = ENV.fetch("RELEASE", "sample-ruby@dev")
  config.send_default_pii = false
end

def parse_price(text)
  Float(text) # ArgumentError for "free"
end

# hub = Sentry.get_current_hub normally; with the dashboard's "Use my DSN"
# a separate hub + client, so only this event goes to the visitor's project
def hub_for(dsn)
  return Sentry.get_current_hub unless dsn

  config = Sentry::Configuration.new
  config.dsn = dsn
  config.environment = "playground"
  config.release = ENV["RELEASE"]
  Sentry::Hub.new(Sentry::Client.new(config), Sentry::Scope.new)
end

def generate(run, fresh = true, dsn = nil)
  hub = hub_for(dsn)
  id = hub.with_scope do |scope|
    scope.set_tags(run_id: run)
    scope.set_fingerprint(["{{ default }}", run]) if fresh
    begin
      parse_price("free-#{run}")
    rescue => e
      hub.capture_exception(e)&.event_id
    end
  end
  hub.current_client.flush if dsn
  id
end

if ARGV.first == "serve"
  server = WEBrick::HTTPServer.new(Port: 8080, AccessLog: [])
  server.mount_proc "/trigger" do |req, res|
    body = JSON.parse(req.body || "{}")
    id = generate(body.fetch("run", "manual"), body.fetch("fresh", true), body["dsn"])
    Sentry.get_current_client.flush
    res["Content-Type"] = "application/json"
    res.body = { event_id: id }.to_json
  end
  trap("TERM") { server.shutdown }
  server.start
else
  puts "event id: #{generate(Time.now.strftime('%H%M%S'))}"
  Sentry.get_current_client.flush
end
