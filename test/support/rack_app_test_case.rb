# frozen_string_literal: true

require "rack/builder"
require "rack/mock"
require "coupling/rack/app"
require_relative "manifest_test_case"

class RackAppTestCase < ManifestTestCase
  def setup
    super
    Coupling.reset!
    Coupling.configure do |config|
      config.assets_path = @assets_path
      config.manifest_path = @manifest_path
      config.public_path = "/assets"
    end
    @app = Coupling::Rack::App.new
    @request = ::Rack::MockRequest.new(@app)
  end

  def teardown
    Coupling.reset!
    super
  end

  private

  def write_asset(path, content)
    asset_path = @assets_path.join(path)
    asset_path.dirname.mkpath
    asset_path.binwrite(content)
  end

  def request_with_path(path)
    env = ::Rack::MockRequest.env_for("/", "PATH_INFO" => path)
    status, headers, body = @app.call(env)
    content = body.each_with_object(String.new) { |part, result| result << part }
    ::Rack::MockResponse.new(status, headers, content)
  end
end
