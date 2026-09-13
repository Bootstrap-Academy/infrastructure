import { createHash, randomUUID } from "node:crypto";
import { createReadStream } from "node:fs";
import {
  lstat,
  mkdir,
  readFile,
  readdir,
  realpath,
  rename,
  rm,
  copyFile,
  chmod,
} from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { pathToFileURL } from "node:url";

const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");
const hashPattern = /^[0-9a-f]{64}$/;
const assetPath = (path) =>
  typeof path === "string" &&
  path
    .split("/")
    .every(
      (part) =>
        part.length > 0 &&
        !part.startsWith(".") &&
        !/[\\\x00-\x1f\x7f]/.test(part),
    );

async function inventory(directory, prefix = "") {
  if (!(await lstat(directory)).isDirectory())
    throw new Error("Package directories cannot be symbolic links");
  const result = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    const path = prefix + item.name;
    if (!assetPath(path) || item.isSymbolicLink())
      throw new Error(
        "Asset names cannot be hidden, contain controls or use symbolic links",
      );
    if (item.isDirectory())
      result.push(...(await inventory(join(directory, item.name), path + "/")));
    else if (item.isFile()) result.push(path);
    else throw new Error("Only regular module assets can be published");
  }
  return result.sort();
}

async function fileHash(path) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest("hex");
}

export async function validatePackage(directory, baseUrl, requireName = true) {
  const base = new URL(baseUrl.endsWith("/") ? baseUrl : baseUrl + "/");
  if (
    base.protocol !== "https:" ||
    base.username ||
    base.password ||
    base.search ||
    base.hash ||
    base.pathname !== "/lesson-modules/"
  ) {
    throw new Error(
      "Use the reviewed HTTPS API origin with /lesson-modules/ as its asset base",
    );
  }
  const files = await inventory(directory);
  const descriptor = JSON.parse(
    await readFile(join(directory, "module.json"), "utf8"),
  );
  const manifest = JSON.parse(
    await readFile(join(directory, "manifest.json"), "utf8"),
  );
  if (
    Object.keys(descriptor).sort().join(",") !== "api_version,entry_url,id" ||
    descriptor.api_version !== 1 ||
    typeof descriptor.id !== "string" ||
    !/^[a-z0-9][a-z0-9-]{0,79}$/.test(descriptor.id)
  ) {
    throw new Error("Invalid public module descriptor");
  }
  const definition = manifest.definition;
  if (
    !definition ||
    definition.id !== descriptor.id ||
    definition.api_version !== 1 ||
    !assetPath(definition.entry) ||
    !/\.m?js$/.test(definition.entry)
  ) {
    throw new Error(
      "Manifest must include its original browser-module definition",
    );
  }
  if (
    !Array.isArray(manifest.files) ||
    !hashPattern.test(manifest.artifact_sha256)
  )
    throw new Error("Invalid artifact manifest");
  const names = manifest.files.map((file) => file.path);
  if (
    new Set(names).size !== names.length ||
    names.includes("module.json") ||
    names.includes("manifest.json") ||
    !names.includes(definition.entry)
  ) {
    throw new Error("Invalid or duplicate asset references");
  }
  if (
    JSON.stringify(files) !==
    JSON.stringify([...names, "module.json", "manifest.json"].sort())
  )
    throw new Error("The package contains missing or unlisted files");
  for (const file of manifest.files) {
    if (
      !assetPath(file.path) ||
      !hashPattern.test(file.sha256) ||
      !Number.isSafeInteger(file.bytes) ||
      file.bytes < 0
    )
      throw new Error("Invalid asset inventory");
    if (
      (await lstat(join(directory, file.path))).size !== file.bytes ||
      (await fileHash(join(directory, file.path))) !== file.sha256
    ) {
      throw new Error("An asset differs from its reviewed hash or size");
    }
  }
  const artifact = digest(
    JSON.stringify({ definition, files: manifest.files }),
  );
  if (
    artifact !== manifest.artifact_sha256 ||
    (requireName && basename(resolve(directory)) !== artifact)
  )
    throw new Error(
      "The artifact does not match its content-addressed directory",
    );
  const entry = definition.entry.split("/").map(encodeURIComponent).join("/");
  if (descriptor.entry_url !== new URL(`${artifact}/${entry}`, base).href)
    throw new Error("The descriptor does not point to this host and artifact");
  return { artifact, descriptor, files };
}

async function samePackage(source, target, files) {
  if (JSON.stringify(await inventory(target)) !== JSON.stringify(files))
    throw new Error(
      "An existing artifact differs; immutable assets cannot be replaced",
    );
  for (const file of files) {
    if (
      (await fileHash(join(source, file))) !==
      (await fileHash(join(target, file)))
    )
      throw new Error(
        "An existing artifact differs; immutable assets cannot be replaced",
      );
  }
}

/** Local filesystem publication only: no upload, registry write, restart or remote request. */
export async function publishLearningModule({
  source,
  root,
  baseUrl,
  check = false,
}) {
  const verified = await validatePackage(source, baseUrl);
  if (check) return { ...verified, published: false, checked: true };
  let createdRoot = false;
  try {
    // Only create the explicit public root, never arbitrary missing parents.
    await mkdir(root, { mode: 0o755 });
    createdRoot = true;
  } catch (error) {
    if (error.code !== "EEXIST") throw error;
  }
  const rootStat = await lstat(root);
  if (!rootStat.isDirectory())
    throw new Error("The publication root cannot be a symbolic link");
  if (createdRoot) {
    // mkdir's mode is filtered by the caller's umask, including deployment 077.
    await chmod(root, 0o755);
  } else if ((rootStat.mode & 0o005) !== 0o005) {
    throw new Error(
      "The existing publication root must be publicly readable and traversable; its permissions were not changed",
    );
  }
  const destination = await realpath(root);
  const target = join(destination, verified.artifact);
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
    const staged = await validatePackage(temporary, baseUrl, false);
    if (
      staged.artifact !== verified.artifact ||
      JSON.stringify(staged.descriptor) !==
        JSON.stringify(verified.descriptor) ||
      JSON.stringify(staged.files) !== JSON.stringify(verified.files)
    ) {
      throw new Error("The reviewed source package changed during publication");
    }
    async function seal(directory) {
      for (const item of await readdir(directory, { withFileTypes: true })) {
        if (item.isDirectory()) await seal(join(directory, item.name));
      }
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
    // Cleanup only our unpublished staging directory; never an existing artifact.
    async function unseal(directory) {
      await chmod(directory, 0o700);
      for (const item of await readdir(directory, { withFileTypes: true })) {
        if (item.isDirectory()) await unseal(join(directory, item.name));
      }
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
        package: { type: "string" },
        root: { type: "string" },
        "base-url": { type: "string" },
        check: { type: "boolean", default: false },
      },
    });
    if (!values.package || !values.root || !values["base-url"])
      throw new Error(
        "Usage: academy-publish-learning-module --package HASH_DIR --root STATIC_ROOT/lesson-modules --base-url https://API_HOST/lesson-modules/ [--check]",
      );
    const result = await publishLearningModule({
      source: values.package,
      root: values.root,
      baseUrl: values["base-url"],
      check: values.check,
    });
    process.stdout.write(JSON.stringify(result, null, 2) + "\n");
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
