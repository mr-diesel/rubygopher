module Tracker
  module Types
    include Dry.Types()

    # Inside this module `String` is the dry type, hence `::String` for the Ruby class.
    StrippedString = Types::String.constructor { |value| value.is_a?(::String) ? value.strip : value }
  end
end
