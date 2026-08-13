# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"
require "test_helper"

class ManifestTestCase < Minitest::Test
  def setup
    @directory = Pathname.new(Dir.mktmpdir("coupling-manifest"))
    @assets_path = @directory.join("assets")
    @assets_path.mkpath
    @manifest_path = @directory.join("manifest.json")
    @config = Coupling::Config.new
    @config.assets_path = @assets_path
    @config.manifest_path = @manifest_path
    @config.public_path = "/packs"
    @manifest = Coupling::Manifest.new(@config)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  private

  def write_manifest(document)
    @manifest_path.dirname.mkpath
    @manifest_path.write(JSON.generate(document))
  end

  def assert_invalid(document, message)
    write_manifest(document)

    error = assert_raises(Coupling::InvalidManifestError) { @manifest.entries }
    assert_includes error.message, @manifest_path.to_s
    assert_includes error.message, message if message
    error
  end
end
