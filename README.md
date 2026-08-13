# Coupling

Coupling connects assets built by any external tool to Rails and Rack applications through a small JSON manifest. It resolves logical asset names to fingerprinted public URLs and can serve the compiled files during development.

Coupling does not build assets, run a compiler, or manage Node and package-manager processes. Your asset toolchain remains independent; at runtime, Coupling needs only the compiled files and their manifest.

Coupling supports Ruby 3.1+, Rack 2.2+, and Rails 7.0 through 8.x. Middleman support is not included in 0.1.0.

## Getting started with Rails

Add Coupling from the [`@hjkl` gem.coop namespace](https://gem.coop/@hjkl):

```sh
bundle add coupling --source "https://gem.coop/@hjkl"
```

Configure your compiler—or a separate adapter—to write compiled files and a flat `manifest.json` to `tmp/assets`:

```json
{
  "application.css": [
    "styles/reset-A1B2C3.css",
    "application-D4E5F6.css"
  ],
  "application.js": "application-G7H8I9.js",
  "images/logo.svg": "images/logo-J1K2L3.svg"
}
```

Each manifest key is a logical asset name. Its value is either one fingerprinted path or an ordered array of paths relative to the compiled assets directory. Compiler-native formats such as Vite's nested manifest must be transformed into this flat format outside Coupling.

The Rails defaults use `tmp/assets/manifest.json`, generate URLs beneath `/assets`, and serve compiled files through the Rails application in development. To make those choices explicit, add `config/initializers/coupling.rb`:

```ruby
Coupling.configure do |config|
  config.assets_path = Rails.root.join("tmp/assets")
  config.public_path = "/assets"
  config.serve = Rails.env.development?
end
```

Use Coupling's prefixed helpers in your views:

```erb
<%= coupled_stylesheet_link_tag "application" %>
<%= coupled_javascript_include_tag "application", defer: true %>
<%= coupled_image_tag "images/logo.svg", alt: "Logo" %>
```

Run Rails and your compiler independently. When the compiler rewrites the files and manifest, the next Coupling lookup sees the new paths without restarting Rails.
