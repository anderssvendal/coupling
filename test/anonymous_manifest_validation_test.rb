# frozen_string_literal: true

require_relative "support/manifest_test_case"

class AnonymousManifestValidationTest < ManifestTestCase
  def test_accepts_a_literal_empty_name_with_a_non_empty_array
    write_manifest("" => ["shared-A1.js", "application-B2.js.map"])

    assert_equal(
      { "" => ["shared-A1.js", "application-B2.js.map"] },
      @manifest.entries
    )
  end

  def test_rejects_scalar_empty_and_malformed_values
    invalid_values = [
      "shared-A1.js",
      "",
      [],
      [""],
      ["shared-A1.js", ""],
      ["shared-A1.js", 1],
      nil,
      1,
      true,
      { "file" => "shared-A1.js" }
    ]

    invalid_values.each do |value|
      assert_invalid({ "" => value }, "anonymous entry")
    end
  end

  def test_rejects_duplicate_outputs
    assert_invalid(
      { "" => ["shared-A1.js", "shared-A1.js"] },
      "duplicate outputs"
    )
  end

  def test_rejects_unsafe_output_paths
    unsafe_outputs.each do |output|
      assert_invalid({ "" => ["safe.js", output] }, nil)
    end
  end

  def test_rejects_the_configured_manifest_as_an_output
    @config.manifest_path = @assets_path.join("metadata.json")
    @manifest_path = @config.manifest_path

    assert_invalid({ "" => ["metadata.json"] }, "configured manifest")
  end

  def test_rejects_an_existing_symlink_escape
    outside = @directory.join("outside.js")
    outside.write("secret")
    File.symlink(outside, @assets_path.join("linked.js"))

    assert_invalid({ "" => ["linked.js"] }, "symlink escape")
  rescue NotImplementedError, Errno::EACCES
    skip "symlinks are not available on this platform"
  end

  def test_non_empty_logical_name_that_normalizes_to_empty_remains_invalid
    assert_invalid({ "/packs" => "asset.js" }, "normalizes to an empty string")
  end

  private

  def unsafe_outputs
    [
      "/absolute.js",
      "C:/absolute.js",
      "../outside.js",
      "nested/../outside.js",
      "./asset.js",
      "nested/./asset.js",
      "nested//asset.js",
      "nested/asset.js/",
      "nested\\asset.js",
      "null\0byte.js"
    ]
  end
end
