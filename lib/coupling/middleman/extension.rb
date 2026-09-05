# frozen_string_literal: true

require "fileutils"
require "pathname"
require "coupling/helper"
require "coupling/rack/app"

module Coupling
  module Middleman
    class Extension < ::Middleman::Extension
      option :assets_path, nil, "Directory containing compiled assets and manifest.json"
      option :manifest_path, nil, "Path to the Coupling manifest"
      option :public_path, nil, "URL path where compiled assets are published"
      option :serve, nil, "Serve compiled assets from the Middleman preview server"

      helpers Coupling::Helper

      def after_configuration
        configure_coupling
        mount_asset_server if Coupling.config.serve?
      end

      def after_build(builder)
        copy_assets(builder)
      end

      private

      def configure_coupling
        config = Coupling.config
        config.apply_middleman_defaults(root: app.root_path, server: app.server?)
        assign_path_option(config, :assets_path)
        assign_path_option(config, :manifest_path)
        assign_option(config, :public_path)
        assign_option(config, :serve)
      end

      def assign_path_option(config, name)
        value = options[name]
        config.public_send("#{name}=", expand_from_root(value)) if value
      end

      def assign_option(config, name)
        value = options[name]
        config.public_send("#{name}=", value) unless value.nil?
      end

      def expand_from_root(path)
        path = Pathname.new(path.to_s)
        path.absolute? ? path : app.root_path.join(path).expand_path
      end

      def mount_asset_server
        if Coupling.config.public_path == "/"
          raise ArgumentError, "Middleman asset serving requires a public_path other than /"
        end

        asset_app = Coupling::Rack::App.new
        app.map(Coupling.config.public_path) { run asset_app }
      end

      def copy_assets(builder)
        build_root = File.expand_path(app.config[:build_dir], app.root)
        destination_root = build_destination(build_root)
        prepare_directory(destination_root, build_root)

        Coupling.manifest.assets.uniq(&:path).each do |asset|
          copy_asset(asset, destination_root, build_root, builder)
        end
      end

      def build_destination(build_root)
        relative_public_path = Coupling.config.public_path.delete_prefix("/")
        destination = File.expand_path(relative_public_path, build_root)
        validate_containment!(destination, build_root)
        destination
      end

      def copy_asset(asset, destination_root, build_root, builder)
        source = asset.absolute_path
        raise Errno::ENOENT, "Manifest-listed asset not found: #{source}" unless source.file?

        destination = File.expand_path(asset.path, destination_root)
        validate_containment!(destination, destination_root)
        prepare_directory(File.dirname(destination), build_root)
        FileUtils.cp(source, destination)
        report_copy(builder, destination)
      end

      def prepare_directory(directory, build_root)
        FileUtils.mkdir_p(directory)
        validate_containment!(File.realpath(directory), File.realpath(build_root))
      end

      def validate_containment!(candidate, root)
        boundary = "#{root.delete_suffix(File::SEPARATOR)}#{File::SEPARATOR}"
        return if candidate == root || candidate.start_with?(boundary)

        raise ArgumentError, "Coupling build destination escapes build_dir: #{candidate}"
      end

      def report_copy(builder, destination)
        path = Pathname.new(destination).relative_path_from(app.root_path)
        if builder.thor
          builder.thor.say_status(:copy_asset, path, :green)
        else
          logger.info "Coupling copied #{path}"
        end
      end
    end
  end
end
