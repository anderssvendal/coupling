# frozen_string_literal: true

require "rack/lint"
require_relative "support/rack_app_test_case"

class RackAppTest < RackAppTestCase
  def test_get_serves_a_listed_nested_asset_with_expected_headers
    content = "console.log('coupling');\n".b
    write_asset("nested/application-A1.js", content)
    write_manifest("application.js" => "nested/application-A1.js")

    response = @request.get("/nested/application-A1.js")

    assert_equal 200, response.status
    assert_equal content, response.body
    assert_includes ["application/javascript", "text/javascript"], response["content-type"]
    assert_equal content.bytesize.to_s, response["content-length"]
    assert_equal "no-cache", response["cache-control"]
  end

  def test_head_has_get_headers_and_no_body
    content = "body { color: red; }\n"
    write_asset("application-A1.css", content)
    write_manifest("application.css" => "application-A1.css")

    get_response = @request.get("/application-A1.css")
    head_response = @request.head("/application-A1.css")

    assert_equal 200, head_response.status
    assert_equal "", head_response.body
    assert_equal get_response.headers, head_response.headers
  end

  def test_uses_rack_mime_types_and_binary_fallback
    write_asset("styles-A1.css", "css")
    write_asset("images/logo-A1.svg", "svg")
    write_asset("data-A1.unknown", "data")
    write_manifest(
      "styles.css" => "styles-A1.css",
      "logo.svg" => "images/logo-A1.svg",
      "data" => "data-A1.unknown"
    )

    assert_equal "text/css", @request.get("/styles-A1.css")["content-type"]
    assert_equal "image/svg+xml", @request.get("/images/logo-A1.svg")["content-type"]
    assert_equal "application/octet-stream", @request.get("/data-A1.unknown")["content-type"]
  end

  def test_unknown_and_listed_but_missing_assets_return_not_found
    write_manifest("application.js" => "application-A1.js")

    unknown = @request.get("/unknown.js")
    missing = @request.get("/application-A1.js")

    [unknown, missing].each do |response|
      assert_equal 404, response.status
      assert_equal "Not Found\n", response.body
      assert_equal response.body.bytesize.to_s, response["content-length"]
    end
  end

  def test_head_not_found_has_no_body_but_reports_get_content_length
    write_manifest({})

    response = @request.head("/unknown.js")

    assert_equal 404, response.status
    assert_equal "", response.body
    assert_equal "Not Found\n".bytesize.to_s, response["content-length"]
  end

  def test_unsupported_methods_return_method_not_allowed_before_manifest_read
    %i[post put delete].each do |method|
      response = @request.public_send(method, "/application-A1.js")

      assert_equal 405, response.status
      assert_equal "GET, HEAD", response["allow"]
      assert_equal "Method Not Allowed\n", response.body
      assert_equal response.body.bytesize.to_s, response["content-length"]
    end
  end

  def test_each_request_reads_the_current_manifest
    write_asset("application-A1.js", "first")
    write_asset("application-B2.js", "second")
    write_manifest("application.js" => "application-A1.js")

    assert_equal "first", @request.get("/application-A1.js").body

    write_manifest("application.js" => "application-B2.js")

    assert_equal 404, @request.get("/application-A1.js").status
    assert_equal "second", @request.get("/application-B2.js").body
  end

  def test_response_satisfies_rack_lint
    write_asset("application-A1.txt", "linted")
    write_manifest("application.txt" => "application-A1.txt")
    linted_app = ::Rack::Lint.new(@app)

    response = ::Rack::MockRequest.new(linted_app).get("/application-A1.txt")

    assert_equal 200, response.status
    assert_equal "linted", response.body
  end

  def test_works_under_a_rack_map_mount
    write_asset("nested/application-A1.js", "mounted")
    write_manifest("application.js" => "nested/application-A1.js")
    rack_app = @app
    mounted_app = ::Rack::Builder.new do
      map "/assets" do
        run rack_app
      end
    end.to_app

    response = ::Rack::MockRequest.new(mounted_app).get("/assets/nested/application-A1.js")

    assert_equal 200, response.status
    assert_equal "mounted", response.body
  end
end
