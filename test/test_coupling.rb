# frozen_string_literal: true

require "open3"
require "rbconfig"
require "test_helper"

class TestCoupling < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil Coupling::VERSION
  end

  def test_configuration_is_available
    assert_instance_of Coupling::Config, Coupling.config
    assert_same Coupling.config, Coupling.config
  end

  def test_configure_yields_the_configuration
    yielded_config = nil

    Coupling.configure do |config|
      yielded_config = config
    end

    assert_same Coupling.config, yielded_config
  end

  def test_reset_replaces_global_configuration_and_manifest
    old_config = Coupling.config
    old_manifest = Coupling.manifest

    Coupling.reset!

    refute_same old_config, Coupling.config
    refute_same old_manifest, Coupling.manifest
  ensure
    Coupling.reset!
  end

  def test_plain_ruby_require_does_not_load_rails_or_active_support
    lib_path = File.expand_path("../lib", __dir__)
    script = <<~RUBY
      require "coupling"
      abort "Rails loaded" if defined?(Rails)
      abort "ActiveSupport loaded" if $LOADED_FEATURES.any? { |feature| feature.include?("active_support") }
      abort "listen loaded" if $LOADED_FEATURES.any? { |feature| feature.include?("listen") }
      puts Coupling::VERSION
    RUBY

    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      "-I#{lib_path}",
      "-e",
      script
    )

    assert status.success?, stderr
    assert_equal "#{Coupling::VERSION}\n", stdout
  end
end
