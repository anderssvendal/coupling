# frozen_string_literal: true

require "test_helper"

class ConfigTest < Minitest::Test
  def test_generic_path_defaults
    config = Coupling::Config.new

    assert_equal Pathname.pwd.join("tmp/assets"), config.assets_path
    assert_equal config.assets_path.join("manifest.json"), config.manifest_path
    assert_equal "/assets", config.public_path
  end

  def test_generic_defaults_are_not_explicit_configuration
    config = Coupling::Config.new

    refute config.serve?
    refute config.assets_path_configured?
    refute config.manifest_path_configured?
    refute config.serve_configured?
  end

  def test_manifest_path_tracks_assets_path_until_explicitly_configured
    config = Coupling::Config.new
    config.assets_path = "build/assets"

    assert_equal Pathname.new("build/assets/manifest.json"), config.manifest_path

    config.manifest_path = "build/metadata/assets.json"
    config.assets_path = "other/assets"

    assert_equal Pathname.new("build/metadata/assets.json"), config.manifest_path
    assert config.assets_path_configured?
    assert config.manifest_path_configured?
  end

  def test_path_settings_accept_path_like_values
    path_like = Object.new
    path_like.define_singleton_method(:to_path) { "compiled/assets" }

    config = Coupling::Config.new
    config.assets_path = path_like

    assert_equal Pathname.new("compiled/assets"), config.assets_path
  end

  def test_public_path_is_normalized
    config = Coupling::Config.new

    config.public_path = "///compiled//assets///"
    assert_equal "/compiled/assets", config.public_path

    config.public_path = "/"
    assert_equal "/", config.public_path
  end

  def test_explicit_serve_values_are_preserved
    config = Coupling::Config.new

    config.serve = true
    assert config.serve?
    assert config.serve_configured?

    config.serve = false
    refute config.serve?
    assert config.serve_configured?
  end
end
