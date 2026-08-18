import path from "node:path";

const WINDOWS_ABSOLUTE = /^[A-Za-z]:[\\/]/;

export function validateManifestFileName(fileName: string): string {
  if (fileName.length === 0) {
    throw new Error("fileName must not be empty");
  }
  if (fileName.includes("\0")) {
    throw new Error("fileName must not contain a null byte");
  }
  if (fileName.includes("\\")) {
    throw new Error("fileName must use forward slashes");
  }
  if (path.posix.isAbsolute(fileName) || WINDOWS_ABSOLUTE.test(fileName)) {
    throw new Error(`fileName must be relative: ${JSON.stringify(fileName)}`);
  }

  const segments = fileName.split("/");
  if (segments.some(isUnsafePathSegment)) {
    throw new Error(
      `fileName contains an unsafe path segment: ${JSON.stringify(fileName)}`,
    );
  }

  return fileName;
}

export function resolveSourceRoot(
  viteRoot: string,
  sourceRoot?: string,
): string {
  return sourceRoot === undefined
    ? path.resolve(viteRoot)
    : path.resolve(viteRoot, sourceRoot);
}

export function sourceLogicalName(
  originalFileName: string,
  sourceRoot: string,
  viteRoot: string,
): string | undefined {
  if (originalFileName.length === 0 || originalFileName.includes("\0")) {
    return undefined;
  }

  const windowsPath = usesWindowsPaths(originalFileName, sourceRoot, viteRoot);
  const pathApi = windowsPath ? path.win32 : path;
  const absoluteSource = pathApi.isAbsolute(originalFileName)
    ? pathApi.resolve(originalFileName)
    : pathApi.resolve(viteRoot, originalFileName);
  const relative = pathApi.relative(
    pathApi.resolve(sourceRoot),
    absoluteSource,
  );

  if (relative.length === 0 || pathApi.isAbsolute(relative)) {
    return undefined;
  }

  const segments = relative.split(/[\\/]/);
  if (segments.some(isUnsafePathSegment)) {
    return undefined;
  }

  return segments.join("/");
}

export function validateLogicalName(name: string): string {
  if (name.length === 0) {
    throw new Error("generated logical name must not be empty");
  }
  if (name.includes("\0") || name.includes("\\")) {
    throw new Error(
      `generated logical name is unsafe: ${JSON.stringify(name)}`,
    );
  }
  if (path.posix.isAbsolute(name) || WINDOWS_ABSOLUTE.test(name)) {
    throw new Error(
      `generated logical name must be relative: ${JSON.stringify(name)}`,
    );
  }

  const segments = name.split("/");
  if (segments.some(isUnsafePathSegment)) {
    throw new Error(
      `generated logical name is unsafe: ${JSON.stringify(name)}`,
    );
  }

  return name;
}

export function validateOutputPath(fileName: string): string {
  try {
    return validateLogicalName(fileName);
  } catch {
    throw new Error(
      `Vite emitted an unsafe output path: ${JSON.stringify(fileName)}`,
    );
  }
}

function isUnsafePathSegment(segment: string): boolean {
  return segment.length === 0 || segment === "." || segment === "..";
}

function usesWindowsPaths(...values: string[]): boolean {
  return values.some(isWindowsPath);
}

function isWindowsPath(value: string): boolean {
  return WINDOWS_ABSOLUTE.test(value) || value.includes("\\");
}
