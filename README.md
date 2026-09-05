# Coupling

Coupling connects assets built by any external tool to Rails, Middleman, and Rack applications through a small JSON manifest.

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

#### Rails

Create `config/initializers/coupling.rb`:

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

Rails automatically serves manifest-listed assets in development.

#### Middleman

Require and activate the extension in `config.rb`:

```ruby
require "coupling/middleman"

activate :coupling
```

By default, the extension reads `<project>/tmp/assets/manifest.json`, publishes assets under `/assets`, and serves manifest-listed files from the preview server. Paths and serving can be configured during activation:

```ruby
activate :coupling,
         assets_path: "compiled/assets",
         manifest_path: "compiled/assets/manifest.json",
         public_path: "/assets",
         serve: true
```

Relative filesystem paths are resolved from the Middleman project root. During a static build, Coupling waits until Middleman has finished its normal cleaning and then copies every manifest-listed output into `build/assets`. Anonymous outputs are included, but `manifest.json` and other unlisted files are not copied.

Coupling does not run an asset compiler or package manager. Build assets before Middleman:

```sh
pnpm build
bundle exec middleman build
```

For preview development, run your asset builder in watch mode alongside `middleman server`.

### Assets

#### Vite

For Vite 5, 6, or 7, install [`coupling-vite`](packages/coupling-vite) and add the plugin to `vite.config.ts`:

```sh
pnpm add --save-dev coupling-vite vite
```

Assuming your entry point is `app/frontend/application.ts`, configure Vite's output directory to match Coupling's `assets_path`:

```ts
import { fileURLToPath } from "node:url";

import coupling from "coupling-vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [coupling({ sourceRoot: "app/frontend" })],
  build: {
    outDir: "tmp/assets",
    rollupOptions: {
      input: {
        application: fileURLToPath(
          new URL("./app/frontend/application.ts", import.meta.url),
        ),
      },
    },
  },
});
```

The `application` input produces the logical `application.js` entry and, when it imports CSS, `application.css`. Assets imported from `app/frontend`, such as `images/logo.svg`, keep their source-relative logical names.

The plugin writes `manifest.json` into Vite's output directory and supports `vite build --watch`. Vite's development server is not yet integrated. See the [coupling-vite documentation](packages/coupling-vite/README.md) for options and output behavior.

#### Manifest contract

`coupling-vite` and other asset builders must output compiled files and a flat `manifest.json`:

```json
{
  "application.css": ["styles/reset-A1B2C3.css", "application-D4E5F6.css"],
  "application.js": "application-G7H8I9.js",
  "images/logo.svg": "images/logo-M4N5P6.svg",
  "": ["shared-Q7R8S9.js", "application-G7H8I9.js.map"]
}
```

Each named entry maps a logical name to one relative asset path or an ordered array of paths. Builders may use the reserved empty key (`""`) for generated outputs that must be served but have no public logical name, such as shared chunks, lazy chunks, and source maps. This anonymous entry must be a non-empty array of unique relative paths. Its files participate in reverse lookup and asset serving, but consumers should not perform logical lookup using the empty key.

Builders other than Vite can emit this format directly or transform their own manifest into it.
