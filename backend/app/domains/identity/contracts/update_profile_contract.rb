module Identity
  module Contracts
    class UpdateProfileContract < Dry::Validation::Contract
      params do
        optional(:name).maybe(:string, max_size?: 100)
        optional(:resume).maybe(:string, max_size?: 20_000)
      end
    end
  end
end
