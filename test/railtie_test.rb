# frozen_string_literal: true

if Gem::Specification.find_all_by_name("rails").any?
  require "fileutils"
  require "tmpdir"
  require "test_helper"
  require "support/rails_probe"

  class RailtieTest < Minitest::Test
    def setup
      @root = Dir.mktmpdir("coupling-railtie-test")
      @probe = RailsProbe.new(@root)
    end

    def teardown
      FileUtils.remove_entry(@root)
    end

    def test_development_defaults_and_mounts_the_rack_app
      result = @probe.call("development")

      assert_equal(
        {
          "assets_path" => File.join(@root, "tmp/assets"),
          "manifest_path" => File.join(@root, "tmp/assets/manifest.json"),
          "public_path" => "/assets",
          "serve" => true,
          "assets_path_configured" => false,
          "serve_configured" => false,
          "helper_included" => true,
          "mounted" => true,
          "request_status" => 200,
          "request_body" => "initial asset",
          "paths_before" => ["/assets/application-A.js"],
          "paths_after" => ["/assets/application-B.js"]
        },
        result
      )
    end

    def test_non_development_default_does_not_mount_the_rack_app
      result = @probe.call("test")

      refute result.fetch("serve")
      refute result.fetch("mounted")
      refute_equal 200, result.fetch("request_status")
      assert result.fetch("helper_included")
    end

    def test_explicit_configuration_survives_initialization
      assets_path = File.join(@root, "custom/assets")
      manifest_path = File.join(@root, "metadata/custom-manifest.json")
      result = @probe.call(
        "development",
        explicit: true,
        assets_path: assets_path,
        manifest_path: manifest_path,
        public_path: "///compiled//assets///"
      )
      expected = {
        "assets_path" => assets_path,
        "manifest_path" => manifest_path,
        "public_path" => "/compiled/assets",
        "serve" => false,
        "assets_path_configured" => true,
        "serve_configured" => true,
        "mounted" => false,
        "paths_before" => ["/compiled/assets/application-A.js"]
      }

      assert_equal expected, result.slice(*expected.keys)
    end

    def test_explicit_serving_can_be_enabled_outside_development
      result = @probe.call("production", explicit: true, serve: true)

      assert result.fetch("serve")
      assert result.fetch("mounted")
      assert_equal 200, result.fetch("request_status")
      assert_equal "initial asset", result.fetch("request_body")
    end
  end
end
