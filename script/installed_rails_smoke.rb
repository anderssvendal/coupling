# frozen_string_literal: true

require "fileutils"
require "json"
require "logger"
require "tmpdir"

ENV["RAILS_ENV"] = "development"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "rack/mock"
require "coupling"

loaded_path = $LOADED_FEATURES.find { |path| path.end_with?("/coupling.rb") }
expected_gem_home = File.realpath(ENV.fetch("EXPECTED_COUPLING_GEM_HOME"))
unless File.realpath(loaded_path).start_with?("#{expected_gem_home}/")
  abort "Coupling loaded outside the isolated gem home: #{loaded_path}"
end
abort "Coupling Railtie was not discovered" unless defined?(Coupling::Railtie)

Dir.mktmpdir("coupling-installed-rails-smoke") do |directory|
  assets_path = File.join(directory, "assets")
  FileUtils.mkdir_p(assets_path)
  File.binwrite(File.join(assets_path, "application-A1B2C3.js"), "rails = true;\n")
  File.write(
    File.join(assets_path, "manifest.json"),
    JSON.generate("application.js" => "application-A1B2C3.js")
  )

  Coupling.configure do |config|
    config.assets_path = assets_path
    config.public_path = "/assets"
    config.serve = true
  end

  application_class = Class.new(Rails::Application) do
    config.root = directory
    config.eager_load = false
    config.secret_key_base = "coupling-release-smoke-secret"
    config.logger = Logger.new(File::NULL)
    config.hosts.clear
  end
  application_class.initialize!

  view = ActionView::Base.empty
  expected_paths = ["/assets/application-A1B2C3.js"]
  abort "Installed Rails helper failed" unless view.coupled_asset_paths("application.js") == expected_paths

  response = Rack::MockRequest.new(application_class.instance).get("/assets/application-A1B2C3.js")
  abort "Installed Rails serving failed" unless response.status == 200 && response.body == "rails = true;\n"
end

puts "Installed Rails smoke passed from #{loaded_path} with Rails #{Rails.version}"
