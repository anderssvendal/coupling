import { cp, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { build as build5 } from "vite-5";
import { build as build6 } from "vite-6";
import { build as build7 } from "vite-7";
import { describe, expect, it } from "vitest";

import coupling from "../src/index.js";

type CouplingManifest = Record<string, string | string[]>;
type SourcemapMode = false | true | "hidden" | "inline";
type BuildFunction = (config: Record<string, unknown>) => Promise<unknown>;

interface BuildOutput {
  fileName: string;
  type: "asset" | "chunk";
  name?: string;
  isEntry?: boolean;
  isDynamicEntry?: boolean;
  source?: string | Uint8Array;
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

const packageRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const fixtureRoot = path.join(packageRoot, "test/fixtures/complete");
const inputs = {
  application: "src/application.ts",
  admin: "src/admin.ts",
};
const versions: Array<[string, BuildFunction]> = [
  ["Vite 5", build5 as unknown as BuildFunction],
  ["Vite 6", build6 as unknown as BuildFunction],
  ["Vite 7", build7 as unknown as BuildFunction],
];

describe.each(versions)("%s compatibility", (_version, viteBuild) => {
  it("covers entries, CSS, static assets, and code splitting", async () => {
    const result = await completeBuild(viteBuild);
    const anonymous = anonymousOutputs(result.manifest);
    const browserManagedChunks = result.outputs
      .filter((output) => output.type === "chunk" && !output.isEntry)
      .map((output) => output.fileName);
    const namedLogo = singleOutput(result.manifest["images/logo.svg"]);
    const outsideAsset = result.fileNames.find(
      (fileName) => fileName.endsWith(".svg") && fileName !== namedLogo,
    );

    expect(result.manifest["application.js"]).toBeDefined();
    expect(result.manifest["admin.js"]).toBeDefined();
    expect(result.manifest["application.css"]).toBeDefined();
    expect(result.manifest["admin.css"]).toBeDefined();
    expect(browserManagedChunks.length).toBeGreaterThan(0);
    expect(anonymous).toEqual(expect.arrayContaining(browserManagedChunks));
    expect(outsideAsset).toBeDefined();
    expect(anonymous).toContain(outsideAsset);
    expect(anonymous).not.toContain(namedLogo);
    expect(representedRuntimeFiles(result)).toEqual(
      new Set(
        result.fileNames.filter((fileName) => fileName !== "manifest.json"),
      ),
    );
  });

  it.each([false, true, "hidden", "inline"] as SourcemapMode[])(
    "handles sourcemap mode %j",
    async (sourcemap) => {
      const result = await completeBuild(viteBuild, sourcemap);
      const emittedMaps = result.fileNames.filter((fileName) =>
        fileName.endsWith(".map"),
      );

      if (sourcemap === true || sourcemap === "hidden") {
        expect(emittedMaps.length).toBeGreaterThan(0);
        expect(anonymousOutputs(result.manifest)).toEqual(
          expect.arrayContaining(emittedMaps),
        );
      } else {
        expect(emittedMaps).toEqual([]);
        expect(
          manifestValues(result.manifest).some((fileName) =>
            fileName.endsWith(".map"),
          ),
        ).toBe(false);
      }
    },
  );

  it("replaces the manifest during build watch", async () => {
    const temporaryRoot = await mkdtemp(
      path.join(tmpdir(), "coupling-vite-compatibility-watch-"),
    );
    const root = path.join(temporaryRoot, "fixture");
    let watcher: BuildWatcher | undefined;

    try {
      await cp(fixtureRoot, root, { recursive: true });
      watcher = asBuildWatcher(
        await viteBuild({
          root,
          logLevel: "silent",
          plugins: [coupling({ sourceRoot: "src" })],
          build: buildOptions(root, { watch: {} }),
        }),
      );

      await waitForBuild(watcher);
      const initial = await readManifest(path.join(root, "dist/manifest.json"));
      const rebuild = waitForBuild(watcher);
      await writeFile(
        path.join(root, "src/shared.ts"),
        'import "./shared.css";\n\nexport const sharedMessage = "compatibility-v2";\n',
      );
      await rebuild;
      const regenerated = await readManifest(
        path.join(root, "dist/manifest.json"),
      );
      const regeneratedValues = manifestValues(regenerated);
      const replacedOutputs = manifestValues(initial).filter(
        (output) => !regeneratedValues.includes(output),
      );

      expect(replacedOutputs.length).toBeGreaterThan(0);
      expect(regenerated["application.js"]).not.toBe(initial["application.js"]);
      for (const replacedOutput of replacedOutputs) {
        expect(regeneratedValues).not.toContain(replacedOutput);
      }
    } finally {
      await watcher?.close();
      await rm(temporaryRoot, { force: true, recursive: true });
    }
  }, 30_000);
});

interface CompleteBuildResult {
  manifest: CouplingManifest;
  fileNames: string[];
  outputs: BuildOutput[];
}

async function completeBuild(
  viteBuild: BuildFunction,
  sourcemap: SourcemapMode = false,
): Promise<CompleteBuildResult> {
  const buildResult = await viteBuild({
    root: fixtureRoot,
    logLevel: "silent",
    plugins: [coupling({ sourceRoot: "src" })],
    build: {
      ...buildOptions(fixtureRoot),
      sourcemap,
      write: false,
    },
  });
  const rollupResults = Array.isArray(buildResult)
    ? buildResult
    : [buildResult];
  const outputs = rollupResults.flatMap(
    (result) => (result as { output: BuildOutput[] }).output,
  );
  const manifestAsset = outputs.find(
    (output) => output.type === "asset" && output.fileName === "manifest.json",
  );
  if (manifestAsset?.source === undefined) {
    throw new Error("Coupling manifest was not emitted");
  }

  return {
    manifest: JSON.parse(
      sourceString(manifestAsset.source),
    ) as CouplingManifest,
    fileNames: outputs.map((output) => output.fileName),
    outputs,
  };
}

function buildOptions(
  root: string,
  additional: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    assetsInlineLimit: 0,
    cssCodeSplit: true,
    emptyOutDir: true,
    minify: false,
    outDir: "dist",
    rollupOptions: {
      input: Object.fromEntries(
        Object.entries(inputs).map(([name, input]) => [
          name,
          path.join(root, input),
        ]),
      ),
    },
    ...additional,
  };
}

function manifestValues(manifest: CouplingManifest): string[] {
  return Object.values(manifest).flatMap((value) =>
    typeof value === "string" ? [value] : value,
  );
}

function anonymousOutputs(manifest: CouplingManifest): string[] {
  const anonymous = manifest[""];
  if (!Array.isArray(anonymous)) {
    throw new Error("Expected an anonymous output array");
  }
  return anonymous;
}

function singleOutput(value: string | string[] | undefined): string {
  if (typeof value !== "string") {
    throw new Error("Expected one named output");
  }
  return value;
}

function representedRuntimeFiles(result: CompleteBuildResult): Set<string> {
  const runtimeFiles = new Set(result.fileNames);
  runtimeFiles.delete("manifest.json");
  return new Set(
    manifestValues(result.manifest).filter((value) => runtimeFiles.has(value)),
  );
}

function sourceString(source: string | Uint8Array): string {
  return typeof source === "string" ? source : new TextDecoder().decode(source);
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
