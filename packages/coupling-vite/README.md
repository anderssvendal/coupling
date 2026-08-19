# coupling-vite

`coupling-vite` generates a [Coupling](https://github.com/anderssvendal/coupling) asset manifest from a Vite build.

It supports Vite 5, 6, and 7 on Node 20.19 or newer. The package is ESM-only.

## Installation

Install the plugin and a supported Vite version:

```sh
pnpm add --save-dev coupling-vite vite
```

Use a Coupling gem version that accepts the reserved anonymous `""` manifest entry before adopting generated manifests from this package.

## Configuration

Add `coupling()` to `vite.config.ts`:

```ts
import coupling from "coupling-vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [coupling()],
});
```

Set Vite's `build.outDir` to the directory read by Coupling. Named keys in `build.rollupOptions.input` determine the logical JavaScript and CSS entry names; for example, an `application` input produces `application.js` and, when it imports CSS, `application.css`.

The default export and named export are the same plugin function:

```ts
import couplingDefault, { coupling, type CouplingOptions } from "coupling-vite";
```

### Options

| Option       | Default           | Description                                                            |
| ------------ | ----------------- | ---------------------------------------------------------------------- |
| `fileName`   | `"manifest.json"` | Manifest path relative to Vite's `build.outDir`.                       |
| `sourceRoot` | Vite's root       | Root stripped from imported source assets when deriving logical names. |

A relative `sourceRoot` is resolved from Vite's root. For example:

```ts
coupling({
  fileName: "metadata/coupling.json",
  sourceRoot: "app/assets",
});
```

`fileName` must be a safe relative path using forward slashes. Absolute paths, empty segments, `.` or `..` segments, and backslashes are rejected.

## Generated manifest

Given configured `application` and `admin` entries, imported CSS and images, code splitting, and external source maps, the plugin can emit:

```json
{
  "application.js": "assets/application-A1.js",
  "application.css": ["assets/shared-B2.css", "assets/application-C3.css"],
  "admin.js": "assets/admin-D4.js",
  "admin.css": ["assets/shared-B2.css", "assets/admin-E5.css"],
  "images/logo.svg": "assets/logo-F6.svg",
  "": [
    "assets/shared-G7.js",
    "assets/lazy-H8.js",
    "assets/application-A1.js.map"
  ]
}
```

The manifest is emitted through Vite's bundle lifecycle. Vite's own `build.manifest` option does not need to be enabled.

### Named entries

- Each configured, non-dynamic JavaScript entry maps `<entry>.js` to its emitted entry chunk. Shared and lazy chunks are not added to this value.
- CSS required by an entry's static dependency graph maps `<entry>.css` to one output string or a dependency-first ordered array of outputs. Paths are deduplicated within each entry, while shared stylesheets appear under every entry that requires them. The key is omitted when the entry has no static CSS.
- Imported images, fonts, and other emitted assets beneath `sourceRoot` use their source-relative POSIX path as the logical name.
- An inlined asset has no output file and is therefore omitted.

### Anonymous outputs

The reserved empty key (`""`) contains every emitted runtime file not already represented by a named entry. Typical anonymous outputs include shared JavaScript chunks, dynamic chunks and their dynamic-only CSS, generated CSS outside named entries' static graphs, assets outside `sourceRoot`, and external source maps.

The empty key is omitted when there are no anonymous outputs. Application code and Rails helpers should look up named entries only; the anonymous bucket exists so Coupling can validate, package, find, and serve browser-managed files.

### Source maps

- `build.sourcemap: true` and `build.sourcemap: "hidden"` produce external map files listed anonymously.
- `build.sourcemap: false` produces no map entries.
- `build.sourcemap: "inline"` produces no separate map file or manifest entry.

Source maps can expose source code. Enable them only when appropriate for the deployment.

## Build and watch behavior

Normal `vite build`, programmatic builds including `write: false`, and `vite build --watch` are supported. Every watch rebuild derives a new manifest from the current bundle, so removed or renamed outputs are not retained in the new manifest.

`vite serve` and hot-module replacement are not yet integrated. Use Vite's build watch mode when Coupling should serve rebuilt files during development.

The initial release also rejects SSR builds, library mode, and multiple Rollup outputs instead of generating a partial manifest.

## License

[MIT](LICENSE.txt)
