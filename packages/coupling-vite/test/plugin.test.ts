import path from "node:path"
import { fileURLToPath } from "node:url"

import { build } from "vite"
import { describe, expect, it } from "vitest"

import couplingDefault, { coupling, type CouplingOptions } from "../src/index.js"
import type { CouplingManifest } from "../src/manifest.js"

const fixturesRoot = path.join(path.dirname(fileURLToPath(import.meta.url)), "fixtures")

describe("coupling plugin", () => {
  it("exports the same default and named plugin function", () => {
    expect(couplingDefault).toBe(coupling)
    const options: CouplingOptions = { fileName: "metadata/coupling.json" }
    expect(coupling(options).name).toBe("coupling")
  })

  it("emits a named JS entry for a write:false build without Vite's manifest", async () => {
    const result = await fixtureBuild("js-only")

    expect(result.manifest).toEqual({
      "application.js": result.entryFile("application"),
    })
    expect(result.fileNames).toContain("manifest.json")
    expect(result.fileNames).not.toContain(".vite/manifest.json")
  })

  it("emits entry CSS and a source-relative static asset", async () => {
    const result = await fixtureBuild("assets", { sourceRoot: "src" })

    expect(result.manifest["application.js"]).toBe(result.entryFile("application"))
    expect(result.manifest["application.css"]).toMatch(/^assets\/.*\.css$/)
    expect(result.manifest["images/logo.svg"]).toMatch(/^assets\/.*\.svg$/)
  })

  it("defaults sourceRoot to Vite's resolved root", async () => {
    const result = await fixtureBuild("assets")

    expect(result.manifest["src/images/logo.svg"]).toMatch(/^assets\/.*\.svg$/)
  })

  it("does not invent a manifest entry for an inlined asset", async () => {
    const result = await fixtureBuild("assets", { sourceRoot: "src" }, undefined, 100_000)

    expect(result.manifest["images/logo.svg"]).toBeUndefined()
    expect(result.fileNames.some((fileName) => fileName.endsWith(".svg"))).toBe(false)
  })

  it("emits CSS mappings for multiple entries that import shared CSS", async () => {
    const result = await fixtureBuild("shared-css", {}, {
      application: "src/application.ts",
      admin: "src/admin.ts",
    })

    expect(result.manifest["application.js"]).toBe(result.entryFile("application"))
    expect(result.manifest["admin.js"]).toBe(result.entryFile("admin"))
    expect(result.manifest["application.css"]).toBeDefined()
    expect(result.manifest["admin.css"]).toBeDefined()
  })

  it("supports a custom safe manifest fileName", async () => {
    const result = await fixtureBuild("js-only", { fileName: "metadata/coupling.json" })

    expect(result.fileNames).toContain("metadata/coupling.json")
    expect(result.fileNames).not.toContain("manifest.json")
  })

  it("rejects unsafe manifest fileName values", () => {
    expect(() => coupling({ fileName: "../manifest.json" })).toThrow(/fileName/)
  })

  it("fails when the manifest fileName conflicts with another output", async () => {
    const root = path.join(fixturesRoot, "js-only")

    await expect(
      build({
        root,
        logLevel: "silent",
        plugins: [
          {
            name: "manifest-collision",
            generateBundle() {
              this.emitFile({ type: "asset", fileName: "manifest.json", source: "{}" })
            },
          },
          coupling(),
        ],
        build: {
          rollupOptions: { input: path.join(root, "src/application.ts") },
          write: false,
        },
      }),
    ).rejects.toThrow(/fileName conflicts with emitted output "manifest.json"/)
  })
})

interface BuildOutput {
  fileName: string
  type: "asset" | "chunk"
  name?: string
  isEntry?: boolean
  source?: string | Uint8Array
}

async function fixtureBuild(
  fixtureName: string,
  options: CouplingOptions = {},
  inputs: Record<string, string> | undefined = { application: "src/application.ts" },
  assetsInlineLimit = 0,
): Promise<{
  manifest: CouplingManifest
  fileNames: string[]
  entryFile(name: string): string
}> {
  const root = path.join(fixturesRoot, fixtureName)
  const buildResult = await build({
    root,
    logLevel: "silent",
    plugins: [coupling(options)],
    build: {
      assetsInlineLimit,
      cssCodeSplit: true,
      emptyOutDir: false,
      minify: false,
      rollupOptions: {
        input: Object.fromEntries(
          Object.entries(inputs ?? { application: "src/application.ts" }).map(([name, input]) => [
            name,
            path.join(root, input),
          ]),
        ),
      },
      write: false,
    },
  })

  const rollupResults = Array.isArray(buildResult) ? buildResult : [buildResult]
  const outputs = rollupResults.flatMap(
    (result) => (result as { output: BuildOutput[] }).output,
  )
  const manifestFileName = options.fileName ?? "manifest.json"
  const manifestAsset = outputs.find(
    (output) => output.type === "asset" && output.fileName === manifestFileName,
  )
  if (manifestAsset?.source === undefined) throw new Error("Coupling manifest was not emitted")

  const manifest = JSON.parse(sourceString(manifestAsset.source)) as CouplingManifest

  return {
    manifest,
    fileNames: outputs.map((output) => output.fileName),
    entryFile(name: string): string {
      const entry = outputs.find(
        (output) => output.type === "chunk" && output.isEntry && output.name === name,
      )
      if (entry === undefined) throw new Error(`Missing entry chunk ${name}`)
      return entry.fileName
    },
  }
}

function sourceString(source: string | Uint8Array): string {
  return typeof source === "string" ? source : new TextDecoder().decode(source)
}
