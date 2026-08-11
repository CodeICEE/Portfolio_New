require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Make code changes take effect immediately without a server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Add Server-Timing headers so you can see where request time goes in devtools.
  config.server_timing = true

config.assets.compile = true
config.assets.debug = true

  # Action Controller caching is off by default. Run `rails dev:cache` to toggle.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Change to :null_store to avoid any caching.
  config.cache_store = :memory_store

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Highlight the code that enqueued a background job in the logs.
  config.active_job.verbose_enqueue_logs = true

  # Raise on missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered HTML with the view file that produced it. Very handy when
  # you are finding your way back around a codebase.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise an error when a before_action's only/except option references a
  # missing action.
  config.action_controller.raise_on_missing_callback_actions = true
end
