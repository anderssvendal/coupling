# frozen_string_literal: true

require_relative "support/rack_app_test_case"

class RackAppAnonymousOutputsTest < RackAppTestCase
  def test_serves_anonymous_outputs_but_rejects_unlisted_files
    write_asset("chunks/shared-A1.js", "chunk")
    write_asset("maps/application-A1.js.map", "map")
    write_asset("maps/unlisted-B2.js.map", "map")
    write_manifest("" => ["chunks/shared-A1.js", "maps/application-A1.js.map"])

    chunk, map, unlisted = %w[
      /chunks/shared-A1.js
      /maps/application-A1.js.map
      /maps/unlisted-B2.js.map
    ].map { |path| @request.get(path) }

    assert_equal [200, 200, 404], [chunk.status, map.status, unlisted.status]
    assert_includes ["application/javascript", "text/javascript"], chunk["content-type"]
    assert_equal "application/octet-stream", map["content-type"]
  end
end
