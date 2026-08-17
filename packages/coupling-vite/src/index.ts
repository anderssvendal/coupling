import path from "node:path";

import type { Plugin, ResolvedConfig } from "vite";

import {
  createNamedManifest,
  serializeManifest,
  type BuildBundle,
} from "./manifest.js";
import { resolveSourceRoot, validateManifestFileName } from "./paths.js";

export interface CouplingOptions {
  fileName?: string;
  sourceRoot?: string;
}

interface BuildContext {
  fileName: string;
  isClientBuild: boolean;
  outDir: string;
  root: string;
  sourceRoot: string;
  sourcemap: ResolvedConfig["build"]["sourcemap"];
}

export function coupling(options: CouplingOptions = {}): Plugin {
  const fileName = validateManifestFileName(
    options.fileName ?? "manifest.json",
  );
  let buildContext: BuildContext | undefined;

  return {
    name: "coupling",
    apply: "build",

    configResolved(config) {
      buildContext = {
        fileName,
        isClientBuild: config.command === "build" && !config.build.ssr,
        outDir: path.resolve(config.root, config.build.outDir),
        root: config.root,
        sourceRoot: resolveSourceRoot(config.root, options.sourceRoot),
        sourcemap: config.build.sourcemap,
      };
    },

    generateBundle(_outputOptions, bundle) {
      const context = buildContext;
      if (context === undefined) {
        this.error(
          "Coupling did not receive Vite's resolved build configuration",
        );
        return;
      }
      if (!context.isClientBuild) {
        return;
      }

      try {
        if (hasOutputFileName(bundle as BuildBundle, context.fileName)) {
          throw new Error(
            `fileName conflicts with emitted output ${JSON.stringify(context.fileName)}`,
          );
        }

        const manifest = createNamedManifest(bundle as BuildBundle, {
          sourceRoot: context.sourceRoot,
          viteRoot: context.root,
        });

        this.emitFile({
          type: "asset",
          fileName: context.fileName,
          source: serializeManifest(manifest),
        });
      } catch (error) {
        this.error(error instanceof Error ? error : String(error));
      }
    },
  };
}

export default coupling;

function hasOutputFileName(bundle: BuildBundle, fileName: string): boolean {
  return Object.values(bundle).map(outputFileName).includes(fileName);
}

function outputFileName(output: BuildBundle[string]): string {
  return output.fileName;
}
