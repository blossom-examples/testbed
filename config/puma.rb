threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", "5"))
threads threads_count, threads_count
workers Integer(ENV.fetch("WEB_CONCURRENCY", "0"))
bind "tcp://0.0.0.0:#{ENV.fetch("PORT", "3000")}"
