require 'mime-types'

module Coupling
  class Asset
    attr_reader :name, :path

    def initialize(name, path = nil)
      @name = name
      @path = path || name
    end

    def extension
      @extension ||= path.to_s.split('.').last.to_s
    end

    def absolute_path
      Coupling.config.root.join(path)
    end

    def read
      File.read(absolute_path)
    end

    def content_type
      MIME::Types.type_for(extension).try(:first).try(:to_s) || 'text/plain'
    end
  end
end
