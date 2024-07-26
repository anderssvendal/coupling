require 'coupling/helper'
require 'coupling/middleman/middleware'

module Coupling::Middleman
  class Extension < ::Middleman::Extension
    option :root

    def initialize(app, options_hash={}, &block)
      super

      # puts 'config Coupling'
      # puts options
      Coupling.configure do |config|
        config.root = options[:root].presence || app.root_path.join('tmp', 'assets')
        config.public_path = options[:public_path] || '/assets'
      end

      app.use(Coupling::Middleman::Middleware)
    end

    helpers do
      include Coupling::Helper
    end


    def after_build
      # puts "copy assets!"
      # binding.irb
    end
  end
end
