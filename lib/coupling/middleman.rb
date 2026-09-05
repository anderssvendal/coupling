# frozen_string_literal: true

require "coupling"
require "middleman-core"

module Coupling
  module Middleman
  end
end

require "coupling/middleman/extension"

Middleman::Extensions.register(:coupling, Coupling::Middleman::Extension)
