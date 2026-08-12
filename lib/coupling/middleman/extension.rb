require 'fileutils'

require 'coupling/helper'
require 'coupling/middleman/middleware'

module Coupling::Middleman
  class Extension < ::Middleman::Extension
    option :root

    def build_command
      'yarn build'
    end

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
      build_assets(builder)
    end

    def after_build(builder)
      ensure_assets_dir(builder)
      copy_assets(builder)
    end

    private

    def build_assets(builder)
      Open3.popen3(build_command) do |stdin, stdout, stderr, waie_thread|
        stdout_thread = Thread.new do
          stdout.each_line do |line|
            builder.thor.say_status(:coupling, line.strip)
          end
        end

        stderr_thread = Thread.new do
          stderr.each_line do |line|
            builder.thor.say_status(:coupling, line.strip)
          end
        end

        stdout_thread.join
        stderr_thread.join

        # if wait_thread.value.success?
        #   puts "Success!"
        # else
        #   puts "Error!"
        # end
      end
    end

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
          builder.thor.say_status(:copy_asset, build_path, :green)
          FileUtils.mkdir_p(File.dirname(dst)) unless Dir.exist?(File.dirname(dst))
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
