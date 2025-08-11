require 'coupling/helper'
require 'coupling/rack/app'

module Coupling
  class Railtie < Rails::Railtie
    initializer 'coupling.helper' do
      ActiveSupport.on_load(:action_view) do
        include Helper
      end
    end

    config.after_initialize do |app|
      app.routes.prepend do
        mount Rack::App.new, at: Coupling.config.public_path
      end
    end
  end
end
