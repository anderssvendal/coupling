# frozen_string_literal: true

require_relative "support/manifest_test_case"

class ManifestReloadTest < ManifestTestCase
  def test_reads_and_validates_again_for_every_operation
    write_manifest("application.js" => "application-A1.js")
    assert_equal "application-A1.js", @manifest.lookup("application.js")

    write_manifest("application.js" => ["runtime-B2.js", "application-C3.js"])

    assert_equal ["runtime-B2.js", "application-C3.js"], @manifest.lookup_all("application.js")
  end

  def test_a_manifest_created_after_a_missing_lookup_is_seen_immediately
    assert_raises(Coupling::ManifestNotFoundError) { @manifest.lookup("application.js") }

    write_manifest("application.js" => "application-A1.js")

    assert_equal "application-A1.js", @manifest.lookup("application.js")
  end

  def test_manifest_construction_starts_no_listener_or_thread
    threads = Thread.list
    manifest = Coupling::Manifest.new(@config)

    assert_equal threads, Thread.list
    refute_respond_to manifest, :listener
  end
end
