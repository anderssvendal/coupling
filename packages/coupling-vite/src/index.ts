import type { Plugin, ResolvedConfig } from "vite";

import {
  createManifest,
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
  root: string;
  sourceRoot: string;
  unsupportedReason?: string;
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
        root: config.root,
        sourceRoot: resolveSourceRoot(config.root, options.sourceRoot),
        unsupportedReason: unsupportedBuildReason(config),
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
      if (context.unsupportedReason !== undefined) {
        this.error(context.unsupportedReason);
        return;
      }

      try {
        if (hasOutputFileName(bundle as BuildBundle, context.fileName)) {
          throw new Error(
            `fileName conflicts with emitted output ${JSON.stringify(context.fileName)}`,
          );
        }

        const manifest = createManifest(bundle as BuildBundle, {
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

function unsupportedBuildReason(config: ResolvedConfig): string | undefined {
  if (config.build.ssr) {
    return "Coupling does not support Vite SSR builds";
  }
  if (config.build.lib) {
    return "Coupling does not support Vite library builds";
  }
  if (Array.isArray(config.build.rollupOptions.output)) {
    return "Coupling does not support multiple Rollup outputs";
  }

  return undefined;
}

function hasOutputFileName(bundle: BuildBundle, fileName: string): boolean {
  return Object.values(bundle).map(outputFileName).includes(fileName);
}

function outputFileName(output: BuildBundle[string]): string {
  return output.fileName;
}
