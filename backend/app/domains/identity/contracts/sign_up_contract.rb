module Identity
  module Contracts
    class SignUpContract < Dry::Validation::Contract
      params do
        required(:email).filled(:string)
        required(:password).filled(:string, min_size?: 8)
        optional(:name).maybe(:string)
      end
    end
  end
end
