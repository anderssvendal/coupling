# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "middleman-core"
require "middleman-core/rack"
require "rack/mock"

class CouplingMiddlemanExampleSmokeTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path
  ASSETS_PATH = ROOT.join("../assets").expand_path
  MANIFEST = JSON.parse(ASSETS_PATH.join("manifest.json").read)
  OUTPUTS = MANIFEST.values.flatten.uniq.freeze

  ENV["MM_ROOT"] = ROOT.to_s
  APP = Dir.chdir(ROOT) do
    Middleman::Application.new { config[:mode] = :server }
  end
  REQUEST = Rack::MockRequest.new(Middleman::Rack.new(APP).to_app)
  Minitest.after_run { APP.shutdown! }

  def test_root_renders_every_fingerprinted_url_in_manifest_order
    response = REQUEST.get("/")

    assert_equal 200, response.status
    OUTPUTS.each { |output| assert_includes response.body, "/assets/#{output}" }
    %w[application.css application.js].each do |logical_name|
      positions = MANIFEST.fetch(logical_name).map { |output| response.body.index("/assets/#{output}") }
      assert_equal positions.sort, positions
    end
    assert_includes response.body, "alt=\"Coupling logo\""
  end

  def test_preview_server_serves_exact_fixture_bytes
    OUTPUTS.each do |output|
      response = REQUEST.get("/assets/#{output}")

      assert_equal 200, response.status
      assert_equal ASSETS_PATH.join(output).binread, response.body
    end
  end

  def test_build_contains_only_manifest_listed_assets
    OUTPUTS.each do |output|
      built = ROOT.join("build/assets", output)

      assert_predicate built, :file?
      assert_equal ASSETS_PATH.join(output).binread, built.binread
    end
    refute_predicate ROOT.join("build/assets/manifest.json"), :exist?
    refute_predicate ROOT.join("build/assets/README.md"), :exist?
  end

  def test_manifest_and_unlisted_files_are_not_served
    assert_equal 404, REQUEST.get("/assets/manifest.json").status
    assert_equal 404, REQUEST.get("/assets/README.md").status
  end

  def test_example_has_no_node_asset_pipeline
    refute ROOT.join("package.json").exist?
    refute ROOT.join("yarn.lock").exist?
    refute ROOT.join("esbuild.mjs").exist?
    refute ROOT.join("source/assets").exist?
  end
end
