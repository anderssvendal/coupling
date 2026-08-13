# frozen_string_literal: true

require "coupling/manifest"

module Coupling
  module Helper
    def coupled_asset_paths(name)
      Coupling.manifest.paths_to(name)
    end

    def coupled_asset_path(name)
      Coupling.manifest.path_to(name)
    end

    def coupled_stylesheet_link_tag(name, **options)
      stylesheet_link_tag(*coupled_asset_paths(with_extension(name, ".css")), options)
    end

    def coupled_javascript_include_tag(name, **options)
      javascript_include_tag(*coupled_asset_paths(with_extension(name, ".js")), options)
    end

    def coupled_image_tag(name, **options)
      image_tag(coupled_asset_path(name), options)
    end

    private

    def with_extension(name, extension)
      name = name.to_s
      name.end_with?(extension) ? name : "#{name}#{extension}"
    end
  end
end
