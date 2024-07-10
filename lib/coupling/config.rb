module Coupling
  class Config
    attr_accessor :root, :public_path

    def initialize
      @public_path = '/assets'
    end

    def public_path=(value)
      @public_path = value.to_s.gsub(/\/+$/, '')
    end
  end
end
