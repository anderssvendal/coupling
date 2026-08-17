import { describe, expect, it } from "vitest"

import {
  createNamedManifest,
  representedOutputs,
  serializeManifest,
  type BuildBundle,
} from "../src/manifest.js"

const context = {
  sourceRoot: "/repo/app/assets",
  viteRoot: "/repo",
}

describe("createNamedManifest", () => {
  it("creates deterministic JS, ordered CSS, and source-relative asset entries", () => {
    const bundle: BuildBundle = {
      "assets/application-A1.js": {
        type: "chunk",
        fileName: "assets/application-A1.js",
        name: "application",
        isEntry: true,
        viteMetadata: {
          importedCss: new Set([
            "assets/reset-B2.css",
            "assets/application-C3.css",
            "assets/reset-B2.css",
          ]),
        },
      },
      "assets/reset-B2.css": {
        type: "asset",
        fileName: "assets/reset-B2.css",
        originalFileNames: ["app/assets/reset.css"],
      },
      "assets/application-C3.css": {
        type: "asset",
        fileName: "assets/application-C3.css",
        originalFileNames: ["app/assets/application.css"],
      },
      "assets/logo-D4.svg": {
        type: "asset",
        fileName: "assets/logo-D4.svg",
        originalFileNames: [
          "app/assets/images/logo.svg",
          "app/assets/branding/logo.svg",
        ],
      },
      "assets/body-E5.woff2": {
        type: "asset",
        fileName: "assets/body-E5.woff2",
        originalFileNames: ["app/assets/fonts/body.woff2"],
      },
      "assets/lazy-F6.js": {
        type: "chunk",
        fileName: "assets/lazy-F6.js",
        name: "lazy",
        isEntry: false,
        isDynamicEntry: true,
      },
    }

    expect(createNamedManifest(bundle, context)).toEqual({
      "application.js": "assets/application-A1.js",
      "application.css": ["assets/reset-B2.css", "assets/application-C3.css"],
      "images/logo.svg": "assets/logo-D4.svg",
      "branding/logo.svg": "assets/logo-D4.svg",
      "fonts/body.woff2": "assets/body-E5.woff2",
    })
  })

  it("uses scalar CSS values and omits CSS when an entry has none", () => {
    const bundle: BuildBundle = {
      "assets/application.js": {
        type: "chunk",
        fileName: "assets/application.js",
        name: "application",
        isEntry: true,
        viteMetadata: { importedCss: new Set(["assets/application.css"]) },
      },
      "assets/admin.js": {
        type: "chunk",
        fileName: "assets/admin.js",
        name: "admin",
        isEntry: true,
      },
    }

    expect(createNamedManifest(bundle, context)).toEqual({
      "application.js": "assets/application.js",
      "application.css": "assets/application.css",
      "admin.js": "assets/admin.js",
    })
  })

  it("deduplicates identical mappings and rejects conflicts", () => {
    const aliases: BuildBundle = {
      "assets/logo.svg": {
        type: "asset",
        fileName: "assets/logo.svg",
        originalFileNames: ["app/assets/logo.svg", "app/assets/logo.svg"],
      },
    }
    expect(createNamedManifest(aliases, context)).toEqual({
      "logo.svg": "assets/logo.svg",
    })

    const conflict: BuildBundle = {
      "assets/application.js": {
        type: "chunk",
        fileName: "assets/application.js",
        name: "application",
        isEntry: true,
      },
      "assets/source.js": {
        type: "asset",
        fileName: "assets/source.js",
        originalFileNames: ["app/assets/application.js"],
      },
    }
    expect(() => createNamedManifest(conflict, context)).toThrow(
      'conflicting outputs for logical name "application.js"',
    )
  })

  it("exposes the complete represented-output set for bundle completion", () => {
    expect(
      representedOutputs({
        "application.js": "assets/application.js",
        "application.css": ["assets/reset.css", "assets/application.css"],
      }),
    ).toEqual(
      new Set(["assets/application.js", "assets/reset.css", "assets/application.css"]),
    )
  })

  it("serializes with two spaces and one trailing newline", () => {
    expect(serializeManifest({ "application.js": "assets/application.js" })).toBe(
      '{\n  "application.js": "assets/application.js"\n}\n',
    )
  })
})
