require "json"
require "open3"
require "tempfile"

module Playground
  module Runners
    # Runs the snippet in a bare `ruby` subprocess: no Rails, no database, no gems.
    # Slower to start than a fork but fully isolated — the "codeinterview" mode.
    class RubyProcess
      # -r loads the evaluator (plain Ruby, see Playground::Evaluator), -e prints its
      # verdict as JSON, and the snippet itself travels in a file to dodge shell quoting.
      BOOT = "print JSON.generate(Playground::Evaluator.run(File.read(ARGV[0])))".freeze

      def self.call(code, timeout:, context: nil)
        file = Tempfile.new([ "console", ".rb" ])
        file.write(code)
        file.flush

        # Without unbundling, the child inherits RUBYOPT=-rbundler/setup from Puma and
        # boots against the app's Gemfile — slow, and it fails outside the bundle.
        Bundler.with_unbundled_env { spawn_ruby(file.path, timeout) }
      ensure
        file&.close!
      end

      def self.spawn_ruby(path, timeout)
        Open3.popen3(RbConfig.ruby, "-r", evaluator_path, "-e", BOOT, path) do |stdin, stdout, stderr, wait|
          stdin.close
          # Drain both pipes in threads: a snippet printing more than the pipe buffer
          # would block forever if we joined the process first.
          out = Thread.new { stdout.read }
          err = Thread.new { stderr.read }

          next parse(out.value, err.value) if wait.join(timeout)

          kill(wait)
          [ out, err ].each(&:kill)
          timed_out(timeout)
        end
      end

      def self.parse(stdout, stderr)
        JSON.parse(stdout.to_s, symbolize_names: true)
      rescue JSON::ParserError
        { output: "", error: { class: "ConsoleError", message: stderr.to_s.presence || "the ruby subprocess produced no result" } }
      end

      def self.kill(wait)
        Process.kill("KILL", wait.pid)
        wait.join
      rescue Errno::ESRCH
        nil
      end

      def self.timed_out(timeout)
        { output: "", error: { class: "Timeout", message: "execution exceeded #{timeout}s — the process was killed" } }
      end

      def self.evaluator_path
        Rails.root.join("app/domains/playground/evaluator.rb").to_s
      end
    end
  end
end
