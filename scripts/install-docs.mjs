import { createHash } from "node:crypto";
import { mkdtemp, writeFile, rm, appendFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import assert from "node:assert/strict";
// CI-only dependency install. Does not edit source or execute downloaded scripts.
assert.equal(process.platform, "linux");
assert.equal(process.arch, "x64");
const folder = await mkdtemp(join(tmpdir(), "ws2-docs-"));
const url = "https://github.com/terraform-docs/terraform-docs/releases/download/v0.24.0/terraform-docs-v0.24.0-linux-amd64.tar.gz";
const response = await fetch(url);
assert.ok(response.ok);
const bytes = Buffer.from(await response.arrayBuffer());
assert.equal(createHash("sha256").update(bytes).digest("hex"), "9005daf969de0b50134493a2c00078b49f5f5b39d021cda7c89bf4d4f3d776d3");
await writeFile(join(folder, "docs.tar.gz"), bytes);
assert.equal(spawnSync("tar", ["-xzf", join(folder, "docs.tar.gz"), "-C", folder, "terraform-docs"]).status, 0);
await rm(join(folder, "docs.tar.gz"));
await appendFile(process.env.GITHUB_PATH, `${folder}\n`);
