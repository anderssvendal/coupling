# frozen_string_literal: true

require_relative "support/rack_app_test_case"

class RackAppSecurityTest < RackAppTestCase
  def test_unsafe_request_paths_do_not_disclose_files
    outside = @directory.join("outside.txt")
    outside.write("secret outside content")
    write_manifest("application.js" => "application-A1.js")

    ["/../outside.txt", "/%2e%2e/outside.txt", "//etc/passwd", "/nested/./application-A1.js"].each do |path|
      response = request_with_path(path)

      refute_equal 200, response.status
      refute_includes response.body, outside.read
    end
  end

  def test_default_and_configured_manifest_names_are_never_served
    @manifest_path = @directory.join("private/metadata.json")
    Coupling.config.manifest_path = @manifest_path
    write_asset("manifest.json", "default manifest secret")
    write_asset("nested/metadata.json", "configured manifest secret")
    write_manifest(
      "default-metadata" => "manifest.json",
      "custom-metadata" => "nested/metadata.json"
    )

    default_response = @request.get("/manifest.json")
    configured_response = @request.get("/nested/metadata.json")

    assert_equal 404, default_response.status
    assert_equal 404, configured_response.status
    refute_includes default_response.body, "default manifest secret"
    refute_includes configured_response.body, "configured manifest secret"
  end

  def test_existing_symlink_escape_is_rejected_without_reading_outside_bytes
    outside = @directory.join("outside.js")
    outside.write("secret outside content")
    File.symlink(outside, @assets_path.join("linked.js"))
    write_manifest("application.js" => "linked.js")

    error = assert_raises(Coupling::InvalidManifestError) { @request.get("/linked.js") }

    refute_includes error.message, outside.read
  rescue NotImplementedError, Errno::EACCES
    skip "symlinks are not available on this platform"
  end

  def test_containment_is_rechecked_immediately_before_reading
    outside = @directory.join("outside.js")
    outside.write("secret outside content")
    asset_path = @assets_path.join("application-A1.js")
    asset_path.write("safe content")
    write_manifest("application.js" => "application-A1.js")
    replace_asset_with_symlink_during_find(asset_path, outside)

    assert_raises(ArgumentError) { @request.get("/application-A1.js") }
  rescue NotImplementedError, Errno::EACCES
    skip "symlinks are not available on this platform"
  end

  def test_missing_and_invalid_manifest_errors_propagate
    assert_raises(Coupling::ManifestNotFoundError) { @request.get("/application-A1.js") }

    @manifest_path.write("not json")

    assert_raises(Coupling::InvalidManifestError) { @request.get("/application-A1.js") }
  end

  private

  def replace_asset_with_symlink_during_find(asset_path, outside)
    manifest = Coupling.manifest
    manifest.define_singleton_method(:find) do |name|
      asset = super(name)
      asset_path.delete
      File.symlink(outside, asset_path)
      asset
    end
  end
end
