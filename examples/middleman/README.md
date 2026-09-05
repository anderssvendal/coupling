# Coupling Middleman example

A minimal Middleman application that renders, serves, and copies the checked-in files in [`../assets/`](../assets/) through Coupling. The assets are shared with the Rails example, and the app has no Node, package-manager, or asset-compiler dependency.

Run the repository-level smoke check with `mise run middleman:test`.

Build the site with `mise run middleman:build`. The extension copies manifest-listed outputs into `build/assets` after Middleman finishes cleaning the build directory; it does not copy `manifest.json`.

Start the preview server with `mise run middleman:server`, then open <http://127.0.0.1:4567>. Set `PORT` to use another port.
