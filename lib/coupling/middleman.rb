module Coupling
  class Middleman < Middleman::Extension
    option :root

    def initialize(app, options_hash={}, &block)
      super

      # puts 'config Coupling'
      # puts options
      # binding.irb
    end
  end
end

::Middleman::Extensions.register(:coupling, Coupling::Middleman)
