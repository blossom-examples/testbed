TESTBED_BOOT_STARTED_AT = Time.now.utc
TESTBED_BOOT_CLOCK = Process.clock_gettime(Process::CLOCK_MONOTONIC)
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
