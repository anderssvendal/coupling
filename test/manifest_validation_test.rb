# frozen_string_literal: true

require_relative "support/manifest_test_case"

class ManifestValidationTest < ManifestTestCase
  def test_missing_manifest_has_an_actionable_error_and_preserves_cause
    error = assert_raises(Coupling::ManifestNotFoundError) { @manifest.entries }

    assert_includes error.message, @manifest_path.to_s
    assert_includes error.message, "Build or deploy"
    assert_instance_of Errno::ENOENT, error.cause
  end

  def test_malformed_json_has_manifest_context_and_preserves_cause
    @manifest_path.write("{")

    error = assert_raises(Coupling::InvalidManifestError) { @manifest.entries }

    assert_includes error.message, @manifest_path.to_s
    assert_instance_of JSON::ParserError, error.cause
  end

  def test_rejects_non_object_top_levels
    [[], "asset.js", 1, true, nil].each do |document|
      assert_invalid(document, "top level")
    end
  end

  def test_rejects_invalid_value_contracts
    invalid_values = ["", [], [""], ["valid.js", ""], ["valid.js", 1], nil, 1, true, { "file" => "asset.js" }]

    invalid_values.each do |value|
      assert_invalid({ "application.js" => value }, "must map")
    end
  end

  def test_rejects_duplicate_outputs_within_one_key
    assert_invalid(
      { "application.js" => ["application-A1.js", "application-A1.js"] },
      "duplicate outputs"
    )
  end

  def test_allows_an_output_to_be_shared_by_different_keys
    write_manifest(
      "application.js" => "shared-A1.js",
      "admin.js" => "shared-A1.js"
    )

    assert_equal ["shared-A1.js"], @manifest.lookup_all("application.js")
    assert_equal ["shared-A1.js"], @manifest.lookup_all("admin.js")
  end

  def test_rejects_unsafe_output_paths_in_scalar_and_array_values
    unsafe_outputs.each do |output|
      assert_invalid({ "scalar.js" => output }, nil)
      assert_invalid({ "array.js" => ["safe.js", output] }, nil)
    end
  end

  def test_rejects_the_configured_manifest_as_an_output
    @config.manifest_path = @assets_path.join("metadata.json")
    @manifest_path = @config.manifest_path

    assert_invalid({ "metadata.json" => "metadata.json" }, "configured manifest")
  end

  def test_rejects_an_existing_symlink_escape
    outside = @directory.join("outside.js")
    outside.write("secret")
    File.symlink(outside, @assets_path.join("linked.js"))

    assert_invalid({ "application.js" => "linked.js" }, "symlink escape")
  rescue NotImplementedError, Errno::EACCES
    skip "symlinks are not available on this platform"
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
