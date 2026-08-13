# frozen_string_literal: true

require "pathname"

module Coupling
  class Manifest
    class OutputValidator
      attr_reader :config, :name, :output

      def initialize(config, name, output)
        @config = config
        @name = name
        @output = output
      end

      def validate
        validate_characters!
        validate_segments!
        candidate = File.expand_path(output, assets_root)
        validate_containment!(candidate)
        validate_manifest_target!(candidate)
        validate_existing_path!(candidate)
      end

      private

      def validate_characters!
        invalid!("contains an output with a null byte") if output.include?("\0")
        invalid!("contains an output with a backslash") if output.include?("\\")
        invalid!("contains an absolute output") if absolute_output?
      end

      def validate_segments!
        segments = output.split("/", -1)
        unsafe = segments.any? { |segment| segment.empty? || %w[. ..].include?(segment) }
        invalid!("contains an unsafe output path") if unsafe
      end

      def validate_containment!(candidate)
        return if contained?(candidate, assets_root)

        invalid!("contains an output outside assets_path")
      end

      def validate_manifest_target!(candidate)
        invalid!("points to the configured manifest") if manifest_target?(candidate)
      end

      def validate_existing_path!(candidate)
        invalid!("contains a symlink escape") if existing_symlink_escape?(candidate)
      end

      def absolute_output?
        Pathname.new(output).absolute? || output.match?(/\A[A-Za-z]:\//)
      end

      def assets_root
        File.expand_path(config.assets_path.to_s)
      end

      def contained?(candidate, root)
        boundary = "#{root.delete_suffix(File::SEPARATOR)}#{File::SEPARATOR}"
        candidate == root || candidate.start_with?(boundary)
      end

      def manifest_target?(candidate)
        manifest = File.expand_path(config.manifest_path.to_s)
        return true if candidate == manifest
        return false unless File.exist?(candidate) && File.exist?(manifest)

        File.identical?(candidate, manifest)
      end

      def existing_symlink_escape?(candidate)
        return false unless File.exist?(candidate)

        root = File.exist?(assets_root) ? File.realpath(assets_root) : assets_root
        !contained?(File.realpath(candidate), root)
      rescue Errno::ENOENT
        false
      end

      def invalid!(reason)
        raise InvalidManifestError.new(config.manifest_path, "#{name.inspect} #{reason}")
      end
    end
  end
end
