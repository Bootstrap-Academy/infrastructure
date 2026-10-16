import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import {
  chmod,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rename,
  rm,
  stat,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  canonicalJson,
  MEDIA_BY_EXTENSION,
  publishLessonPackage,
} from "../scripts/publish-lesson-package.mjs";

const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const run = promisify(execFile);

// API 2: packages of the lesson engine, as the frontend loads them from {origin}/packages/{package_hash}/.

const script = fileURLToPath(
  new URL("../scripts/publish-lesson-package.mjs", import.meta.url),
);

async function lessonFixture(edit = () => {}) {
  const directory = await mkdtemp(join(tmpdir(), "academy-lesson-package-"));
  const contents = {
    "img/bg.svg": '<svg xmlns="http://www.w3.org/2000/svg"></svg>',
    "index.html": "<!doctype html><title>Lektion</title>\n",
    "main.js": "export const lesson = 'Ä';\n",
    "state.schema.json": '{"type":"object"}\n',
    "style.css": "body { margin: 0; }\n",
  };
  const media = {
    "img/bg.svg": "image/svg+xml",
    "index.html": "text/html",
    "main.js": "text/javascript",
    "state.schema.json": "application/json",
    "style.css": "text/css",
  };
  const manifest = {
    id: "fixture-lesson",
    protocol: { major: 2, minor: 1 },
    entry: "index.html",
    assets: Object.keys(contents).map((path) => ({
      path,
      sha256: hash(contents[path]),
      mediaType: media[path],
      bytes: Buffer.byteLength(contents[path]),
      loading: "initial",
    })),
    state: { schemaVersion: 1, schema: "state.schema.json", maxBytes: 1024 },
  };
  const files = { ...contents, "manifest.json": null };
  edit({ manifest, files });
  const name = hash(canonicalJson(manifest.assets));
  const source = join(directory, name);
  await mkdir(source);
  for (const [path, text] of Object.entries(files)) {
    await mkdir(join(source, path, ".."), { recursive: true });
    await writeFile(join(source, path), text ?? JSON.stringify(manifest));
  }
  const root = join(directory, "packages");
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
  return { directory, source, root, name, manifest, cleanup };
}

test("API 2: the package hash is the one the frontend computes", () => {
  // Computed with the canonical JSON of the protocol vendored in the lesson engine (src/build/protocol.ts).
  // Keys sort by code point: U+FF5E before U+1F600, the reverse of JavaScript's default UTF-16 order.
  const assets = [
    {
      path: "index.html",
      sha256: "a".repeat(64),
      mediaType: "text/html",
      bytes: 10,
      loading: "initial",
    },
    {
      loading: "lazy",
      bytes: 3,
      mediaType: "image/svg+xml",
      path: "img/b.svg",
      sha256: "b".repeat(64),
      note: "Ä",
      "\u{1F600}": 1,
      "\uFF5E": 2,
    },
  ];
  assert.equal(
    hash(canonicalJson(assets)),
    "ab98b5f144315816a01bdb247d5b6b6dce0644d3a7dfc53258c419db98fd95e6",
  );
});

test("API 2: a package is installed sealed below its hash and reused", async () => {
  const value = await lessonFixture();
  try {
    const checked = await publishLessonPackage({ ...value, check: true });
    assert.equal(checked.checked, true);
    assert.equal(checked.package_hash, value.name);
    assert.equal(
      checked.manifest_hash,
      hash(await readFile(join(value.source, "manifest.json"))),
    );
    assert.deepEqual(await readdir(value.directory), [value.name]);

    const first = await publishLessonPackage(value);
    assert.equal(first.published, true);
    assert.equal(first.directory, join(value.root, value.name));
    assert.equal((await stat(value.root)).mode & 0o7777, 0o755);
    for (const path of ["", "img"])
      assert.equal(
        (await stat(join(first.directory, path))).mode & 0o7777,
        0o555,
      );
    for (const path of [
      ...value.manifest.assets.map((asset) => asset.path),
      "manifest.json",
    ])
      assert.equal(
        (await stat(join(first.directory, path))).mode & 0o7777,
        0o444,
      );
    assert.deepEqual(await readdir(value.root), [value.name]);

    const again = await publishLessonPackage(value);
    assert.equal(again.reused, true);
    assert.deepEqual(await readdir(value.root), [value.name]);
  } finally {
    await value.cleanup();
  }
});

test("API 2: a package that is not exactly its manifest fails before publishing", async () => {
  const cases = [
    [
      "a different directory name",
      null,
      async (value) => {
        const renamed = join(value.directory, "f".repeat(64));
        await rename(value.source, renamed);
        value.source = renamed;
      },
      /content-addressed directory/,
    ],
    [
      "changed bytes",
      null,
      async (value) =>
        writeFile(
          join(value.source, "main.js"),
          "export const lesson = 'B';\n",
        ),
      /differs from its reviewed hash/,
    ],
    [
      "an unlisted file",
      null,
      async (value) => writeFile(join(value.source, "extra.js"), ""),
      /missing or unlisted/,
    ],
    [
      "a missing file",
      null,
      async (value) => rm(join(value.source, "style.css")),
      /missing or unlisted/,
    ],
    [
      "a symbolic link",
      null,
      async (value) => {
        await rm(join(value.source, "style.css"));
        await symlink("main.js", join(value.source, "style.css"));
      },
      /symbolic links/,
    ],
    [
      "a path with a space",
      ({ manifest, files }) => {
        files["a b.css"] = files["style.css"];
        delete files["style.css"];
        manifest.assets.find((asset) => asset.path === "style.css").path =
          "a b.css";
      },
      null,
      /Invalid asset inventory/,
    ],
    [
      "a media type outside the protocol",
      ({ manifest }) => {
        manifest.assets.find((asset) => asset.path === "style.css").mediaType =
          "text/plain";
      },
      null,
      /Invalid asset inventory/,
    ],
    [
      "manifest.json among the assets",
      ({ manifest }) => {
        manifest.assets.push({ ...manifest.assets[0], path: "manifest.json" });
      },
      null,
      /Invalid asset inventory/,
    ],
    [
      "a duplicate asset",
      ({ manifest }) => {
        manifest.assets.push({ ...manifest.assets[0] });
      },
      null,
      /duplicate asset references/,
    ],
    [
      "an entry that is not among the assets",
      ({ manifest }) => {
        manifest.entry = "missing/index.html";
      },
      null,
      /no HTML entry/,
    ],
    [
      "more bytes than the platform loads",
      ({ manifest }) => {
        manifest.assets[0].bytes = 1572865;
      },
      null,
      /Invalid asset inventory/,
    ],
    [
      "a manifest over 64 KiB",
      ({ manifest }) => {
        manifest.padding = "x".repeat(65536);
      },
      null,
      /more than 65536 bytes/,
    ],
    [
      "a manifest without id",
      ({ manifest }) => {
        delete manifest.id;
      },
      null,
      /Invalid protocol manifest/,
    ],
    [
      "an entry that the origin does not serve under its address",
      ({ manifest, files }) => {
        files["lesson.html"] = files["index.html"];
        delete files["index.html"];
        manifest.assets.find((asset) => asset.path === "index.html").path =
          "lesson.html";
        manifest.entry = "lesson.html";
      },
      null,
      /entry must be index.html/,
    ],
    [
      "a media type that is not the one of the extension",
      ({ manifest }) => {
        manifest.assets.find((asset) => asset.path === "main.js").mediaType =
          "text/css";
      },
      null,
      /Invalid asset inventory/,
    ],
    [
      "a known extension declared as octet-stream",
      ({ manifest }) => {
        manifest.assets.find((asset) => asset.path === "style.css").mediaType =
          "application/octet-stream";
      },
      null,
      /Invalid asset inventory/,
    ],
    [
      "an extension in capitals",
      ({ manifest, files }) => {
        files["style.CSS"] = files["style.css"];
        delete files["style.css"];
        manifest.assets.find((asset) => asset.path === "style.css").path =
          "style.CSS";
      },
      null,
      /Invalid asset inventory/,
    ],
    [
      "a manifest that is no UTF-8",
      ({ files }) => {
        files["manifest.json"] = Buffer.from([0xff, 0xfe]);
      },
      null,
      /no UTF-8 JSON/,
    ],
  ];
  for (const [name, edit, mutate, error] of cases) {
    const value = await lessonFixture(edit ?? undefined);
    try {
      if (mutate) await mutate(value);
      await assert.rejects(publishLessonPackage(value), error, name);
      await assert.rejects(
        publishLessonPackage({ ...value, check: true }),
        error,
        name,
      );
      await assert.rejects(stat(value.root), { code: "ENOENT" }, name);
    } finally {
      await value.cleanup();
    }
  }
});

test("API 2: the CLI checks without writing and refuses the options of API 1", async () => {
  const value = await lessonFixture();
  try {
    const { stdout } = await run(process.execPath, [
      script,
      "--api",
      "2",
      "--package",
      value.source,
      "--root",
      value.root,
      "--check",
    ]);
    const result = JSON.parse(stdout);
    assert.equal(result.checked, true);
    assert.equal(result.package_hash, value.name);
    await assert.rejects(stat(value.root), { code: "ENOENT" });
    for (const extra of [
      ["--base-url", "https://api.example/lesson-modules/"],
      ["--private"],
      ["--api", "3"],
    ]) {
      await assert.rejects(
        run(process.execPath, [
          script,
          "--api",
          "2",
          "--package",
          value.source,
          "--root",
          value.root,
          ...extra,
        ]),
        (error) => error.code === 1,
        extra.join(" "),
      );
    }
    await assert.rejects(stat(value.root), { code: "ENOENT" });
    const published = JSON.parse(
      (
        await run(process.execPath, [
          script,
          "--api",
          "2",
          "--package",
          value.source,
          "--root",
          value.root,
        ])
      ).stdout,
    );
    assert.equal(published.published, true);
  } finally {
    await value.cleanup();
  }
});

test("API 2: an entry in a folder and an unknown extension as octet-stream are published", async () => {
  const value = await lessonFixture(({ manifest, files }) => {
    files["app/index.html"] = files["index.html"];
    delete files["index.html"];
    manifest.assets.find((asset) => asset.path === "index.html").path =
      "app/index.html";
    manifest.entry = "app/index.html";
    files["data.bin"] = "binary";
    manifest.assets.push({
      path: "data.bin",
      sha256: hash("binary"),
      mediaType: "application/octet-stream",
      bytes: 6,
      loading: "lazy",
    });
  });
  try {
    assert.equal((await publishLessonPackage(value)).published, true);
  } finally {
    await value.cleanup();
  }
});

test("API 2: the media types are the ones nginx sends from the content origin", async () => {
  const nix = await readFile(
    fileURLToPath(
      new URL("../modules/backend/lesson-content.nix", import.meta.url),
    ),
    "utf8",
  );
  const block = nix.match(/\n\s*types \{\n([^}]*)\n\s*\}/);
  assert.ok(block, "types block");
  const served = {};
  for (const line of block[1].split("\n")) {
    const match = line.trim().match(/^(\S+)((?:\s+[a-z0-9]+)+);$/);
    assert.ok(match, line);
    for (const extension of match[2].trim().split(/\s+/))
      served[extension] = match[1];
  }
  assert.deepEqual(served, MEDIA_BY_EXTENSION);
  assert.match(nix, /default_type application\/octet-stream;/);
});
