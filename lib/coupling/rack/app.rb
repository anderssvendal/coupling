# frozen_string_literal: true

require "coupling/manifest"

module Coupling
  module Rack
    class App
      def call(env)
        req = Rack::Request.new(env)
        asset = Coupling.manifest.find(req.path)

        [
          200,
          {
            "Content-Type" => asset.content_type
          },
          [
            asset.read
          ]
        ]
      end
    end
  end
end
