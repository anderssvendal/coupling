import { describe, expect, it } from "vitest";

import {
  createManifest,
  createNamedManifest,
  representedOutputs,
  serializeManifest,
  type BuildBundle,
} from "../src/manifest.js";

const context = {
  sourceRoot: "/repo/app/assets",
  viteRoot: "/repo",
};

describe("createManifest", () => {
  it("adds every unrepresented output to a final anonymous entry", () => {
    const bundle: BuildBundle = {
      "assets/application-A1.js": {
        type: "chunk",
        fileName: "assets/application-A1.js",
        name: "application",
        isEntry: true,
        viteMetadata: {
          importedCss: new Set(["assets/application-B2.css"]),
        },
      },
      "assets/application-B2.css": {
        type: "asset",
        fileName: "assets/application-B2.css",
        originalFileNames: ["app/assets/application.css"],
      },
      "assets/logo-C3.svg": {
        type: "asset",
        fileName: "assets/logo-C3.svg",
        originalFileNames: ["app/assets/images/logo.svg"],
      },
      "assets/shared-D4.js": {
        type: "chunk",
        fileName: "assets/shared-D4.js",
        name: "shared",
        isEntry: false,
      },
      "assets/lazy-E5.js": {
        type: "chunk",
        fileName: "assets/lazy-E5.js",
        name: "lazy",
        isEntry: false,
        isDynamicEntry: true,
      },
      "assets/vendor-F6.svg": {
        type: "asset",
        fileName: "assets/vendor-F6.svg",
        originalFileNames: ["vendor/logo.svg"],
      },
      "assets/application-A1.js.map": {
        type: "asset",
        fileName: "assets/application-A1.js.map",
        originalFileNames: ["app/assets/application.ts"],
      },
      "assets/generated-G7.css": {
        type: "asset",
        fileName: "assets/generated-G7.css",
        originalFileNames: ["app/assets/generated.css"],
      },
    };

    expect(createManifest(bundle, context)).toEqual({
      "application.js": "assets/application-A1.js",
      "application.css": "assets/application-B2.css",
      "images/logo.svg": "assets/logo-C3.svg",
      "": [
        "assets/shared-D4.js",
        "assets/lazy-E5.js",
        "assets/vendor-F6.svg",
        "assets/application-A1.js.map",
        "assets/generated-G7.css",
      ],
    });
  });

  it("omits the anonymous entry when named values cover the bundle", () => {
    const bundle: BuildBundle = {
      "assets/application.js": {
        type: "chunk",
        fileName: "assets/application.js",
        name: "application",
        isEntry: true,
      },
    };

    expect(createManifest(bundle, context)).toEqual({
      "application.js": "assets/application.js",
    });
  });

  it("shares ordered static dependency CSS between entries and leaves dynamic-only CSS anonymous", () => {
    const bundle: BuildBundle = {
      "assets/admin.js": {
        type: "chunk",
        fileName: "assets/admin.js",
        name: "admin",
        isEntry: true,
        imports: ["assets/shared.js"],
        viteMetadata: { importedCss: new Set(["assets/admin.css"]) },
      },
      "assets/guide.js": {
        type: "chunk",
        fileName: "assets/guide.js",
        name: "guide",
        isEntry: true,
        imports: ["assets/shared.js"],
        viteMetadata: { importedCss: new Set(["assets/guide.css"]) },
      },
      "assets/shared.js": {
        type: "chunk",
        fileName: "assets/shared.js",
        name: "shared",
        isEntry: false,
        imports: ["assets/base.js"],
        viteMetadata: {
          importedCss: [
            "assets/shared.css",
            "assets/base.css",
            "assets/shared.css",
          ],
        },
      },
      "assets/base.js": {
        type: "chunk",
        fileName: "assets/base.js",
        name: "base",
        isEntry: false,
        viteMetadata: { importedCss: new Set(["assets/base.css"]) },
      },
      "assets/lazy.js": {
        type: "chunk",
        fileName: "assets/lazy.js",
        name: "lazy",
        isEntry: false,
        isDynamicEntry: true,
        imports: ["assets/lazy-support.js"],
        viteMetadata: { importedCss: new Set(["assets/lazy.css"]) },
      },
      "assets/lazy-support.js": {
        type: "chunk",
        fileName: "assets/lazy-support.js",
        name: "lazy-support",
        isEntry: false,
        viteMetadata: { importedCss: new Set(["assets/lazy-support.css"]) },
      },
      ...Object.fromEntries(
        [
          "admin.css",
          "guide.css",
          "shared.css",
          "base.css",
          "lazy.css",
          "lazy-support.css",
        ].map((fileName) => [
          `assets/${fileName}`,
          { type: "asset" as const, fileName: `assets/${fileName}` },
        ]),
      ),
    };

    expect(createManifest(bundle, context)).toEqual({
      "admin.js": "assets/admin.js",
      "admin.css": ["assets/base.css", "assets/shared.css", "assets/admin.css"],
      "guide.js": "assets/guide.js",
      "guide.css": ["assets/base.css", "assets/shared.css", "assets/guide.css"],
      "": [
        "assets/shared.js",
        "assets/base.js",
        "assets/lazy.js",
        "assets/lazy-support.js",
        "assets/lazy.css",
        "assets/lazy-support.css",
      ],
    });
  });
});

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
    };

    expect(createNamedManifest(bundle, context)).toEqual({
      "application.js": "assets/application-A1.js",
      "application.css": ["assets/reset-B2.css", "assets/application-C3.css"],
      "images/logo.svg": "assets/logo-D4.svg",
      "branding/logo.svg": "assets/logo-D4.svg",
      "fonts/body.woff2": "assets/body-E5.woff2",
    });
  });

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
    };

    expect(createNamedManifest(bundle, context)).toEqual({
      "application.js": "assets/application.js",
      "application.css": "assets/application.css",
      "admin.js": "assets/admin.js",
    });
  });

  it("deduplicates identical mappings and rejects conflicts", () => {
    const aliases: BuildBundle = {
      "assets/logo.svg": {
        type: "asset",
        fileName: "assets/logo.svg",
        originalFileNames: ["app/assets/logo.svg", "app/assets/logo.svg"],
      },
    };
    expect(createNamedManifest(aliases, context)).toEqual({
      "logo.svg": "assets/logo.svg",
    });

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
    };
    expect(() => createNamedManifest(conflict, context)).toThrow(
      'conflicting outputs for logical name "application.js"',
    );
  });

  it("exposes the complete represented-output set for bundle completion", () => {
    expect(
      representedOutputs({
        "application.js": "assets/application.js",
        "application.css": ["assets/reset.css", "assets/application.css"],
      }),
    ).toEqual(
      new Set([
        "assets/application.js",
        "assets/reset.css",
        "assets/application.css",
      ]),
    );
  });

  it("serializes with two spaces and one trailing newline", () => {
    expect(
      serializeManifest({ "application.js": "assets/application.js" }),
    ).toBe('{\n  "application.js": "assets/application.js"\n}\n');
  });
});
