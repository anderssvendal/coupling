# frozen_string_literal: true

module Coupling
  class AssetNotFoundError < StandardError
    def initialize(name)
      super("Asset not found: #{name}")
    end
  end

  class MultipleAssetsError < StandardError
    def initialize(name, count)
      super("Asset #{name} has #{count} outputs; use a plural lookup")
    end
  end

  class ManifestNotFoundError < StandardError
    def initialize(path)
      super("Manifest not found at #{path}. Build or deploy the assets before using Coupling")
    end
  end

  class InvalidManifestError < StandardError
    def initialize(path, reason)
      super("Invalid manifest at #{path}: #{reason}")
    end
  end

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield(config)
    end

    def manifest
      @manifest ||= Coupling::Manifest.new(config)
    end

    def assets
      manifest.assets
    end

    def reset!
      @config = Config.new
      @manifest = nil
    end
  end
end

require "coupling/config"
require "coupling/manifest"
require "coupling/railtie" if defined?(Rails::Railtie)
require "coupling/version"
