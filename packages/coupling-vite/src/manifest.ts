import path from "node:path";

import {
  sourceLogicalName,
  validateLogicalName,
  validateOutputPath,
} from "./paths.js";

type ManifestValue = string | string[];
type CouplingManifest = Record<string, ManifestValue>;

interface ManifestContext {
  sourceRoot: string;
  viteRoot: string;
}

interface BundleChunk {
  type: "chunk";
  fileName: string;
  name: string;
  isEntry: boolean;
  isDynamicEntry?: boolean;
  viteMetadata?: unknown;
}

interface BundleAsset {
  type: "asset";
  fileName: string;
  originalFileName?: string | null;
  originalFileNames?: string[];
}

export type BuildBundle = Record<string, BundleChunk | BundleAsset>;

interface ViteChunkMetadata {
  importedCss: Iterable<string>;
}

export function createNamedManifest(
  bundle: BuildBundle,
  context: ManifestContext,
): CouplingManifest {
  const outputs = Object.values(bundle);
  const entries = outputs.reduce(addEntryOutput, new NamedEntries());
  const assetAccumulator = outputs.reduce(addAssetOutput, {
    context,
    entries,
    representedOutputs: entries.representedOutputs(),
  });

  return assetAccumulator.entries.toManifest();
}

function addEntryOutput(
  entries: NamedEntries,
  output: BuildBundle[string],
): NamedEntries {
  if (output.type !== "chunk" || !output.isEntry || output.isDynamicEntry) {
    return entries;
  }

  const outputPath = validateOutputPath(output.fileName);
  const extension = path.posix.extname(outputPath);
  if (extension.length === 0) {
    throw new Error(
      `entry chunk has no file extension: ${JSON.stringify(outputPath)}`,
    );
  }

  const logicalBase = output.name.endsWith(extension)
    ? output.name.slice(0, -extension.length)
    : output.name;
  const javascriptName = validateLogicalName(`${logicalBase}${extension}`);
  entries.add(javascriptName, [outputPath]);

  const css = importedCss(output).map(validateOutputPath).filter(stableUnique);
  if (css.length > 0) {
    entries.add(validateLogicalName(`${logicalBase}.css`), css);
  }

  return entries;
}

interface AssetAccumulator {
  context: ManifestContext;
  entries: NamedEntries;
  representedOutputs: Set<string>;
}

function addAssetOutput(
  accumulator: AssetAccumulator,
  output: BuildBundle[string],
): AssetAccumulator {
  if (
    output.type !== "asset" ||
    accumulator.representedOutputs.has(output.fileName)
  ) {
    return accumulator;
  }

  originalFileNames(output).reduce(addAssetAlias, {
    context: accumulator.context,
    entries: accumulator.entries,
    outputPath: validateOutputPath(output.fileName),
  });

  return accumulator;
}

interface AssetAliasAccumulator {
  context: ManifestContext;
  entries: NamedEntries;
  outputPath: string;
}

function addAssetAlias(
  accumulator: AssetAliasAccumulator,
  originalFileName: string,
): AssetAliasAccumulator {
  const logicalName = sourceLogicalName(
    originalFileName,
    accumulator.context.sourceRoot,
    accumulator.context.viteRoot,
  );
  if (logicalName === undefined) {
    return accumulator;
  }

  accumulator.entries.add(validateLogicalName(logicalName), [
    accumulator.outputPath,
  ]);
  return accumulator;
}

export function representedOutputs(manifest: CouplingManifest): Set<string> {
  return new Set(
    Object.values(manifest).flatMap((value) =>
      typeof value === "string" ? [value] : value,
    ),
  );
}

export function serializeManifest(manifest: CouplingManifest): string {
  return `${JSON.stringify(manifest, null, 2)}\n`;
}

class NamedEntries {
  readonly #entries = new Map<string, string[]>();

  add(name: string, outputs: string[]): void {
    const normalized = outputs.filter(stableUnique);
    const existing = this.#entries.get(name);
    if (existing === undefined) {
      this.#entries.set(name, normalized);
      return;
    }
    if (sameValues(existing, normalized)) {
      return;
    }

    throw new Error(
      `conflicting outputs for logical name ${JSON.stringify(name)}`,
    );
  }

  representedOutputs(): Set<string> {
    return new Set([...this.#entries.values()].flat());
  }

  toManifest(): CouplingManifest {
    return Object.fromEntries(
      [...this.#entries].map(([name, outputs]) => [
        name,
        outputs.length === 1 ? outputs[0] : outputs,
      ]),
    );
  }
}

function importedCss(chunk: BundleChunk): string[] {
  const metadata = viteMetadata(chunk.viteMetadata);
  return metadata === undefined ? [] : [...metadata.importedCss];
}

function viteMetadata(value: unknown): ViteChunkMetadata | undefined {
  if (
    typeof value !== "object" ||
    value === null ||
    !("importedCss" in value)
  ) {
    return undefined;
  }

  const importedCss = value.importedCss;
  if (importedCss === null || importedCss === undefined) {
    return undefined;
  }
  if (!(Symbol.iterator in Object(importedCss))) {
    return undefined;
  }

  return { importedCss: importedCss as Iterable<string> };
}

function originalFileNames(asset: BundleAsset): string[] {
  if (asset.originalFileNames !== undefined) {
    return asset.originalFileNames.filter(stableUnique);
  }
  return asset.originalFileName === null || asset.originalFileName === undefined
    ? []
    : [asset.originalFileName];
}

function stableUnique(value: string, index: number, values: string[]): boolean {
  return values.indexOf(value) === index;
}

function sameValues(left: string[], right: string[]): boolean {
  return (
    left.length === right.length &&
    left.every((value, index) => value === right[index])
  );
}
