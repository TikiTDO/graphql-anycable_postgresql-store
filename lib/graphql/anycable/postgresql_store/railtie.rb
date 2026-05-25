# frozen_string_literal: true

require "rails/railtie"

module GraphQL
  module AnyCable
    module PostgreSQLStore
      class Railtie < Rails::Railtie
      end
    end
  end
end
