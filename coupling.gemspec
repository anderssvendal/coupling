# frozen_string_literal: true

require_relative "lib/coupling/version"

Gem::Specification.new do |spec|
  spec.name = "coupling"
  spec.version = Coupling::VERSION
  spec.authors = ["Anders Svendal"]
  spec.email = ["anders.svendal@gmail.com"]

  spec.summary = "Connect external asset builds to Rails and Rack"
  spec.description = "Coupling maps logical asset names to compiled files through a small JSON manifest."
  spec.homepage = "https://github.com/anderssvendal/coupling"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["allowed_push_host"] = "https://gem.coop/@hjkl"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/anderssvendal/coupling/tree/v#{spec.version}"
  spec.metadata["changelog_uri"] = "https://github.com/anderssvendal/coupling/blob/main/CHANGELOG.md"

  spec.add_dependency "rack", ">= 2.2"

  runtime_files = Dir["lib/**/*.rb"].reject { |file| file.start_with?("lib/coupling/middleman") }
  spec.files = (runtime_files + %w[CHANGELOG.md LICENSE.txt README.md]).sort
  spec.require_paths = ["lib"]
end
