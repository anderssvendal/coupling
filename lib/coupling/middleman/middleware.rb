require 'coupling/rack/app'

module Coupling::Middleman
  class Middleware < Coupling::Rack::App
    def initialize(app)
      @app = app 
    end

    def call(env)
      return @app.call(env) unless env['PATH_INFO'].starts_with?(Coupling.config.public_path)

      super
    end
  end
end
