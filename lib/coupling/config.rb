module Coupling
  class Config
    attr_accessor :root, :public_path
    attr_writer :helpers, :serve

    def initialize
      self.public_path = '/assets'
      self.helpers = true
      self.serve = true
    end

    def public_path=(value)
      @public_path = value.to_s.gsub(/\/+$/, '')
    end

    def helpers?
      !!@helpers
    end

    def serve?
      !!@serve
    end
  end
end
