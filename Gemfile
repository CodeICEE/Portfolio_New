source "https://rubygems.org"

# Ruby version. Heroku reads the matching "RUBY VERSION" block out of
# Gemfile.lock, so run `bundle install` after changing this.
ruby "3.4.10"

# --- Framework -------------------------------------------------------------

gem "rails", "~> 8.1.3"

# Puma is the app server. Heroku runs it via the Procfile.
gem "puma", ">= 6.0"

# --- Asset pipeline --------------------------------------------------------

# Propshaft is the Rails 8 asset pipeline. It fingerprints and serves files;
# it does NOT transpile or bundle anything.
gem "propshaft"

# Compiles app/assets/stylesheets/application.scss into
# app/assets/builds/application.css using the Dart Sass binary.
gem "dartsass-rails"

# --- Boot / platform -------------------------------------------------------

# Caches expensive boot-time work (path lookups, YAML, ISeq).
gem "bootsnap", require: false

# Windows and JRuby do not ship the tz database.
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  # Modern replacement for byebug. `binding.break` drops you into a console.
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end

group :development do
  # Interactive console on the exception page.
  gem "web-console"
end

group :test do
  gem "capybara"
  # Selenium 4.11+ downloads matching drivers itself, so the `webdrivers`
  # gem is no longer needed (and is no longer maintained).
  gem "selenium-webdriver"
end
