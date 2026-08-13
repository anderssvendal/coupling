# frozen_string_literal: true

require "pathname"

module Coupling
  class Config
    attr_reader :assets_path, :public_path
    attr_writer :helpers

    def initialize
      @assets_path = Pathname.pwd.join("tmp/assets")
      @assets_path_configured = false
      @manifest_path = nil
      @manifest_path_configured = false
      @serve = false
      @serve_configured = false
      self.public_path = "/assets"
      self.helpers = true
    end

    def assets_path=(value)
      @assets_path = coerce_path(value)
      @assets_path_configured = true
    end

    def assets_path_configured?
      @assets_path_configured
    end

    def manifest_path
      @manifest_path || assets_path.join("manifest.json")
    end

    def manifest_path=(value)
      @manifest_path = coerce_path(value)
      @manifest_path_configured = true
    end

    def manifest_path_configured?
      @manifest_path_configured
    end

    def public_path=(value)
      segments = value.to_s.split("/").reject(&:empty?)
      @public_path = "/#{segments.join("/")}"
    end

    def helpers?
      !!@helpers
    end

    def serve=(value)
      @serve = value
      @serve_configured = true
    end

    def serve?
      !!@serve
    end

    def serve_configured?
      @serve_configured
    end

    def apply_rails_defaults(root:, development:)
      @assets_path = coerce_path(root).join("tmp/assets") unless assets_path_configured?
      @serve = development unless serve_configured?
    end

    private

    def coerce_path(value)
      value = value.to_path if value.respond_to?(:to_path)
      Pathname.new(value.to_s)
    end
  end
end
