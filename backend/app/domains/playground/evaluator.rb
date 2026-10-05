require "json"
require "stringio"

module Playground
  # Evaluates one snippet and returns a plain hash — no Rails APIs used anywhere
  # in this file on purpose: the plain-Ruby runner loads it into a bare `ruby`
  # subprocess (`ruby -r <this file>`), while the Rails runner calls it after fork.
  #
  # Always runs in a throwaway process, so `$stdout` juggling and `TOPLEVEL_BINDING`
  # pollution die with it — and nothing leaks between two runs.
  #
  # Only what the snippet printed comes back. The value of the last expression is
  # deliberately NOT reported: inspecting it is user code with a cost of its own
  # (`User.all` on a fat table), and `p` says exactly what you want to see.
  module Evaluator
    MAX_OUTPUT = 100_000    # bytes of captured stdout/stderr kept
    MAX_MESSAGE = 10_000    # chars of an exception message kept
    MAX_BACKTRACE = 12      # frames kept (Rails backtraces are hundreds deep)

    # Stops storing at the limit, so an endless print hits the timeout, not the memory limit.
    class CappedOutput < StringIO
      attr_reader :dropped

      def initialize(limit)
        super()
        @limit = limit
        @dropped = 0
      end

      def write(*chunks)
        chunks.sum do |chunk|
          chunk = chunk.to_s
          room = @limit - size
          super(chunk.byteslice(0, room)) if room.positive?
          @dropped += [ chunk.bytesize - room, 0 ].max
          chunk.bytesize
        end
      end

      def report
        return string if dropped.zero?

        "#{string}\n… truncated (#{dropped} more bytes)"
      end
    end

    def self.run(code)
      captured = CappedOutput.new(MAX_OUTPUT)
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = captured
      $stderr = captured

      result =
        begin
          TOPLEVEL_BINDING.eval(code, "(console)", 1)
          {}
        rescue Exception => e # rubocop:disable Lint/RescueException -- SyntaxError/NoMemoryError are results here, not crashes
          { error: describe(e) }
        end

      result.merge(output: clamp(captured.report, MAX_OUTPUT + 100))
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end

    def self.describe(error)
      {
        class: error.class.name,
        message: clamp(error.message.to_s, MAX_MESSAGE),
        backtrace: trim(error.backtrace)
      }
    end

    # Everything from this file down is runner plumbing the user did not write.
    def self.trim(backtrace)
      frames = Array(backtrace)
      own = frames.take_while { |line| !line.include?(__FILE__) }

      (own.empty? ? frames : own).first(MAX_BACKTRACE).map { |line| clamp(line, 500) }
    end

    # JSON.generate rejects invalid byte sequences, which arbitrary user output may contain.
    def self.clamp(string, limit)
      text = string.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      text.length > limit ? "#{text[0, limit]}\n… truncated (#{text.length} chars)" : text
    end
  end
end
