import { spawnSync } from "node:child_process";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repositoryRoot = path.resolve(packageRoot, "../..");
const packageJson = JSON.parse(
  readFileSync(path.join(packageRoot, "package.json"), "utf8"),
);
const expectedFiles = [
  "dist/index.d.ts",
  "dist/index.js",
  "dist/manifest.d.ts",
  "dist/manifest.js",
  "dist/paths.d.ts",
  "dist/paths.js",
  "LICENSE.txt",
  "package.json",
  "README.md",
];

assertPackageMetadata(packageJson);

const dryRun = JSON.parse(
  capture("pnpm", ["pack", "--dry-run", "--json"], packageRoot),
);
const packedFiles = dryRun.files
  .map((file) => file.path)
  .sort((left, right) => left.localeCompare(right));
assertEqual(
  packedFiles,
  expectedFiles,
  "Packed files differ from the intentional package allowlist",
);

const temporaryRoot = mkdtempSync(
  path.join(tmpdir(), "coupling-vite-package-audit-"),
);

try {
  run("pnpm", ["pack", "--pack-destination", temporaryRoot], packageRoot);
  const tarball = path.join(
    temporaryRoot,
    `${packageJson.name}-${packageJson.version}.tgz`,
  );
  const consumerRoot = path.join(temporaryRoot, "consumer");
  writeConsumer(consumerRoot, tarball);

  run("pnpm", ["install", "--ignore-workspace", "--no-lockfile"], consumerRoot);
  run("node", ["import-check.mjs"], consumerRoot);
  run("pnpm", ["exec", "tsc", "--noEmit"], consumerRoot);
  run("pnpm", ["exec", "vite", "build"], consumerRoot);
  run(
    "bundle",
    [
      "exec",
      "ruby",
      "-Ilib",
      "-e",
      rubyManifestCheck(),
      path.join(consumerRoot, "dist"),
    ],
    repositoryRoot,
  );

  console.log(`Audited ${dryRun.filename}`);
  console.log(`Files: ${packedFiles.length}`);
  console.log(
    "Isolated ESM import, declaration, Vite build, and Ruby checks passed",
  );
} finally {
  rmSync(temporaryRoot, { force: true, recursive: true });
}

function assertPackageMetadata(metadata) {
  assertEqual(metadata.engines, { node: ">=20.19" }, "Unexpected Node engine");
  assertEqual(
    metadata.peerDependencies,
    { vite: "^5.0.0 || ^6.0.0 || ^7.0.0" },
    "Unexpected Vite peer dependency",
  );
  assertEqual(
    metadata.exports,
    {
      ".": {
        types: "./dist/index.d.ts",
        import: "./dist/index.js",
      },
    },
    "Package exports must advertise ESM imports and declarations only",
  );
}

function writeConsumer(root, tarball) {
  mkdirSync(path.join(root, "src"), { recursive: true });
  writeJson(path.join(root, "package.json"), {
    name: "coupling-vite-audit-consumer",
    private: true,
    type: "module",
    dependencies: {
      "coupling-vite": `file:${tarball}`,
      vite: "7.3.6",
    },
    devDependencies: {
      "@types/node": "22.20.1",
      typescript: "5.9.3",
    },
  });
  writeJson(path.join(root, "tsconfig.json"), {
    compilerOptions: {
      lib: ["ESNext"],
      module: "ESNext",
      moduleResolution: "Bundler",
      noEmit: true,
      strict: true,
      target: "ES2022",
      types: ["node"],
    },
    include: ["typecheck.ts"],
  });
  writeFileSync(
    path.join(root, "typecheck.ts"),
    `import couplingDefault, { coupling, type CouplingOptions } from "coupling-vite";\n\nconst options: CouplingOptions = { fileName: "manifest.json", sourceRoot: "src" };\nconst defaultPlugin = couplingDefault(options);\nconst namedPlugin = coupling(options);\nvoid [defaultPlugin, namedPlugin];\n`,
  );
  writeFileSync(
    path.join(root, "import-check.mjs"),
    `import couplingDefault, { coupling } from "coupling-vite";\n\nif (couplingDefault !== coupling || coupling().name !== "coupling") {\n  throw new Error("Packed package exports are invalid");\n}\n`,
  );
  writeFileSync(
    path.join(root, "vite.config.mjs"),
    `import path from "node:path";\nimport { fileURLToPath } from "node:url";\n\nimport coupling from "coupling-vite";\nimport { defineConfig } from "vite";\n\nconst root = path.dirname(fileURLToPath(import.meta.url));\n\nexport default defineConfig({\n  plugins: [coupling({ sourceRoot: "src" })],\n  build: {\n    assetsInlineLimit: 0,\n    minify: false,\n    rollupOptions: {\n      input: { application: path.join(root, "src/application.js") },\n    },\n  },\n});\n`,
  );
  writeFileSync(
    path.join(root, "src/application.js"),
    `import "./application.css";\nimport logo from "./logo.svg";\n\nconsole.log(logo);\nvoid import("./lazy.js");\n`,
  );
  writeFileSync(
    path.join(root, "src/application.css"),
    "body { color: rebeccapurple; }\n",
  );
  writeFileSync(
    path.join(root, "src/lazy.js"),
    'export const lazy = "loaded";\n',
  );
  writeFileSync(
    path.join(root, "src/logo.svg"),
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>\n',
  );
}

function writeJson(fileName, value) {
  writeFileSync(fileName, `${JSON.stringify(value, null, 2)}\n`);
}

function rubyManifestCheck() {
  return `
require "coupling"

assets_path = ARGV.fetch(0)
Coupling.configure do |config|
  config.assets_path = assets_path
  config.public_path = "/assets"
end

entries = Coupling.manifest.entries
abort "missing packed entry JavaScript" unless entries.key?("application.js")
abort "missing packed entry CSS" unless entries.key?("application.css")
abort "missing packed static asset" unless entries.key?("logo.svg")
anonymous = entries.fetch("")
abort "missing packed lazy chunk" unless anonymous.any? { |output| output.end_with?(".js") }
entries.values.flatten.each do |output|
  abort "missing built output: #{output}" unless File.file?(File.join(assets_path, output))
  Coupling.manifest.find(output)
end
`;
}

function capture(command, arguments_, cwd) {
  const result = spawnSync(command, arguments_, {
    cwd,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    process.stdout.write(result.stdout ?? "");
    process.stderr.write(result.stderr ?? "");
    throw new Error(`${command} failed with status ${result.status}`);
  }
  return result.stdout;
}

function run(command, arguments_, cwd) {
  const result = spawnSync(command, arguments_, { cwd, stdio: "inherit" });
  if (result.status !== 0) {
    throw new Error(`${command} failed with status ${result.status}`);
  }
}

function assertEqual(actual, expected, message) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `${message}\nExpected: ${JSON.stringify(expected)}\nActual: ${JSON.stringify(actual)}`,
    );
  }
}
