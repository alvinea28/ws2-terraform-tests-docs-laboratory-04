import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export function renderDocumentation(root = process.cwd()) {
  const binary = process.env.TERRAFORM_DOCS_BIN || "terraform-docs";
  const execute = (args) => {
    const result = spawnSync(binary, args, { cwd: root, encoding: "utf8", shell: false, timeout: 60_000, maxBuffer: 8 * 1024 * 1024 });
    assert.equal(result.status, 0, "Install terraform-docs 0.24.0 and run this command from the lab root.");
    return result.stdout;
  };
  assert.match(execute(["version"]), /terraform-docs version v0\.24\.0(?:\s|$)/, "Use terraform-docs 0.24.0.");
  // stdout is the canonical document. --output-file adds wrapper comments and
  // must not be mixed with this representation in the learner freshness check.
  const text = execute(["markdown", "table", "--config", "exercises/terraform-docs.yml", "."]);
  for (const section of ["## Requirements", "## Providers", "## Inputs", "## Outputs"]) assert.ok(text.includes(section), `Generated API is missing ${section}.`);
  return `${text.replaceAll("\r\n", "\n").trim()}\n`;
}

export async function generateDocumentation({ root = process.cwd(), check = false } = {}) {
  const expected = renderDocumentation(root);
  const file = resolve(root, "docs/module-api.md");
  if (check) {
    const actual = await readFile(file, "utf8");
    assert.equal(actual.replaceAll("\r\n", "\n").trim(), expected.trim(), "Regenerate the actual module API with node scripts/generate-docs.mjs; do not invent a table or add output wrappers.");
  } else {
    await mkdir(dirname(file), { recursive: true });
    await writeFile(file, expected, "utf8");
  }
  return file;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== "--check")) {
    console.error("Use node scripts/generate-docs.mjs [--check] from the lab root.");
    process.exitCode = 1;
  } else {
    generateDocumentation({ check: args[0] === "--check" })
      .then(() => console.log(args[0] === "--check" ? "Generated module API is current." : "Generated docs/module-api.md from the actual module; run again to verify no diff."))
      .catch((error) => { console.error(error.message); process.exitCode = 1; });
  }
}