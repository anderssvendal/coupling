# frozen_string_literal: true

require "coupling/helper"
require "coupling/rack/app"

module Coupling
  class Railtie < Rails::Railtie
    initializer "coupling.defaults", before: :load_config_initializers do |app|
      Coupling.config.apply_rails_defaults(root: app.root, development: Rails.env.development?)
    end

    initializer "coupling.helper" do
      ActiveSupport.on_load(:action_view) do
        include Coupling::Helper
      end
    end

    config.after_initialize do |app|
      next unless Coupling.config.serve?

      app.routes.prepend do
        mount Coupling::Rack::App.new, at: Coupling.config.public_path
      end
    end
  end
end
