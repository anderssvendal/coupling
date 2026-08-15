# frozen_string_literal: true

require_relative "support/rack_app_test_case"

class RackAppAnonymousOutputsTest < RackAppTestCase
  def test_serves_anonymous_javascript_chunks
    content = "export const shared = true;\n"
    write_asset("chunks/shared-A1.js", content)
    write_manifest("" => ["chunks/shared-A1.js"])

    response = @request.get("/chunks/shared-A1.js")

    assert_equal 200, response.status
    assert_equal content, response.body
    assert_includes ["application/javascript", "text/javascript"], response["content-type"]
  end

  def test_serves_anonymous_source_maps_with_binary_fallback
    content = '{"version":3,"sources":["application.js"]}'
    write_asset("maps/application-A1.js.map", content)
    write_manifest("" => ["maps/application-A1.js.map"])

    response = @request.get("/maps/application-A1.js.map")

    assert_equal 200, response.status
    assert_equal content, response.body
    assert_equal "application/octet-stream", response["content-type"]
  end

  def test_rejects_an_unlisted_source_map
    write_asset("maps/unlisted-A1.js.map", "source map")
    write_manifest("" => ["maps/listed-B2.js.map"])

    response = @request.get("/maps/unlisted-A1.js.map")

    assert_equal 404, response.status
  end
end
