import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  chmod,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { publishLearningModule } from "../scripts/publish-learning-module.mjs";

const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const baseUrl = "https://api.example/lesson-modules/";

async function fixture() {
  const directory = await mkdtemp(join(tmpdir(), "academy-module-publisher-"));
  const definition = {
    id: "fixture",
    api_version: 1,
    entry: "main.mjs",
    explanation: "Unicode Ä is preserved",
  };
  const content = "export const apiVersion = 1;\n";
  const asset = '<svg xmlns="http://www.w3.org/2000/svg"></svg>';
  const files = [
    {
      path: "main.mjs",
      bytes: Buffer.byteLength(content),
      sha256: hash(content),
    },
    {
      path: "assets ü/bg image.svg",
      bytes: Buffer.byteLength(asset),
      sha256: hash(asset),
    },
  ];
  const artifact = hash(JSON.stringify({ definition, files }));
  const source = join(directory, artifact);
  await mkdir(source);
  await mkdir(join(source, "assets ü"));
  await writeFile(join(source, "assets ü/bg image.svg"), asset);
  await writeFile(join(source, "main.mjs"), content);
  await writeFile(
    join(source, "module.json"),
    JSON.stringify({
      id: definition.id,
      api_version: 1,
      entry_url: `${baseUrl}${artifact}/main.mjs`,
    }),
  );
  await writeFile(
    join(source, "manifest.json"),
    JSON.stringify({ artifact_sha256: artifact, definition, files }),
  );
  const root = join(directory, "published");
  async function cleanup() {
    async function unseal(path) {
      await chmod(path, 0o700);
      for (const item of await readdir(path, { withFileTypes: true })) {
        if (item.isDirectory()) await unseal(join(path, item.name));
      }
    }
    await unseal(directory);
    await rm(directory, { recursive: true, force: true });
  }
  return { directory, source, root, artifact, cleanup };
}

test("publication is atomic and an identical package is safely reused", async () => {
  const value = await fixture();
  try {
    const args = { ...value, baseUrl };
    assert.equal(
      (await publishLearningModule({ ...args, check: true })).checked,
      true,
    );
    assert.deepEqual(await readdir(value.directory), [value.artifact]);
    assert.equal((await publishLearningModule(args)).published, true);
    assert.match(
      await readFile(
        join(value.root, value.artifact, "assets ü/bg image.svg"),
        "utf8",
      ),
      /<svg/,
    );
    assert.equal((await publishLearningModule(args)).reused, true);
    assert.deepEqual(await readdir(value.root), [value.artifact]);
    assert.equal(
      await readFile(join(value.root, value.artifact, "main.mjs"), "utf8"),
      "export const apiVersion = 1;\n",
    );
  } finally {
    await value.cleanup();
  }
});

test("a changed existing artifact is rejected without overwriting it", async () => {
  const value = await fixture();
  try {
    await publishLearningModule({ ...value, baseUrl });
    const existing = join(value.root, value.artifact, "main.mjs");
    await chmod(existing, 0o644);
    await writeFile(existing, "preserve this unexpected existing file");
    await assert.rejects(
      publishLearningModule({ ...value, baseUrl }),
      /immutable assets cannot be replaced/,
    );
    assert.equal(
      await readFile(existing, "utf8"),
      "preserve this unexpected existing file",
    );
    assert.deepEqual(await readdir(value.root), [value.artifact]);
  } finally {
    await value.cleanup();
  }
});

test("asset tampering, unlisted files and host changes fail before publishing", async () => {
  const value = await fixture();
  try {
    await assert.rejects(
      publishLearningModule({
        ...value,
        baseUrl: "https://elsewhere.example/lesson-modules/",
      }),
      /this host and artifact/,
    );
    await writeFile(join(value.source, "unlisted.txt"), "extra");
    await assert.rejects(
      publishLearningModule({ ...value, baseUrl }),
      /unlisted/,
    );
    await rm(join(value.source, "unlisted.txt"));
    await writeFile(join(value.source, "main.mjs"), "tampered");
    await assert.rejects(
      publishLearningModule({ ...value, baseUrl }),
      /hash or size/,
    );
    assert.deepEqual(await readdir(value.directory), [value.artifact]);
  } finally {
    await value.cleanup();
  }
});

test("symlink assets and falsified artifact digests fail closed", async () => {
  const value = await fixture();
  try {
    await symlink("module.json", join(value.source, "extra.json"));
    await assert.rejects(
      publishLearningModule({ ...value, baseUrl }),
      /symbolic links/,
    );
    await rm(join(value.source, "extra.json"));
    const manifestPath = join(value.source, "manifest.json");
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    manifest.artifact_sha256 = "0".repeat(64);
    await writeFile(manifestPath, JSON.stringify(manifest));
    await assert.rejects(
      publishLearningModule({ ...value, baseUrl }),
      /content-addressed/,
    );
  } finally {
    await value.cleanup();
  }
});
