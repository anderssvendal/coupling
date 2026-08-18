## [Unreleased]

- Add the pnpm workspace and the ESM `coupling-vite` package for Vite 5 through 7 builds.
- Integrate package compatibility, type, test, and packed-artifact checks with the local mise workflow.

## [0.1.1] - 2026-08-18

- Accept a reserved empty manifest key for anonymous generated outputs such as shared chunks, lazy chunks, and source maps.

## [0.1.0] - 2026-08-17

- Add strict, uncached lookup for flat JSON manifests with ordered multi-output entries.
- Add prefixed Rails helpers and optional development asset serving for Rails 7.0 through 8.x.
- Add a generic Rack 2.2+ development endpoint restricted to manifest-listed files.
- Support Ruby 3.1+ with Rack as the only runtime dependency.
