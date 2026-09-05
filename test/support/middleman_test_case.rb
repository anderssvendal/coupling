# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

module MiddlemanFixture
  Reporter = Struct.new(:events) do
    def say_status(status, path, color)
      events << [status, path.to_s, color]
    end
  end

  def setup
    @original_mm_root = ENV.fetch("MM_ROOT", nil)
    @directory = Dir.mktmpdir("coupling-middleman-test")
    @site = Pathname.new(@directory).join("site")
    @assets = Pathname.new(@directory).join("assets")
    @apps = []
    FileUtils.mkdir_p([@site.join("source"), @assets.join("styles"), @assets.join("images")])
    write_assets
    write_site
  end

  def teardown
    @apps.each(&:shutdown!)
    Coupling.reset!
    ENV["MM_ROOT"] = @original_mm_root
    FileUtils.remove_entry(@directory)
  end

  private

  def build_app(mode)
    Coupling.reset!
    ENV["MM_ROOT"] = @site.to_s
    app = Dir.chdir(@site) do
      ::Middleman::Application.new { config[:mode] = mode }
    end
    @apps << app
    app
  end

  def run_build(clean:)
    app = build_app(:build)
    reporter = Reporter.new([])
    success = Dir.chdir(@site) do
      builder = ::Middleman::Builder.new(app, glob: nil, clean: clean, parallel: false)
      builder.thor = reporter
      builder.run!
    end
    [success, reporter]
  end

  def write_config(contents)
    @site.join("config.rb").write(<<~RUBY)
      require "coupling/middleman"
      #{contents}
    RUBY
  end

  def activation
    <<~RUBY
      activate :coupling,
               assets_path: #{@assets.to_s.inspect},
               public_path: "/assets"
    RUBY
  end

  def write_site
    @site.join("source/index.html.erb").write(<<~ERB)
      <%= coupled_stylesheet_link_tag "application" %>
      <%= coupled_javascript_include_tag "application", defer: true %>
      <%= coupled_image_tag "images/logo.svg", alt: "Logo" %>
    ERB
  end

  def write_assets
    fixture_files.each do |path, contents|
      destination = @assets.join(path)
      FileUtils.mkdir_p(destination.dirname)
      destination.binwrite(contents)
    end
    @assets.join("manifest.json").write(JSON.generate(manifest_entries))
  end

  def fixture_files
    {
      "styles/reset-A1B2C3.css" => "* { box-sizing: border-box; }\n",
      "application-D4E5F6.css" => "body { color: navy; }\n",
      "application-D4E5F6.js" => "console.log('coupling');\n",
      "images/logo-M4N5P6.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>\n",
      "application-D4E5F6.js.map" => "{}\n"
    }
  end

  def manifest_entries
    {
      "application.css" => ["styles/reset-A1B2C3.css", "application-D4E5F6.css"],
      "application.js" => "application-D4E5F6.js",
      "images/logo.svg" => "images/logo-M4N5P6.svg",
      "" => ["application-D4E5F6.js.map"]
    }
  end

  def outputs
    manifest_entries.values.flatten.uniq
  end
end

class MiddlemanTestCase < Minitest::Test
  include MiddlemanFixture
end
