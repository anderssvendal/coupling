# frozen_string_literal: true

require_relative "support/manifest_test_case"

class ManifestTest < ManifestTestCase
  def test_normalizes_scalar_and_array_values_to_ordered_arrays
    write_manifest(
      "application.js" => "application-A1.js",
      "application.css" => ["vendor-B2.css", "application-C3.css"]
    )

    assert_equal(
      {
        "application.js" => ["application-A1.js"],
        "application.css" => ["vendor-B2.css", "application-C3.css"]
      },
      @manifest.entries
    )
  end

  def test_empty_manifest_is_valid
    write_manifest({})

    assert_empty @manifest.entries
  end

  def test_named_and_anonymous_entries_coexist_without_changing_named_lookup
    write_manifest(
      "application.js" => "application-A1.js",
      "" => ["shared-B2.js", "application-A1.js.map"]
    )

    assert_equal(
      {
        "application.js" => ["application-A1.js"],
        "" => ["shared-B2.js", "application-A1.js.map"]
      },
      @manifest.entries
    )
    assert_equal ["application-A1.js"], @manifest.lookup_all("application.js")
    assert_equal "application-A1.js", @manifest.lookup("application.js")
  end

  def test_plural_and_singular_lookups_preserve_order
    write_manifest(
      "application.js" => ["runtime-A1.js", "application-B2.js"],
      "images/logo.svg" => "images/logo-C3.svg"
    )

    assert_equal ["runtime-A1.js", "application-B2.js"], @manifest.lookup_all("application.js")
    assert_equal ["/packs/runtime-A1.js", "/packs/application-B2.js"], @manifest.paths_to("application.js")
    assert_equal "images/logo-C3.svg", @manifest.lookup("images/logo.svg")
    assert_equal "/packs/images/logo-C3.svg", @manifest.path_to("images/logo.svg")
  end

  def test_public_root_does_not_add_a_duplicate_slash
    @config.public_path = "/"
    write_manifest("application.js" => "application-A1.js")

    assert_equal "/application-A1.js", @manifest.path_to("application.js")
  end

  def test_lookup_normalizes_leading_and_public_path_prefixes
    write_manifest("application.js" => "application-A1.js")

    assert_equal "application-A1.js", @manifest.lookup("/application.js")
    assert_equal "application-A1.js", @manifest.lookup("/packs/application.js")
  end

  def test_singular_lookup_rejects_multiple_outputs
    write_manifest("application.js" => ["runtime-A1.js", "application-B2.js"])

    error = assert_raises(Coupling::MultipleAssetsError) { @manifest.lookup("application.js") }
    assert_includes error.message, "application.js"
    assert_includes error.message, "2 outputs"
    assert_raises(Coupling::MultipleAssetsError) { @manifest.path_to("application.js") }
  end

  def test_unknown_logical_and_output_names_raise_asset_not_found
    write_manifest("application.js" => "application-A1.js")

    logical_error = assert_raises(Coupling::AssetNotFoundError) { @manifest.lookup_all("missing.js") }
    output_error = assert_raises(Coupling::AssetNotFoundError) { @manifest.find("missing-A1.js") }

    assert_includes logical_error.message, "missing.js"
    assert_includes output_error.message, "missing-A1.js"
  end

  def test_reverse_lookup_checks_every_output_deterministically
    write_manifest(
      "application.js" => ["runtime-A1.js", "application-B2.js"],
      "legacy.js" => "application-B2.js",
      "" => ["shared-C3.js", "application-B2.js.map"]
    )

    named_asset = @manifest.find("/packs/application-B2.js")
    anonymous_asset = @manifest.find("/packs/application-B2.js.map")

    assert_equal "application.js", named_asset.name
    assert_equal "application-B2.js", named_asset.path
    assert_equal @config, named_asset.config
    assert_equal "", anonymous_asset.name
    assert_equal "application-B2.js.map", anonymous_asset.path
    assert_equal @config, anonymous_asset.config
  end

  def test_assets_flattens_all_outputs_in_manifest_order
    write_manifest(
      "application.js" => ["runtime-A1.js", "application-B2.js"],
      "application.css" => "application-C3.css",
      "" => ["shared-D4.js", "application-B2.js.map"]
    )

    assert_equal(
      [
        ["application.js", "runtime-A1.js"],
        ["application.js", "application-B2.js"],
        ["application.css", "application-C3.css"],
        ["", "shared-D4.js"],
        ["", "application-B2.js.map"]
      ],
      @manifest.assets.map { |asset| [asset.name, asset.path] }
    )
  end
end
