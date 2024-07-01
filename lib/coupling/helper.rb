require "coupling/manifest"

module Coupling
  module Helper
    def esbuild_asset_path(name)
      esbuild_manifest.path_to(name)
    end

    def esbuild_stylesheet_link_tag(name)
      name = "#{name}.css" unless name.ends_with?('.css')

      tag(:link, href: esbuild_asset_path(name), rel: 'stylesheet')
    end

    def esbuild_javascript_include_tag(name)
      name = "#{name}.js" unless name.ends_with?('.js')

      content_tag('script', src: esbuild_asset_path(name)) { '' }
    end

    def esbuild_image_tag(name)
      image_tag(esbuild_asset_path(name))
    end

    def esbuild_assets
      esbuild_manifest.entries.keys
    end

    def esbuild_manifest
      @esbuild_manifest ||= Coupling::Manifest.new
    end
  end
end
