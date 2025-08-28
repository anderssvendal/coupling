require 'coupling/helper'
require 'coupling/rack/app'

module Coupling
  class Railtie < Rails::Railtie
    initializer "coupling.clear" do |app|
      next unless Rails.env.development?

      ActiveSupport.on_load(:action_controller) do
        ActionDispatch::Callbacks.before do
          Coupling.clear_manifest
        end
      end
    end

    initializer 'coupling.helper' do
      ActiveSupport.on_load(:action_view) do
        include Helper
     end
    end

    config.after_initialize do |app|
      next unless Coupling.config.serve?

      app.routes.prepend do
        mount Rack::App.new, at: Coupling.config.public_path
      end
    end
  end
end
