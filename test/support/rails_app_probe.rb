# frozen_string_literal: true

require "json"
require "logger"

ENV["RAILS_ENV"] = ENV.fetch("COUPLING_RAILS_ENV")

require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "rack/mock"
require "coupling"

abort "Coupling Railtie was not discovered" unless defined?(Coupling::Railtie)

if ENV["COUPLING_EXPLICIT"] == "true"
  Coupling.configure do |config|
    config.assets_path = ENV.fetch("COUPLING_ASSETS_PATH")
    config.manifest_path = ENV.fetch("COUPLING_MANIFEST_PATH")
    config.public_path = ENV.fetch("COUPLING_PUBLIC_PATH")
    config.serve = ENV.fetch("COUPLING_SERVE") == "true"
  end
end

class CouplingProbeApplication < Rails::Application
  config.root = ENV.fetch("COUPLING_ROOT")
  config.eager_load = false
  config.secret_key_base = "coupling-probe-secret-key-base"
  config.logger = Logger.new(File::NULL)
  config.hosts.clear
end

CouplingProbeApplication.initialize!
application = CouplingProbeApplication.instance
public_path = Coupling.config.public_path
output = ENV.fetch("COUPLING_OUTPUT")
request_status = nil
request_body = nil

begin
  response = Rack::MockRequest.new(application).get("#{public_path}/#{output}")
  request_status = response.status
  request_body = response.body
rescue ActionController::RoutingError
  request_status = 404
end

route_paths = application.routes.routes.map { |route| route.path.spec.to_s }
view = ActionView::Base.empty
paths_before = view.coupled_asset_paths("application.js")
File.write(
  Coupling.config.manifest_path,
  JSON.generate("application.js" => ENV.fetch("COUPLING_REWRITTEN_OUTPUT"))
)
paths_after = view.coupled_asset_paths("application.js")

result = {
  assets_path: Coupling.config.assets_path.to_s,
  manifest_path: Coupling.config.manifest_path.to_s,
  public_path: public_path,
  serve: Coupling.config.serve?,
  assets_path_configured: Coupling.config.assets_path_configured?,
  serve_configured: Coupling.config.serve_configured?,
  helper_included: ActionView::Base.ancestors.include?(Coupling::Helper),
  mounted: route_paths.any? { |path| path.start_with?(public_path) },
  request_status: request_status,
  request_body: request_body,
  paths_before: paths_before,
  paths_after: paths_after
}

puts "COUPLING_PROBE=#{JSON.generate(result)}"
