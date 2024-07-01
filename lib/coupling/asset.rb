module Coupling
  class Asset
    attr_reader :path

    def initialize(path)
      @path = path
    end

    def extension
      @extension ||= path.to_s.split('.').last.to_sym
    end

    def absolute_path
      Coupling.build_dir.join(path)
    end

    def read
      File.read(absolute_path)
    end

    def content_type
      Mime::Type.lookup_by_extension(extension).to_s.presence || 'text/plain'
    end
  end
end
