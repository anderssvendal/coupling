
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

  def self.public_path
    '/assets'
  end

  def self.build_dir
    Rails.root.join('tmp/assets')
  end
end

require 'coupling/version'
