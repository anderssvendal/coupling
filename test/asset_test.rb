# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "test_helper"

class AssetTest < Minitest::Test
  def setup
    @directory = Pathname.new(Dir.mktmpdir("coupling-asset"))
    @assets_path = @directory.join("assets")
    @assets_path.mkpath
    @config = Coupling::Config.new
    @config.assets_path = @assets_path
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_absolute_path_resolves_beneath_configured_assets_path
    asset = Coupling::Asset.new("application.js", "nested/application-A1.js", config: @config)

    assert_equal @assets_path.join("nested/application-A1.js"), asset.absolute_path
  end

  def test_absolute_path_rejects_escape
    asset = Coupling::Asset.new("application.js", "../outside.js", config: @config)

    assert_raises(ArgumentError) { asset.absolute_path }
  end

  def test_absolute_path_rejects_an_existing_symlink_escape
    outside = @directory.join("outside.js")
    outside.write("secret")
    File.symlink(outside, @assets_path.join("linked.js"))
    asset = Coupling::Asset.new("application.js", "linked.js", config: @config)

    assert_raises(ArgumentError) { asset.absolute_path }
  rescue NotImplementedError, Errno::EACCES
    skip "symlinks are not available on this platform"
  end

  def test_read_preserves_binary_bytes
    bytes = "\x00\xFF\x80coupling".b
    @assets_path.join("asset.bin").binwrite(bytes)
    asset = Coupling::Asset.new("asset.bin", config: @config)

    result = asset.read

    assert_equal Encoding::ASCII_8BIT, result.encoding
    assert_equal bytes, result
  end
end
