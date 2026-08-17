require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module Demo
  class Application < Rails::Application
    config.load_defaults 7.1
    config.secret_key_base = "coupling-rails-example-only-not-for-production"
    config.generators.system_tests = nil
  end
end
