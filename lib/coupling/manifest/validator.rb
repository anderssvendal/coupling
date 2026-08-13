# frozen_string_literal: true

require "coupling/manifest/asset_path_validator"

module Coupling
  class Manifest
    class Validator
      attr_reader :config, :normalizer

      def initialize(config, normalizer)
        @config = config
        @normalizer = normalizer
      end

      def validate(document)
        invalid!("top level must be a JSON object") unless document.is_a?(Hash)

        document.each_with_object({}) do |(name, value), validated|
          validate_entry!(validated, name, value)
        end
      end

      private

      def validate_entry!(validated, name, value)
        validate_name!(name)
        normalized_name = normalizer.call(name)
        validate_normalized_name!(validated, name, normalized_name)
        outputs = normalize_outputs(normalized_name, value)
        outputs.each { |output| AssetPathValidator.new(config, normalized_name, output).validate }
        validate_duplicates!(normalized_name, outputs)
        validated[normalized_name] = outputs
      end

      def validate_name!(name)
        return if name.is_a?(String) && !name.empty?

        invalid!("logical names must be non-empty strings")
      end

      def validate_normalized_name!(validated, name, normalized_name)
        invalid!("logical name #{name.inspect} normalizes to an empty string") if normalized_name.empty?
        return unless validated.key?(normalized_name)

        invalid!("duplicate normalized logical name #{normalized_name.inspect}")
      end

      def normalize_outputs(name, value)
        outputs = value.is_a?(String) ? [value] : value
        return outputs if valid_outputs?(outputs)

        invalid!("#{name.inspect} must map to a non-empty string or non-empty array of non-empty strings")
      end

      def valid_outputs?(outputs)
        outputs.is_a?(Array) && !outputs.empty? && outputs.all? do |output|
          output.is_a?(String) && !output.empty?
        end
      end

      def validate_duplicates!(name, outputs)
        return if outputs.uniq.length == outputs.length

        invalid!("#{name.inspect} contains duplicate outputs")
      end

      def invalid!(reason)
        raise InvalidManifestError.new(config.manifest_path, reason)
      end
    end
  end
end
