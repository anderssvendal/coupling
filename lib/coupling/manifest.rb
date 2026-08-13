# frozen_string_literal: true

require "json"
require "coupling/asset"
require "coupling/manifest/validator"

module Coupling
  class Manifest
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def lookup(name)
      normalized_name = normalize_name(name)
      outputs = entries.fetch(normalized_name) { raise_asset_not_found(normalized_name) }

      raise MultipleAssetsError.new(normalized_name, outputs.length) unless outputs.one?

      outputs.first
    end

    def lookup_all(name)
      normalized_name = normalize_name(name)
      entries.fetch(normalized_name) { raise_asset_not_found(normalized_name) }
    end

    def path_to(name)
      public_url(lookup(name))
    end

    def paths_to(name)
      lookup_all(name).map { |output| public_url(output) }
    end

    def find(name)
      normalized_name = normalize_name(name)

      entries.each do |logical_name, outputs|
        output = outputs.find { |candidate| candidate == normalized_name }
        return Asset.new(logical_name, output, config: config) if output
      end

      raise_asset_not_found(normalized_name)
    end

    def assets
      entries.flat_map do |logical_name, outputs|
        outputs.map { |output| Asset.new(logical_name, output, config: config) }
      end
    end

    def entries
      Validator.new(config, method(:normalize_name)).validate(read_document)
    end

    private

    def read_document
      JSON.parse(File.read(config.manifest_path))
    rescue Errno::ENOENT => e
      raise ManifestNotFoundError.new(config.manifest_path), cause: e
    rescue JSON::ParserError => e
      raise InvalidManifestError.new(config.manifest_path, e.message), cause: e
    end

    def public_url(output)
      return "/#{output}" if config.public_path == "/"

      "#{config.public_path}/#{output}"
    end

    def normalize_name(name)
      normalized = name.to_s
      prefix = config.public_path

      return "" if prefix != "/" && normalized == prefix
      return normalized.delete_prefix("#{prefix}/") if prefix != "/" && normalized.start_with?("#{prefix}/")

      normalized.delete_prefix("/")
    end

    def raise_asset_not_found(name)
      raise AssetNotFoundError, name
    end
  end
end
