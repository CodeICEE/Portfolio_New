require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Serve everything in /public plus everything Propshaft has fingerprinted
  # directly from the dyno. There is no NGINX in front of us on Heroku.
  config.public_file_server.enabled = true

  # Fingerprinted assets can be cached forever - the digest in the filename
  # changes whenever the contents change.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Do not fall back to compiling assets at runtime. If an asset is missing at
  # this point the build was wrong, and we want to know about it.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Heroku's router terminates TLS and forwards over plain HTTP with an
  # X-Forwarded-Proto header. `assume_ssl` tells Rails to trust that header so
  # that `force_ssl` redirects correctly instead of looping forever.
  config.assume_ssl = true
  config.force_ssl = true

  # Log to STDOUT. Heroku's log drain reads the process's stdout; there is no
  # persistent filesystem to write log files to.
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [:request_id]

  # Keep health check pings out of the logs.
  config.silence_healthcheck_path = "/up"

  # Do not log deprecations in production.
  config.active_support.report_deprecations = false

  # Swap in a durable cache store here if you ever need one.
  # config.cache_store = :mem_cache_store

  config.action_mailer.perform_caching = false

  # Set host to be used by links generated in mailer templates.
  # config.action_mailer.default_url_options = { host: "example.com" }

  # Enable locale fallbacks for I18n.
  config.i18n.fallbacks = true

  # DNS-rebinding protection. Left off so that both <app>.herokuapp.com and any
  # custom domain work out of the box. Uncomment and list your hosts to lock
  # the app down to specific domains.
  # config.hosts = ["example.com", /.*\.example\.com/]

  # Skip host authorization for the health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
