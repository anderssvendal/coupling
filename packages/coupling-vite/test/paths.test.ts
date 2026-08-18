import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  resolveSourceRoot,
  sourceLogicalName,
  validateManifestFileName,
} from "../src/paths.js";

describe("validateManifestFileName", () => {
  it("accepts safe relative output paths", () => {
    expect(validateManifestFileName("manifest.json")).toBe("manifest.json");
    expect(validateManifestFileName("metadata/coupling.json")).toBe(
      "metadata/coupling.json",
    );
  });

  it.each([
    "",
    "/manifest.json",
    "C:/manifest.json",
    "../manifest.json",
    "metadata/../manifest.json",
    "./manifest.json",
    "metadata//manifest.json",
    "metadata\\manifest.json",
  ])("rejects unsafe fileName %j", (fileName) => {
    expect(() => validateManifestFileName(fileName)).toThrow(/fileName/);
  });
});

describe("source paths", () => {
  it("resolves relative source roots from the Vite root", () => {
    expect(resolveSourceRoot("/repo", "app/assets")).toBe(
      path.resolve("/repo/app/assets"),
    );
    expect(resolveSourceRoot("/repo")).toBe(path.resolve("/repo"));
  });

  it("derives nested logical names beneath sourceRoot", () => {
    expect(
      sourceLogicalName(
        "app/assets/images/logo.svg",
        "/repo/app/assets",
        "/repo",
      ),
    ).toBe("images/logo.svg");
    expect(
      sourceLogicalName(
        "/repo/app/assets/fonts/body.woff2",
        "/repo/app/assets",
        "/repo",
      ),
    ).toBe("fonts/body.woff2");
  });

  it("normalizes Windows source paths to forward slashes", () => {
    expect(
      sourceLogicalName(
        "C:\\repo\\app\\assets\\images\\logo.svg",
        "C:\\repo\\app\\assets",
        "C:\\repo",
      ),
    ).toBe("images/logo.svg");
  });

  it("does not expose files outside sourceRoot", () => {
    expect(
      sourceLogicalName("/repo/vendor/logo.svg", "/repo/app/assets", "/repo"),
    ).toBeUndefined();
  });
});
