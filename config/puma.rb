# Puma configuration.
#
# Sizing on Heroku: a Basic/Eco dyno has 512MB RAM and 1 shared CPU core, so a
# single Puma process with a handful of threads is the right shape. Add workers
# (WEB_CONCURRENCY) only if you move to a Standard-2X or larger dyno.

# Threads per process. Rails is thread-safe, and this app does almost no work
# per request, so the default of 3 is plenty.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Heroku assigns a port at boot and passes it in as $PORT. Binding to anything
# else is the classic cause of an R10 "Boot timeout" crash.
port ENV.fetch("PORT", 3000)

# Workers = separate OS processes. Each one costs roughly a full copy of the
# app's memory, so leave this unset on a 512MB dyno.
workers ENV.fetch("WEB_CONCURRENCY", 0)

# Only preload when actually running multiple workers.
preload_app! if ENV.fetch("WEB_CONCURRENCY", 0).to_i > 1

# Allow puma to be restarted by `bin/rails restart`.
plugin :tmp_restart

# Give a long timeout in development so that a debugger breakpoint does not
# cause the worker to be reaped.
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"
