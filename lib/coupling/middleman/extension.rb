require 'fileutils'

require 'coupling/helper'
require 'coupling/middleman/middleware'

module Coupling::Middleman
  class Extension < ::Middleman::Extension
    option :root

    def initialize(app, options_hash={}, &block)
      super

      Coupling.configure do |config|
        config.root = options[:root].presence || app.root_path.join('tmp', 'assets')
        config.public_path = options[:public_path] || '/assets'
      end

      app.use(Coupling::Middleman::Middleware)
    end

    helpers do
      include Coupling::Helper
    end


    def before_build(builder)
      # TODO: Override app.config[:skip_clean_build] to not delete from build_dir
    end

    def after_build(builder)
      ensure_assets_dir(builder)
      copy_assets(builder)
    end

    private

    def ensure_assets_dir(builder)
      if Dir.exist?(build_dir_path)
        builder.thor.say_status(:exists, build_dir, :blue)
      else
        builder.thor.say_status(:create, build_dir, :green)
        FileUtils.mkdir_p(build_dir_path)
      end
    end

    def copy_assets(builder)
      Coupling.manifest.assets.each do |asset|
        src = asset.absolute_path
        dst = File.join(build_dir_path, asset.path)
        build_path = File.join(build_dir, asset.path)

        if File.exist?(dst)
          builder.thor.say_status(:exists, build_path, :blue)
        else
          builder.thor.say_status(:copy, build_path, :green)
          FileUtils.cp(src, dst)
        end
      end
    end

    def build_dir
      File.join(app.config[:build_dir], Coupling.config.public_path)
    end

    def build_dir_path
      File.join(Dir.pwd, build_dir)
    end
  end
end
