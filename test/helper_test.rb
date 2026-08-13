# frozen_string_literal: true

begin
  require "action_view"
rescue LoadError
  # Rails integration tests run only inside the Appraisal dependency sets.
else
  require "fileutils"
  require "tmpdir"
  require "test_helper"
  require "coupling/helper"

  class HelperTest < Minitest::Test
    def setup
      @directory = Dir.mktmpdir("coupling-helper-test")
      Coupling.reset!
      Coupling.configure do |config|
        config.assets_path = @directory
        config.public_path = "/compiled"
      end
      write_manifest(
        "application.css" => ["runtime-A.css", "application-B.css"],
        "explicit.css" => "explicit-C.css",
        "application.js" => ["runtime-A.js", "application-B.js"],
        "classic.js" => "classic-C.js",
        "images/logo.svg" => "images/logo-D.svg"
      )
      @view = Class.new do
        include ActionView::Helpers
        include Coupling::Helper
      end.new
    end

    def teardown
      Coupling.reset!
      FileUtils.remove_entry(@directory)
    end

    def test_asset_paths_preserve_manifest_order
      assert_equal ["/compiled/runtime-A.css", "/compiled/application-B.css"],
                   @view.coupled_asset_paths("application.css")
      assert_equal "/compiled/images/logo-D.svg", @view.coupled_asset_path("images/logo.svg")
    end

    def test_stylesheet_helper_infers_extension_and_forwards_options
      html = @view.coupled_stylesheet_link_tag("application", media: "screen", data: { theme: "main" })

      assert_operator html.index("runtime-A.css"), :<, html.index("application-B.css")
      assert_equal 2, html.scan("<link").length
      assert_equal 2, html.scan('media="screen"').length
      assert_equal 2, html.scan('data-theme="main"').length

      assert_includes @view.coupled_stylesheet_link_tag("explicit.css"), "/compiled/explicit-C.css"
    end

    def test_javascript_helper_infers_extension_and_keeps_classic_default
      html = @view.coupled_javascript_include_tag("application", defer: true)

      assert_operator html.index("runtime-A.js"), :<, html.index("application-B.js")
      assert_equal 2, html.scan("<script").length
      assert_equal 2, html.scan(/defer(?:="defer")?/).length
      refute_includes html, 'type="module"'

      module_html = @view.coupled_javascript_include_tag("classic.js", type: "module")
      assert_includes module_html, 'type="module"'
      assert_includes module_html, "/compiled/classic-C.js"
    end

    def test_image_helper_forwards_options
      html = @view.coupled_image_tag("images/logo.svg", alt: "Logo", class: "brand")

      assert_includes html, 'src="/compiled/images/logo-D.svg"'
      assert_includes html, 'alt="Logo"'
      assert_includes html, 'class="brand"'
    end

    def test_helpers_are_prefixed_instance_methods_only
      assert @view.respond_to?(:coupled_asset_path)
      assert @view.respond_to?(:asset_path)
      refute_equal Coupling::Helper, @view.method(:asset_path).owner
      refute Coupling::Helper.respond_to?(:coupled_asset_path)
    end

    private

    def write_manifest(entries)
      File.write(File.join(@directory, "manifest.json"), JSON.generate(entries))
    end
  end
end
