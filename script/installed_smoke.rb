# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"
require "coupling"
require "coupling/rack/app"
require "rack/mock"

loaded_path = $LOADED_FEATURES.find { |path| path.end_with?("/coupling.rb") }
expected_gem_home = File.realpath(ENV.fetch("EXPECTED_COUPLING_GEM_HOME"))
unless File.realpath(loaded_path).start_with?("#{expected_gem_home}/")
  abort "Coupling loaded outside the isolated gem home: #{loaded_path}"
end
abort "Unexpected version: #{Coupling::VERSION}" unless Coupling::VERSION == "0.1.0"
abort "Core loading unexpectedly loaded Rails" if defined?(Rails)
abort "Core loading unexpectedly loaded ActiveSupport" if defined?(ActiveSupport)

Dir.mktmpdir("coupling-installed-smoke") do |directory|
  assets_path = File.join(directory, "assets")
  FileUtils.mkdir_p(assets_path)
  File.binwrite(File.join(assets_path, "application-A1B2C3.js"), "installed = true;\n")
  File.write(
    File.join(assets_path, "manifest.json"),
    JSON.generate("application.js" => "application-A1B2C3.js")
  )

  Coupling.reset!
  Coupling.configure do |config|
    config.assets_path = assets_path
    config.public_path = "/assets"
  end

  expected_path = "/assets/application-A1B2C3.js"
  abort "Installed manifest lookup failed" unless Coupling.manifest.path_to("application.js") == expected_path

  response = Rack::MockRequest.new(Coupling::Rack::App.new).get("/application-A1B2C3.js")
  abort "Installed Rack response failed" unless response.status == 200 && response.body == "installed = true;\n"
end

puts "Installed core/Rack smoke passed from #{loaded_path}"
