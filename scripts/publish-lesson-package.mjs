// Publisher for API 2 packages of the lesson engine (academy.backend.lessonContent). The API 1 publisher
// (publish-learning-module.mjs) stays unchanged; it is part of every host with lesson modules.
import { createHash, randomUUID } from "node:crypto";
import { createReadStream } from "node:fs";
import {
  chmod,
  copyFile,
  lstat,
  mkdir,
  readFile,
  readdir,
  realpath,
  rename,
  rm,
} from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

// What the frontend loads (lesson-protocol/browser.ts, verifyLessonPackage; schemas/manifest.schema.json).
const PATH = /^(?:[A-Za-z0-9_-]+\/)*[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+$/;
const ID = /^[a-z0-9][a-z0-9-]{0,79}$/;
const HASH = /^[0-9a-f]{64}$/;
const MEDIA = new Set([
  "text/html",
  "text/javascript",
  "text/css",
  "application/json",
  "image/svg+xml",
  "image/png",
  "image/webp",
  "image/avif",
  "audio/ogg",
  "audio/mpeg",
  "audio/mp4",
  "application/octet-stream",
]);
const PACKAGE_BYTES = 1572864;
const MANIFEST_BYTES = 65536;

const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");

/** The canonical JSON of the frontend (lesson-protocol/schema.ts): keys sorted by code point, no spaces. */
export function canonicalJson(value) {
  const order = (a, b) => {
    const left = Array.from(a, (char) => char.codePointAt(0));
    const right = Array.from(b, (char) => char.codePointAt(0));
    for (let index = 0; index < Math.min(left.length, right.length); index++)
      if (left[index] !== right[index]) return left[index] - right[index];
    return left.length - right.length;
  };
  const encode = (item) => {
    if (Array.isArray(item)) return `[${item.map(encode).join(",")}]`;
    if (item !== null && typeof item === "object")
      return `{${Object.keys(item)
        .sort(order)
        .map((key) => `${JSON.stringify(key)}:${encode(item[key])}`)
        .join(",")}}`;
    if (typeof item === "number" && !Number.isFinite(item))
      throw new Error("Numbers in the manifest must be finite");
    return JSON.stringify(item);
  };
  return encode(value);
}

async function inventory(directory, prefix = "") {
  if (!(await lstat(directory)).isDirectory())
    throw new Error("Package directories cannot be symbolic links");
  const result = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    const path = prefix + item.name;
    if (item.isSymbolicLink())
      throw new Error("Packages cannot contain symbolic links");
    if (item.isDirectory())
      result.push(...(await inventory(join(directory, item.name), path + "/")));
    else if (item.isFile()) result.push(path);
    else throw new Error("Only regular files can be published");
  }
  return result.sort();
}

async function fileHash(path) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest("hex");
}

/**
 * A package as the frontend loads it from {origin}/packages/{package_hash}/: the protocol manifest as
 * manifest.json and exactly its assets. The directory is named by SHA-256 of the canonical JSON of the assets.
 */
export async function validateLessonPackage(directory, requireName = true) {
  const files = await inventory(directory);
  const raw = await readFile(join(directory, "manifest.json"));
  if (raw.length > MANIFEST_BYTES)
    throw new Error(`The manifest has more than ${MANIFEST_BYTES} bytes`);
  let manifest;
  try {
    manifest = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(raw),
    );
  } catch {
    throw new Error("The manifest is no UTF-8 JSON");
  }
  if (
    manifest === null ||
    typeof manifest !== "object" ||
    Array.isArray(manifest) ||
    typeof manifest.id !== "string" ||
    !ID.test(manifest.id) ||
    typeof manifest.entry !== "string" ||
    !Array.isArray(manifest.assets) ||
    manifest.assets.length === 0
  )
    throw new Error("Invalid protocol manifest");
  let total = 0;
  for (const asset of manifest.assets) {
    if (
      asset === null ||
      typeof asset !== "object" ||
      typeof asset.path !== "string" ||
      asset.path.length > 200 ||
      !PATH.test(asset.path) ||
      asset.path === "manifest.json" ||
      !HASH.test(asset.sha256) ||
      !MEDIA.has(asset.mediaType) ||
      !["initial", "lazy"].includes(asset.loading) ||
      !Number.isSafeInteger(asset.bytes) ||
      asset.bytes < 0 ||
      (total += asset.bytes) > PACKAGE_BYTES
    )
      throw new Error("Invalid asset inventory");
  }
  const names = manifest.assets.map((asset) => asset.path);
  const entry = manifest.assets.find((asset) => asset.path === manifest.entry);
  if (new Set(names).size !== names.length || entry?.mediaType !== "text/html")
    throw new Error("Invalid or duplicate asset references, or no HTML entry");
  if (
    JSON.stringify(files) !== JSON.stringify([...names, "manifest.json"].sort())
  )
    throw new Error("The package contains missing or unlisted files");
  for (const asset of manifest.assets) {
    if (
      (await lstat(join(directory, asset.path))).size !== asset.bytes ||
      (await fileHash(join(directory, asset.path))) !== asset.sha256
    )
      throw new Error("An asset differs from its reviewed hash or size");
  }
  const packageHash = digest(canonicalJson(manifest.assets));
  if (requireName && basename(resolve(directory)) !== packageHash)
    throw new Error(
      "The package does not match its content-addressed directory",
    );
  return {
    package_hash: packageHash,
    manifest_hash: digest(raw),
    id: manifest.id,
    entry: manifest.entry,
    files,
  };
}

async function samePackage(source, target, files) {
  if (JSON.stringify(await inventory(target)) !== JSON.stringify(files))
    throw new Error(
      "An existing package differs; immutable files cannot be replaced",
    );
  for (const file of files) {
    if (
      (await fileHash(join(source, file))) !==
      (await fileHash(join(target, file)))
    )
      throw new Error(
        "An existing package differs; immutable files cannot be replaced",
      );
  }
}

/** Local filesystem publication only: no upload, registry write, restart or remote request. */
export async function publishLessonPackage({ source, root, check = false }) {
  const verified = await validateLessonPackage(source, true);
  if (check) return { ...verified, published: false, checked: true };
  let createdRoot = false;
  try {
    // Only the explicit public root, never missing parents.
    await mkdir(root, { mode: 0o755 });
    createdRoot = true;
  } catch (error) {
    if (error.code !== "EEXIST") throw error;
  }
  const rootStat = await lstat(root);
  if (!rootStat.isDirectory())
    throw new Error("The publication root cannot be a symbolic link");
  if (createdRoot) await chmod(root, 0o755);
  else if ((rootStat.mode & 0o005) !== 0o005)
    throw new Error(
      "The existing publication root must be publicly readable and traversable; its permissions were not changed",
    );
  const destination = await realpath(root);
  const target = join(destination, verified.package_hash);
  try {
    await lstat(target);
    await samePackage(source, target, verified.files);
    return { ...verified, published: false, reused: true, directory: target };
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  const temporary = join(
    destination,
    `.publish-${process.pid}-${randomUUID()}`,
  );
  await mkdir(temporary, { mode: 0o700 });
  try {
    for (const name of verified.files) {
      const path = join(temporary, name);
      await mkdir(dirname(path), { recursive: true, mode: 0o755 });
      await copyFile(join(source, name), path);
      await chmod(path, 0o444);
    }
    const staged = await validateLessonPackage(temporary, false);
    if (
      staged.package_hash !== verified.package_hash ||
      staged.manifest_hash !== verified.manifest_hash ||
      JSON.stringify(staged.files) !== JSON.stringify(verified.files)
    )
      throw new Error("The reviewed source package changed during publication");
    async function seal(directory) {
      for (const item of await readdir(directory, { withFileTypes: true }))
        if (item.isDirectory()) await seal(join(directory, item.name));
      await chmod(directory, 0o555);
    }
    await seal(temporary);
    try {
      await rename(temporary, target);
    } catch (error) {
      if (!["EEXIST", "ENOTEMPTY"].includes(error.code)) throw error;
      await samePackage(source, target, verified.files);
      return { ...verified, published: false, reused: true, directory: target };
    }
    return { ...verified, published: true, directory: target };
  } finally {
    // Cleanup only our unpublished staging directory; never an existing package.
    async function unseal(directory) {
      await chmod(directory, 0o700);
      for (const item of await readdir(directory, { withFileTypes: true }))
        if (item.isDirectory()) await unseal(join(directory, item.name));
    }
    try {
      await unseal(temporary);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
    await rm(temporary, { recursive: true, force: true });
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    const { values } = parseArgs({
      options: {
        api: { type: "string", default: "2" },
        package: { type: "string" },
        root: { type: "string" },
        check: { type: "boolean", default: false },
      },
    });
    if (values.api !== "2" || !values.package || !values.root)
      throw new Error(
        "Usage: academy-publish-lesson-package [--api 2] --package PACKAGE_HASH_DIR --root LESSON_CONTENT_ROOT/packages [--check]",
      );
    const result = await publishLessonPackage({
      source: values.package,
      root: values.root,
      check: values.check,
    });
    process.stdout.write(JSON.stringify(result, null, 2) + "\n");
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
