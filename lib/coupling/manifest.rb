require 'listen'
require 'coupling/asset'

module Coupling
  class Manifest
    attr_reader :config, :listener, :entries

    def initialize(config)
      @config = config

      listen
    end

    def lookup(name)
      name = normalize_name(name)

      entries[name] || raise_asset_not_found(name)
    end

    def path_to(name)
      "#{public_path}/#{lookup(name)}".gsub(/\/{2,}/, '/')
    end

    def find(name)
      name = normalize_name(name)

      assets.find { _1.name == name || _1.path == name } || raise_asset_not_found(name)
    end

    def assets
      entries.map do |k, v|
        Asset.new(k, v)
      end
    end

    def entries
      @entries ||= JSON
        .load_file(path)
        .each_with_object({}) do |(k, v), entries|
          next unless k.is_a?(String) && v.is_a?(String)

          k = normalize_name(k)
          v = normalize_name(v)

          entries[k] = v
        end
    end
    
    private

    def listen
      @listener = Listen.to(dirname) do |modified, added, removed|
        next unless modified.include?(path.to_s)

        @entries = nil
      end
      listener.start
    end

    def path
      config.root.join('manifest.json')
    end

    def dirname
      File.dirname(path)
    end

    def filename
      File.basename(path)
    end

    def public_path
      config.public_path
    end

    def normalize_name(name)
      name
        .gsub(/^#{public_path}\/*/, '')
        .gsub(/^\//, '')
    end

    def raise_asset_not_found(name)
      name = normalize_name(name)

      raise AssetNotFoundError.new(name)
    end
  end
end
