# frozen_string_literal: true

require "coupling/middleman"

activate :coupling,
         assets_path: File.expand_path("../assets", root),
         public_path: "/assets"
