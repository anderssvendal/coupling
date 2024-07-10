require 'coupling/asset'

module Coupling
  class Manifest
    class << self
      def find(name)
        new.find(name)
      end
    end

    def lookup(name)
      name = normalize_name(name)

      entries[name] || raise_asset_not_found(name)
    end

    def path_to(name)
      "#{Coupling.config.public_path}/#{lookup(name)}"
    end

    def find(name)
      name = normalize_name(name)

      raise_asset_not_found(name) unless entries.values.include?(name)

      Asset.new(name)
    end

    def entries
      @entries ||= JSON
        .load_file(path)
        .each_with_object({}) do |(k, v), entries|
          k = k.gsub(/^#{path_prefix}/, '')
          v = v.gsub(/^#{path_prefix}/, '')

          entries[k] = v
        end
    end

    private

    def path
      Coupling.config.root.join('manifest.json')
    end

    def path_prefix
      Coupling.config.root.to_s.gsub(Rails.root.to_s, '').gsub(/^\//, '') + '/'
    end

    def normalize_name(name)
      name.gsub(/^#{Coupling.config.public_path}\/*/, '')
    end

    def raise_asset_not_found(name)
      name = normalize_name(name)

      raise AssetNotFoundError.new(name)
    end
  end
end
