# frozen_string_literal: true

begin
  require "middleman-core"
  require "middleman-core/builder"
  require "middleman-core/profiling"
  require "middleman-core/rack"
rescue LoadError
  # Middleman integration tests run only inside the Middleman Appraisal dependency sets.
else
  require "test_helper"
  require "coupling/middleman"
  require_relative "support/middleman_test_case"

  class MiddlemanExtensionConfigurationTest < MiddlemanTestCase
    def test_registers_the_extension_and_applies_server_defaults
      write_config("activate :coupling")
      build_app(:server)

      assert_equal Coupling::Middleman::Extension, ::Middleman::Extensions.registered.fetch(:coupling)
      assert_equal @site.join("tmp/assets"), Coupling.config.assets_path
      assert Coupling.config.serve?
    end

    def test_expands_relative_options_from_the_project_root
      compiled = copy_assets_into_site
      write_config <<~RUBY
        activate :coupling,
                 assets_path: "compiled",
                 manifest_path: "compiled/manifest.json",
                 public_path: "/compiled-assets",
                 serve: false
      RUBY

      build_app(:server)

      assert_configured_options(compiled)
    end

    def test_server_mount_serves_only_the_exact_public_path
      write_config(activation)
      request = rack_request(build_app(:server))

      assert_served_asset(request, "application-D4E5F6.js")
      assert_head_asset(request, "application-D4E5F6.js")
      assert_equal 404, request.get("/assets/unknown.js").status
      assert_equal 404, request.get("/assets/manifest.json").status
      refute_equal "Not Found\n", request.get("/assets-extra/application-D4E5F6.js").body
    end

    private

    def copy_assets_into_site
      compiled = @site.join("compiled")
      FileUtils.mkdir_p(compiled)
      FileUtils.cp_r(@assets.join("."), compiled)
      compiled
    end

    def assert_configured_options(compiled)
      expected = [compiled.expand_path, compiled.join("manifest.json").expand_path, "/compiled-assets", false]
      actual = [Coupling.config.assets_path, Coupling.config.manifest_path,
                Coupling.config.public_path, Coupling.config.serve?]
      assert_equal expected, actual
    end

    def rack_request(app)
      ::Rack::MockRequest.new(::Middleman::Rack.new(app).to_app)
    end

    def assert_served_asset(request, output)
      response = request.get("/assets/#{output}")
      assert_equal 200, response.status
      assert_equal @assets.join(output).binread, response.body
    end

    def assert_head_asset(request, output)
      get = request.get("/assets/#{output}")
      head = request.head("/assets/#{output}")
      assert_equal [200, "", get["content-length"]], [head.status, head.body, head["content-length"]]
    end
  end

  class MiddlemanBuildTest < MiddlemanTestCase
    def test_copies_current_manifest_outputs_after_cleaning
      write_config(activation)
      stale = write_stale_asset

      success, reporter = run_build(clean: true)

      assert_clean_build(success, stale, reporter)
      assert_generated_html
    end

    def test_overwrites_outputs_when_cleaning_is_disabled
      write_config(activation)
      destination = @site.join("build/assets/application-D4E5F6.js")
      FileUtils.mkdir_p(destination.dirname)
      destination.write("old")

      success, = run_build(clean: false)

      assert success
      assert_equal @assets.join("application-D4E5F6.js").binread, destination.binread
    end

    private

    def write_stale_asset
      stale = @site.join("build/assets/stale.js")
      FileUtils.mkdir_p(stale.dirname)
      stale.write("stale")
      stale
    end

    def assert_clean_build(success, stale, reporter)
      assert success
      refute stale.exist?
      assert_copied_outputs
      refute_predicate @site.join("build/assets/manifest.json"), :exist?
      copies = reporter.events.count { |event| event.first == :copy_asset }
      assert_equal outputs.length, copies
    end

    def assert_copied_outputs
      outputs.each do |output|
        destination = @site.join("build/assets", output)
        assert_predicate destination, :file?
        assert_equal @assets.join(output).binread, destination.binread
      end
    end

    def assert_generated_html
      html = @site.join("build/index.html").read
      assert_operator html.index("styles/reset-A1B2C3.css"), :<, html.index("application-D4E5F6.css")
      assert_includes html, "/assets/application-D4E5F6.js"
      assert_includes html, "/assets/images/logo-M4N5P6.svg"
    end
  end
end
