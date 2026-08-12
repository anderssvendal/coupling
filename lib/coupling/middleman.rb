require 'coupling/middleman/extension'
require 'coupling/middleman/middleware'

module Coupling
  module Middleman
  end
end

::Middleman::Extensions.register(:coupling, Coupling::Middleman::Extension)
