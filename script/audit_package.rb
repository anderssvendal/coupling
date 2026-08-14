# frozen_string_literal: true

require "digest"
require "rubygems/package"

artifact = ARGV.fetch(0)
package = Gem::Package.new(artifact)
spec = package.spec
expected_files = Gem::Specification.load("coupling.gemspec").files.sort
actual_files = package.contents.sort

unless actual_files == expected_files
  added = (actual_files - expected_files).map { |file| "+ #{file}" }
  missing = (expected_files - actual_files).map { |file| "- #{file}" }
  abort "Package files differ from the gemspec:\n#{(added + missing).join("\n")}"
end

abort "Unexpected package version: #{spec.version}" unless spec.version.to_s == Coupling::VERSION
abort "Unexpected runtime dependencies" unless spec.runtime_dependencies.map(&:name) == ["rack"]
abort "Unexpected Rack requirement" unless spec.runtime_dependencies.first.requirement.to_s == ">= 2.2"
abort "Unexpected push host" unless spec.metadata["allowed_push_host"] == "https://gem.coop/@hjkl"

puts "Package: #{artifact}"
puts "Files: #{actual_files.length}"
puts "SHA256: #{Digest::SHA256.file(artifact).hexdigest}"
