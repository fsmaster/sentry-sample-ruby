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

def generate(run, fresh = true)
  Sentry.with_scope do |scope|
    scope.set_tags(run_id: run)
    scope.set_fingerprint(["{{ default }}", run]) if fresh
    begin
      parse_price("free-#{run}")
    rescue => e
      Sentry.capture_exception(e)&.event_id
    end
  end
end

if ARGV.first == "serve"
  server = WEBrick::HTTPServer.new(Port: 8080, AccessLog: [])
  server.mount_proc "/trigger" do |req, res|
    body = JSON.parse(req.body || "{}")
    id = generate(body.fetch("run", "manual"), body.fetch("fresh", true))
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
