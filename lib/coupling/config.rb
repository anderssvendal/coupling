module Coupling
  class Config
    attr_accessor :root, :public_path, :helpers

    def initialize
      self.public_path = '/assets'
      self.helpers = true
    end

    def public_path=(value)
      @public_path = value.to_s.gsub(/\/+$/, '')
    end

    def helpers?
      !!helpers
    end
  end
end
