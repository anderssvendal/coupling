require 'coupling/manifest'

module Coupling::Rack
  class App
    def call(env)
      req =  Rack::Request.new(env)
      asset = Coupling::Manifest.find(req.path)

      [
        200,
        {
          'Content-Type' => asset.content_type
        },
        [
          asset.read
        ]
      ]
    end
  end
end
