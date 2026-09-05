# Coupling Rails example

A minimal Rails application that renders and serves the checked-in files in [`../assets/`](../assets/) through Coupling. The assets are shared with the Middleman example, and the app has no Node, package-manager, or asset-compiler dependency.

Run the repository-level smoke check with `mise run rails:test`.

Start the app with `mise run rails:server`, then open <http://127.0.0.1:3000>. Set `PORT` to use another port.
