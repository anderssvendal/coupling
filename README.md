# Coupling

Coupling connects assets built by any external tool to Rails and Rack applications through a small JSON manifest.

## Getting started

### Ruby

#### Add the gem

Add Coupling from the [`@hjkl` gem.coop namespace](https://gem.coop/@hjkl):

```sh
bundle add coupling --source "https://gem.coop/@hjkl"
```

Or add it to your `Gemfile`:

```ruby
gem "coupling", source: "https://gem.coop/@hjkl"
```

#### Configuration

Create `config/initializers/coupling.rb`:

```ruby
Coupling.configure do |config|
  config.assets_path = Rails.root.join("tmp/assets")
  config.public_path = "/assets"
  config.serve = Rails.env.development?
end
```

#### Rails

Use Coupling's prefixed helpers in your views:

```erb
<%= coupled_stylesheet_link_tag "application" %>
<%= coupled_javascript_include_tag "application", defer: true %>
<%= coupled_image_tag "images/logo.svg", alt: "Logo" %>
```

Rails automatically serves manifest-listed assets in development.

### Assets

Your asset builder must output compiled files and a flat `manifest.json`:

```json
{
  "application.css": [
    "styles/reset-A1B2C3.css",
    "application-D4E5F6.css"
  ],
  "application.js": "application-G7H8I9.js",
  "images/logo.svg": "images/logo-M4N5P6.svg",
  "": [
    "shared-Q7R8S9.js",
    "application-G7H8I9.js.map"
  ]
}
```

Each named entry maps a logical name to one relative asset path or an ordered array of paths. Builders may use the reserved empty key (`""`) for generated outputs that must be served but have no public logical name, such as shared chunks, lazy chunks, and source maps. This anonymous entry must be a non-empty array of unique relative paths. Its files participate in reverse lookup and asset serving, but consumers should not perform logical lookup using the empty key.

For now, configure or transform your bundler's output yourself. Instructions and packages for popular bundlers such as Vite are planned.
