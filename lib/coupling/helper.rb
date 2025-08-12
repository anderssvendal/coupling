require "coupling/manifest"

module Coupling
  module Helper
    def coupled_asset_path(name)
      coupled_manifest.path_to(name)
    end
    module_function :coupled_asset_path

    def coupled_stylesheet_link_tag(name)
      name = "#{name}.css" unless name.ends_with?('.css')

      tag(:link, href: coupled_asset_path(name), rel: 'stylesheet')
    end
    module_function :coupled_stylesheet_link_tag

    def coupled_javascript_include_tag(name)
      name = "#{name}.js" unless name.ends_with?('.js')

      content_tag('script', src: coupled_asset_path(name)) { '' }
    end
    module_function :coupled_javascript_include_tag

    def coupled_image_tag(name, options = {})
      image_tag(coupled_asset_path(name), options)
    end
    module_function :coupled_image_tag

    def coupled_assets
      coupled_manifest.entries.keys
    end
    module_function :coupled_assets

    def coupled_manifest
      Coupling.manifest
    end
    module_function :coupled_manifest
  end
end
