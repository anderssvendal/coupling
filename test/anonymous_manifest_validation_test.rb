# frozen_string_literal: true

require_relative "support/manifest_test_case"

class AnonymousManifestValidationTest < ManifestTestCase
  def test_accepts_a_non_empty_array_under_the_empty_key
    write_manifest("" => ["shared-A1.js", "application-B2.js.map"])

    assert_equal ["shared-A1.js", "application-B2.js.map"], @manifest.entries.fetch("")
  end

  def test_rejects_invalid_values
    ["shared-A1.js", [], [""], [1]].each do |value|
      assert_invalid({ "" => value }, "anonymous entry")
    end
  end

  def test_rejects_duplicate_outputs
    assert_invalid({ "" => ["shared-A1.js", "shared-A1.js"] }, "duplicate outputs")
  end

  def test_applies_output_path_validation
    assert_invalid({ "" => ["../shared-A1.js"] }, "unsafe output path")
  end

  def test_non_empty_name_that_normalizes_to_empty_remains_invalid
    assert_invalid({ "/packs" => "asset.js" }, "normalizes to an empty string")
  end
end
