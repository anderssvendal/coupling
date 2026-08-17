# frozen_string_literal: true

require "pathname"

module Coupling
  class Asset
    attr_reader :config, :name, :path

    def initialize(name, path = nil, config: Coupling.config)
      @name = name
      @path = path || name
      @config = config
    end

    def absolute_path
      root = File.expand_path(config.assets_path.to_s)
      candidate = File.expand_path(path.to_s, root)
      validate_containment!(candidate, root)

      Pathname.new(resolve_existing_path(candidate, root))
    end

    def read
      File.binread(absolute_path)
    end

    private

    def resolve_existing_path(candidate, root)
      return candidate unless File.exist?(candidate)

      real_root = File.exist?(root) ? File.realpath(root) : root
      real_candidate = File.realpath(candidate)
      validate_containment!(real_candidate, real_root)
      real_candidate
    end

    def validate_containment!(candidate, root)
      return if contained?(candidate, root)

      raise ArgumentError, "Asset path escapes assets_path: #{path}"
    end

    def contained?(candidate, root)
      boundary = "#{root.delete_suffix(File::SEPARATOR)}#{File::SEPARATOR}"
      candidate == root || candidate.start_with?(boundary)
    end
  end
end
