# frozen_string_literal: true

require "rack/mime"
require "rack/request"
require "coupling/manifest"

module Coupling
  module Rack
    class App
      ALLOWED_METHODS = %w[GET HEAD].freeze
      FALLBACK_MIME_TYPE = "application/octet-stream"

      def call(env)
        request = ::Rack::Request.new(env)
        return method_not_allowed unless ALLOWED_METHODS.include?(request.request_method)

        serve(request)
      rescue AssetNotFoundError, Errno::ENOENT, Errno::ENOTDIR
        not_found(head: env["REQUEST_METHOD"] == "HEAD")
      end

      private

      def serve(request)
        output_path = request.path_info.to_s.delete_prefix("/")
        return not_found(head: request.head?) if manifest_request?(output_path)

        asset = Coupling.manifest.find(output_path)
        successful(asset.read, asset.path, head: request.head?)
      end

      def successful(content, path, head:)
        response(
          200,
          content,
          {
            "cache-control" => "no-cache",
            "content-type" => ::Rack::Mime.mime_type(File.extname(path).downcase, FALLBACK_MIME_TYPE)
          },
          head: head
        )
      end

      def not_found(head: false)
        response(404, "Not Found\n", { "content-type" => "text/plain; charset=utf-8" }, head: head)
      end

      def method_not_allowed
        response(
          405,
          "Method Not Allowed\n",
          {
            "allow" => ALLOWED_METHODS.join(", "),
            "content-type" => "text/plain; charset=utf-8"
          }
        )
      end

      def response(status, content, headers, head: false)
        headers = headers.merge("content-length" => content.bytesize.to_s)
        [status, headers, head ? [] : [content]]
      end

      def manifest_request?(output_path)
        basename = File.basename(output_path)
        basename == "manifest.json" || basename == Coupling.config.manifest_path.basename.to_s
      end
    end
  end
end
