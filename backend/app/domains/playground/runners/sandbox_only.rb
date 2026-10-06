module Playground
  module Runners
    # Stands in for contexts that have no local runner (Go needs the sandbox toolchain).
    class SandboxOnly
      def self.call(_code, context:, timeout: nil)
        { output: "", error: { class: "ConsoleError", message: "the #{context} context is only available through the sandbox (SANDBOX_URL)" } }
      end
    end
  end
end
