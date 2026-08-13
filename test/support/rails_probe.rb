# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"

class RailsProbe
  def initialize(root)
    @root = root
  end

  def call(environment, **settings)
    settings = default_settings.merge(settings).merge(environment: environment)
    prepare_assets(settings)
    stdout, stderr, status = execute(probe_environment(settings))
    raise "Rails probe failed:\n#{stdout}\n#{stderr}" unless status.success?

    line = stdout.lines.find { |output| output.start_with?("COUPLING_PROBE=") }
    raise "Rails probe emitted no result:\n#{stdout}\n#{stderr}" unless line

    JSON.parse(line.delete_prefix("COUPLING_PROBE="))
  end

  private

  attr_reader :root

  def default_settings
    assets_path = File.join(root, "tmp/assets")
    {
      explicit: false,
      assets_path: assets_path,
      manifest_path: File.join(assets_path, "manifest.json"),
      public_path: "/assets",
      serve: false,
      output: "application-A.js"
    }
  end

  def prepare_assets(settings)
    FileUtils.mkdir_p(settings.fetch(:assets_path))
    FileUtils.mkdir_p(File.dirname(settings.fetch(:manifest_path)))
    File.write(File.join(settings.fetch(:assets_path), settings.fetch(:output)), "initial asset")
    File.write(settings.fetch(:manifest_path), JSON.generate("application.js" => settings.fetch(:output)))
  end

  def probe_environment(settings)
    settings.to_h do |key, value|
      ["COUPLING_#{key.to_s.upcase}", value.to_s]
    end.merge(
      "COUPLING_ROOT" => root,
      "COUPLING_RAILS_ENV" => settings.fetch(:environment),
      "COUPLING_REWRITTEN_OUTPUT" => "application-B.js"
    )
  end

  def execute(environment)
    lib_path = File.expand_path("../../lib", __dir__)
    probe_path = File.expand_path("rails_app_probe.rb", __dir__)
    Open3.capture3(environment, RbConfig.ruby, "-I#{lib_path}", probe_path)
  end
end
