import { execFileSync } from "node:child_process";
import { cp, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { build } from "vite";
import { describe, expect, it } from "vitest";

import couplingDefault, {
  coupling,
  type CouplingOptions,
} from "../src/index.js";

type CouplingManifest = Record<string, string | string[]>;
type SourcemapMode = false | true | "hidden" | "inline";

const packageRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repositoryRoot = path.resolve(packageRoot, "../..");
const fixturesRoot = path.join(packageRoot, "test/fixtures");
const completeInputs = {
  application: "src/application.ts",
  admin: "src/admin.ts",
};

describe("coupling plugin", () => {
  it("exports the same default and named plugin function", () => {
    expect(couplingDefault).toBe(coupling);
    const options: CouplingOptions = { fileName: "metadata/coupling.json" };
    expect(coupling(options).name).toBe("coupling");
  });

  it("emits a named JS entry for a write:false build without Vite's manifest", async () => {
    const result = await fixtureBuild("js-only");

    expect(result.manifest).toEqual({
      "application.js": result.entryFile("application"),
    });
    expect(result.fileNames).toContain("manifest.json");
    expect(result.fileNames).not.toContain(".vite/manifest.json");
  });

  it("emits entry CSS and a source-relative static asset", async () => {
    const result = await fixtureBuild("assets", { sourceRoot: "src" });

    expect(result.manifest["application.js"]).toBe(
      result.entryFile("application"),
    );
    expect(result.manifest["application.css"]).toMatch(/^assets\/.*\.css$/);
    expect(result.manifest["images/logo.svg"]).toMatch(/^assets\/.*\.svg$/);
  });

  it("defaults sourceRoot to Vite's resolved root", async () => {
    const result = await fixtureBuild("assets");

    expect(result.manifest["src/images/logo.svg"]).toMatch(/^assets\/.*\.svg$/);
  });

  it("does not invent a manifest entry for an inlined asset", async () => {
    const result = await fixtureBuild(
      "assets",
      { sourceRoot: "src" },
      undefined,
      100_000,
    );

    expect(result.manifest["images/logo.svg"]).toBeUndefined();
    expect(result.fileNames.some((fileName) => fileName.endsWith(".svg"))).toBe(
      false,
    );
  });

  it("includes shared static-chunk CSS in every dependent entry", async () => {
    const result = await fixtureBuild("shared-css", {}, completeInputs);
    const applicationCss = outputsFor(result.manifest["application.css"]);
    const adminCss = outputsFor(result.manifest["admin.css"]);
    const sharedCss = applicationCss[0];

    expect(result.manifest["application.js"]).toBe(
      result.entryFile("application"),
    );
    expect(result.manifest["admin.js"]).toBe(result.entryFile("admin"));
    expect(applicationCss).toHaveLength(2);
    expect(adminCss).toHaveLength(2);
    expect(adminCss[0]).toBe(sharedCss);
    expect(applicationCss[1]).not.toBe(adminCss[1]);
    expect(new Set(applicationCss).size).toBe(applicationCss.length);
    expect(new Set(adminCss).size).toBe(adminCss.length);
    expect(anonymousOutputs(result.manifest)).not.toContain(sharedCss);
    expect(
      manifestValues(result.manifest).filter((output) => output === sharedCss),
    ).toHaveLength(2);
  });

  it("covers shared chunks, dynamic chunks, CSS, and outside-root assets", async () => {
    const result = await fixtureBuild(
      "complete",
      { sourceRoot: "src" },
      completeInputs,
    );
    const anonymous = anonymousOutputs(result.manifest);
    const browserManagedChunks = result.outputs
      .filter((output) => output.type === "chunk" && !output.isEntry)
      .map((output) => output.fileName);
    const namedLogo = singleOutput(result.manifest["images/logo.svg"]);
    const outsideAsset = result.fileNames.find(
      (fileName) => fileName.endsWith(".svg") && fileName !== namedLogo,
    );
    if (outsideAsset === undefined) {
      throw new Error("Expected an emitted asset outside sourceRoot");
    }

    expect(
      result.outputs.some(
        (output) => output.type === "chunk" && output.isDynamicEntry,
      ),
    ).toBe(true);
    expect(
      result.outputs.some(
        (output) =>
          output.type === "chunk" && !output.isEntry && !output.isDynamicEntry,
      ),
    ).toBe(true);
    expect(anonymous).toEqual(expect.arrayContaining(browserManagedChunks));
    expect(anonymous).toContain(outsideAsset);
    expect(anonymous).not.toContain(namedLogo);
    expect(anonymous.every((output) => !path.isAbsolute(output))).toBe(true);

    for (const chunk of browserManagedChunks) {
      expect(
        manifestValues(result.manifest).filter((value) => value === chunk),
      ).toHaveLength(1);
    }
    expect(representedRuntimeFiles(result)).toEqual(
      new Set(
        result.fileNames.filter((fileName) => fileName !== "manifest.json"),
      ),
    );
  });

  it.each([false, true, "hidden", "inline"] as SourcemapMode[])(
    "represents emitted source maps for sourcemap mode %j",
    async (sourcemap) => {
      const result = await fixtureBuild(
        "complete",
        { sourceRoot: "src" },
        completeInputs,
        0,
        { sourcemap },
      );
      const emittedMaps = result.fileNames.filter((fileName) =>
        fileName.endsWith(".map"),
      );
      const anonymous = result.manifest[""];

      if (sourcemap === true || sourcemap === "hidden") {
        expect(emittedMaps.length).toBeGreaterThan(0);
        expect(anonymous).toEqual(expect.arrayContaining(emittedMaps));
        expect(
          emittedMaps.every((fileName) => /\.(?:css|js)\.map$/.test(fileName)),
        ).toBe(true);
      } else {
        expect(emittedMaps).toEqual([]);
        expect(
          manifestValues(result.manifest).some((value) =>
            value.endsWith(".map"),
          ),
        ).toBe(false);
      }
    },
  );

  it("supports a custom safe manifest fileName", async () => {
    const result = await fixtureBuild("js-only", {
      fileName: "metadata/coupling.json",
    });

    expect(result.fileNames).toContain("metadata/coupling.json");
    expect(result.fileNames).not.toContain("manifest.json");
    expect(manifestValues(result.manifest)).not.toContain(
      "metadata/coupling.json",
    );
  });

  it("rejects unsafe manifest fileName values", () => {
    expect(() => coupling({ fileName: "../manifest.json" })).toThrow(
      /fileName/,
    );
  });

  it("fails when the manifest fileName conflicts with another output", async () => {
    const root = path.join(fixturesRoot, "js-only");

    await expect(
      build({
        root,
        logLevel: "silent",
        plugins: [
          {
            name: "manifest-collision",
            generateBundle() {
              this.emitFile({
                type: "asset",
                fileName: "manifest.json",
                source: "{}",
              });
            },
          },
          coupling(),
        ],
        build: {
          rollupOptions: { input: path.join(root, "src/application.ts") },
          write: false,
        },
      }),
    ).rejects.toThrow(/fileName conflicts with emitted output "manifest.json"/);
  });

  it("rejects unsupported SSR, library, and multiple-output builds", async () => {
    const root = path.join(fixturesRoot, "js-only");
    const entry = path.join(root, "src/application.ts");

    await expect(
      build({
        root,
        logLevel: "silent",
        plugins: [coupling()],
        build: { rollupOptions: { input: entry }, ssr: true, write: false },
      }),
    ).rejects.toThrow(/does not support Vite SSR builds/);

    await expect(
      build({
        root,
        logLevel: "silent",
        plugins: [coupling()],
        build: { lib: { entry, formats: ["es"] }, write: false },
      }),
    ).rejects.toThrow(/does not support Vite library builds/);

    await expect(
      build({
        root,
        logLevel: "silent",
        plugins: [coupling()],
        build: {
          rollupOptions: {
            input: entry,
            output: [{ format: "es" }, { format: "es" }],
          },
          write: false,
        },
      }),
    ).rejects.toThrow(/does not support multiple Rollup outputs/);
  });

  it("regenerates only current outputs during build watch", async () => {
    const temporaryRoot = await mkdtemp(
      path.join(tmpdir(), "coupling-vite-watch-"),
    );
    const root = path.join(temporaryRoot, "fixture");
    let watcher: BuildWatcher | undefined;

    try {
      await cp(path.join(fixturesRoot, "complete"), root, {
        recursive: true,
      });
      const buildResult = await build({
        root,
        logLevel: "silent",
        plugins: [coupling({ sourceRoot: "src" })],
        build: {
          assetsInlineLimit: 0,
          cssCodeSplit: true,
          emptyOutDir: true,
          minify: false,
          outDir: "dist",
          rollupOptions: {
            input: Object.fromEntries(
              Object.entries(completeInputs).map(([name, input]) => [
                name,
                path.join(root, input),
              ]),
            ),
          },
          watch: {},
        },
      });
      watcher = asBuildWatcher(buildResult);

      await waitForBuild(watcher);
      const initial = await readManifest(path.join(root, "dist/manifest.json"));
      const rebuild = waitForBuild(watcher);
      await writeFile(
        path.join(root, "src/shared.ts"),
        'import "./shared.css";\n\nexport const sharedMessage = "shared-v2";\n',
      );
      await rebuild;
      const regenerated = await readManifest(
        path.join(root, "dist/manifest.json"),
      );
      const initialJavascript = manifestValues(initial).filter((value) =>
        value.endsWith(".js"),
      );
      const regeneratedJavascript = manifestValues(regenerated).filter(
        (value) => value.endsWith(".js"),
      );
      const replaced = initialJavascript.filter(
        (value) => !regeneratedJavascript.includes(value),
      );

      expect(replaced.length).toBeGreaterThan(0);
      for (const replacedOutput of replaced) {
        expect(manifestValues(regenerated)).not.toContain(replacedOutput);
      }
      expect(regenerated["application.js"]).not.toBe(initial["application.js"]);
    } finally {
      await watcher?.close();
      await rm(temporaryRoot, { force: true, recursive: true });
    }
  }, 30_000);

  it("produces manifests that Ruby Coupling can find and serve", async () => {
    const temporaryRoot = await mkdtemp(
      path.join(tmpdir(), "coupling-vite-ruby-"),
    );
    const outDir = path.join(temporaryRoot, "assets");

    try {
      await fixtureBuild("complete", { sourceRoot: "src" }, completeInputs, 0, {
        outDir,
        sourcemap: true,
        write: true,
      });

      execFileSync(
        "bundle",
        ["exec", "ruby", "-Ilib", "-e", rubyIntegrationScript(), outDir],
        { cwd: repositoryRoot, stdio: "pipe" },
      );
    } finally {
      await rm(temporaryRoot, { force: true, recursive: true });
    }
  });
});

interface BuildOutput {
  fileName: string;
  type: "asset" | "chunk";
  name?: string;
  isEntry?: boolean;
  isDynamicEntry?: boolean;
  source?: string | Uint8Array;
}

interface FixtureBuildOverrides {
  outDir?: string;
  sourcemap?: SourcemapMode;
  write?: boolean;
}

interface FixtureBuildResult {
  manifest: CouplingManifest;
  fileNames: string[];
  outputs: BuildOutput[];
  entryFile(name: string): string;
}

async function fixtureBuild(
  fixtureName: string,
  options: CouplingOptions = {},
  inputs: Record<string, string> | undefined = {
    application: "src/application.ts",
  },
  assetsInlineLimit = 0,
  overrides: FixtureBuildOverrides = {},
): Promise<FixtureBuildResult> {
  const root = path.join(fixturesRoot, fixtureName);
  const buildResult = await build({
    root,
    logLevel: "silent",
    plugins: [coupling(options)],
    build: {
      assetsInlineLimit,
      cssCodeSplit: true,
      emptyOutDir: false,
      minify: false,
      outDir: overrides.outDir,
      rollupOptions: {
        input: Object.fromEntries(
          Object.entries(inputs ?? { application: "src/application.ts" }).map(
            ([name, input]) => [name, path.join(root, input)],
          ),
        ),
      },
      sourcemap: overrides.sourcemap,
      write: overrides.write ?? false,
    },
  });

  const rollupResults = Array.isArray(buildResult)
    ? buildResult
    : [buildResult];
  const outputs = rollupResults.flatMap(
    (result) => (result as { output: BuildOutput[] }).output,
  );
  const manifestFileName = options.fileName ?? "manifest.json";
  const manifestAsset = outputs.find(
    (output) => output.type === "asset" && output.fileName === manifestFileName,
  );
  if (manifestAsset?.source === undefined) {
    throw new Error("Coupling manifest was not emitted");
  }

  const manifest = JSON.parse(
    sourceString(manifestAsset.source),
  ) as CouplingManifest;

  return {
    manifest,
    fileNames: outputs.map((output) => output.fileName),
    outputs,
    entryFile(name: string): string {
      const entry = outputs.find(
        (output) =>
          output.type === "chunk" && output.isEntry && output.name === name,
      );
      if (entry === undefined) {
        throw new Error(`Missing entry chunk ${name}`);
      }
      return entry.fileName;
    },
  };
}

function manifestValues(manifest: CouplingManifest): string[] {
  return Object.values(manifest).flatMap((value) =>
    typeof value === "string" ? [value] : value,
  );
}

function singleOutput(value: string | string[] | undefined): string {
  if (typeof value !== "string") {
    throw new Error("Expected one named output");
  }
  return value;
}

function outputsFor(value: string | string[] | undefined): string[] {
  if (value === undefined) {
    throw new Error("Expected a named output");
  }
  return typeof value === "string" ? [value] : value;
}

function anonymousOutputs(manifest: CouplingManifest): string[] {
  const anonymous = manifest[""];
  if (!Array.isArray(anonymous)) {
    throw new Error("Expected an anonymous output array");
  }
  return anonymous;
}

function representedRuntimeFiles(result: FixtureBuildResult): Set<string> {
  const runtimeFiles = new Set(result.fileNames);
  runtimeFiles.delete("manifest.json");
  return new Set(
    manifestValues(result.manifest).filter((value) => runtimeFiles.has(value)),
  );
}

function sourceString(source: string | Uint8Array): string {
  return typeof source === "string" ? source : new TextDecoder().decode(source);
}

interface BuildWatcher {
  close(): Promise<void>;
  off(event: "event", listener: (event: BuildWatcherEvent) => void): void;
  on(event: "event", listener: (event: BuildWatcherEvent) => void): void;
}

interface BuildWatcherEvent {
  code: string;
  error?: Error;
}

function asBuildWatcher(value: unknown): BuildWatcher {
  if (
    typeof value !== "object" ||
    value === null ||
    !("on" in value) ||
    !("close" in value)
  ) {
    throw new Error("Vite did not return a build watcher");
  }
  return value as BuildWatcher;
}

function waitForBuild(watcher: BuildWatcher): Promise<void> {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      cleanup();
      reject(new Error("Timed out waiting for Vite watch build"));
    }, 15_000);
    const onEvent = (event: BuildWatcherEvent): void => {
      if (event.code === "END") {
        cleanup();
        resolve();
      } else if (event.code === "ERROR") {
        cleanup();
        reject(event.error ?? new Error("Vite watch build failed"));
      }
    };
    const cleanup = (): void => {
      clearTimeout(timeout);
      watcher.off("event", onEvent);
    };

    watcher.on("event", onEvent);
  });
}

async function readManifest(fileName: string): Promise<CouplingManifest> {
  return JSON.parse(await readFile(fileName, "utf8")) as CouplingManifest;
}

function rubyIntegrationScript(): string {
  return `
require "json"
require "rack/mock"
require "coupling"
require "coupling/rack/app"

assets_path = ARGV.fetch(0)
manifest_path = File.join(assets_path, "manifest.json")
manifest = JSON.parse(File.read(manifest_path))
anonymous = manifest.fetch("")
raise "missing anonymous chunk" unless anonymous.any? { |path| path.end_with?(".js") }
raise "missing anonymous source map" unless anonymous.any? { |path| path.end_with?(".map") }

Coupling.configure do |config|
  config.assets_path = assets_path
  config.manifest_path = manifest_path
  config.public_path = "/assets"
end

request = Rack::MockRequest.new(Coupling::Rack::App.new)
manifest.values.flatten.each do |output|
  Coupling.manifest.find(output)
  response = request.get("/#{output}")
  raise "failed to serve #{output}: #{response.status}" unless response.status == 200
end
raise "served an unlisted file" unless request.get("/assets/unlisted.js").status == 404
`;
}
