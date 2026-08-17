# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "rack/mock"
require_relative "../config/environment"

class CouplingRailsExampleSmokeTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path
  ASSETS_PATH = ROOT.join("coupled_assets")
  MANIFEST = JSON.parse(ASSETS_PATH.join("manifest.json").read)
  OUTPUTS = MANIFEST.values.flatten.freeze

  def setup
    @request = Rack::MockRequest.new(Rails.application)
  end

  def test_root_renders_every_fingerprinted_url_in_manifest_order
    response = get("/")

    assert_equal 200, response.status
    OUTPUTS.each do |output|
      assert_includes response.body, "/coupled-assets/#{output}"
    end
    %w[application.css application.js].each do |logical_name|
      positions = MANIFEST.fetch(logical_name).map do |output|
        response.body.index("/coupled-assets/#{output}")
      end
      assert_equal positions.sort, positions
    end
    assert_includes response.body, "media=\"screen\""
    assert_includes response.body, "defer=\"defer\""
    assert_includes response.body, "alt=\"Coupling logo\""
  end

  def test_manifest_is_valid_and_every_output_exists
    expected = MANIFEST.transform_values { |outputs| Array(outputs) }

    assert_equal expected, Coupling.manifest.entries
    OUTPUTS.each do |output|
      assert_predicate ASSETS_PATH.join(output), :file?
      assert_equal ASSETS_PATH.join(output).binread, Coupling.manifest.find(output).read
    end
  end

  def test_example_has_no_node_asset_pipeline
    refute ROOT.join("package.json").exist?
    refute ROOT.join("yarn.lock").exist?
    refute ROOT.join("esbuild.mjs").exist?
    refute ROOT.join("app/assets").exist?
  end

  def test_development_serves_exact_fixture_bytes
    skip unless Rails.env.development?

    expected_types = {
      ".css" => "text/css",
      ".js" => "text/javascript",
      ".svg" => "image/svg+xml"
    }

    OUTPUTS.each do |output|
      response = get("/coupled-assets/#{output}")

      assert_equal 200, response.status
      assert_equal ASSETS_PATH.join(output).binread, response.body
      assert_equal expected_types.fetch(File.extname(output)), response["content-type"]
      assert_equal "no-cache", response["cache-control"]
    end
  end

  def test_development_head_and_404_responses_do_not_disclose_manifest
    skip unless Rails.env.development?

    output = OUTPUTS.first
    get_response = get("/coupled-assets/#{output}")
    head_response = head("/coupled-assets/#{output}")

    assert_equal 200, head_response.status
    assert_equal get_response["content-type"], head_response["content-type"]
    assert_equal get_response["content-length"], head_response["content-length"]
    assert_empty head_response.body
    assert_equal 404, get("/coupled-assets/unknown.js").status
    assert_equal 404, get("/coupled-assets/manifest.json").status
    refute_includes get("/coupled-assets/manifest.json").body, MANIFEST.keys.first
  end

  def test_non_development_environment_generates_urls_without_serving_files
    skip if Rails.env.development?

    refute Coupling.config.serve?
    OUTPUTS.each do |output|
      refute_equal 200, get("/coupled-assets/#{output}").status
    end
  end

  private

  def get(path)
    @request.get(path, "HTTP_HOST" => "localhost")
  end

  def head(path)
    @request.head(path, "HTTP_HOST" => "localhost")
  end
end
