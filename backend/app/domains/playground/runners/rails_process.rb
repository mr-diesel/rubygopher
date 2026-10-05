require "json"
require "timeout"

module Playground
  module Runners
    # Runs the snippet in a fork of the Puma worker: Rails is already booted there,
    # so models and ActiveRecord are available with no boot cost. The child is killed
    # after `timeout`, which is also what stops runaway loops.
    class RailsProcess
      def self.available?
        Process.respond_to?(:fork)
      end

      def self.call(code, timeout:)
        return unsupported unless available?

        reader, writer = IO.pipe

        pid = fork do
          reader.close
          reconnect_database
          writer.write(JSON.generate(Playground::Evaluator.run(code)))
          writer.close
          # exit! skips at_exit hooks — they would tear down resources the parent still uses.
          exit!(0)
        end

        writer.close
        collect(pid, reader, timeout)
      end

      def self.collect(pid, reader, timeout)
        raw = nil

        Timeout.timeout(timeout) do
          raw = reader.read # the child closes the pipe when it is done
          Process.waitpid(pid)
        end

        JSON.parse(raw.to_s, symbolize_names: true)
      rescue Timeout::Error
        terminate(pid)
        timed_out(timeout)
      rescue JSON::ParserError
        died
      ensure
        reader.close unless reader.closed?
      end

      # The child inherits the parent's open database sockets. It must never write to
      # them (that would corrupt the parent's connection), so swap in a fresh pool —
      # any query then opens its own socket. The inherited ones are left untouched and
      # simply go away with the process; closing them would send a FIN the parent owns.
      def self.reconnect_database
        ActiveRecord::Base.connection_handler.clear_active_connections!
        ActiveRecord::Base.establish_connection
      rescue StandardError # a snippet that needs no database should still run
        nil
      end

      def self.terminate(pid)
        Process.kill("KILL", pid)
        Process.waitpid(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end

      def self.timed_out(timeout)
        { output: "", error: { class: "Timeout", message: "execution exceeded #{timeout}s — the process was killed" } }
      end

      def self.died
        { output: "", error: { class: "ConsoleError", message: "the process died without returning a result" } }
      end

      def self.unsupported
        { output: "", error: { class: "ConsoleError", message: "fork is unavailable on this platform" } }
      end
    end
  end
end
