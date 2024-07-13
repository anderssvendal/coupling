module Coupling
  class AssetNotFoundError < StandardError
    def initialize(name)
      super("Asset not found: #{name}")
    end
  end

  class ManifestNotFoundError < StandardError
    def initialize(name)
      super("Manifest not found. Make sure assets have been built")
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
      @manifest ||= Coupling::Manifest.new
    end
  end
end

require 'coupling/config'
require 'coupling/manifest'
require 'coupling/version'
