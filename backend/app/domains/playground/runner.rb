module Playground
  # Entry point for the "Rails console" tab: picks a runner, times the round trip,
  # and returns the hash the API renders.
  #
  # Executing user-supplied Ruby is inherently dangerous, so it is limited to
  # local environments unless PLAYGROUND_CONSOLE=true is set deliberately.
  class Runner
    CONTEXTS = %w[rails ruby].freeze
    DEFAULT_TIMEOUT = 5

    RUNNERS = {
      "rails" => Runners::RailsProcess, # fork of this process — models and the database are live
      "ruby" => Runners::RubyProcess    # bare `ruby` subprocess — no Rails, no database
    }.freeze

    def self.enabled?
      Rails.env.local? || ENV["PLAYGROUND_CONSOLE"] == "true"
    end

    def self.call(code:, context: "rails", timeout: DEFAULT_TIMEOUT)
      runner = RUNNERS.fetch(context)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = runner.call(code, timeout: timeout)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      {
        output: result[:output].to_s,
        error: result[:error],
        context: context,
        duration_ms: (elapsed * 1000).round
      }
    end
  end
end
