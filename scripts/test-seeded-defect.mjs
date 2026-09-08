import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFile, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// AgentAlvine | D1.5 / D2.1. Never run a live plan/apply/destroy here.
// Only a temporary copy of the COMPLETE v1.0.0 reference is changed. Tests use
// mock_provider, and their command is plan. init may download public providers;
// no Azure credentials, OIDC, user CLI configuration or remote state are needed.
export const TARGET_TEST_FILE = "tests/seeded-defect.tftest.hcl";
export const TARGET_RUN = "reject_wildcard_ingress";
// Terraform's test selector uses native separators on Windows. A forward slash
// can emit Unknown test file and exit 0 with zero tests, which is not evidence.
export const nativeTestFilter = (platform = process.platform) => platform === "win32" ? TARGET_TEST_FILE.replaceAll("/", "\\") : TARGET_TEST_FILE;
const BEGIN = "# BEGIN WS2_INGRESS_GUARD";
const END = "# END WS2_INGRESS_GUARD";
const CHECKPOINT = fileURLToPath(new URL("../solutions/reference/", import.meta.url));
const EXPECTED_TERRAFORM = "1.16.1";
const normalizePath = (value) => String(value ?? "").replaceAll("\\", "/");
const isTargetFile = (value) => {
  const path = normalizePath(value);
  return path === TARGET_TEST_FILE || path.endsWith(`/${TARGET_TEST_FILE}`);
};

export function weakenIngressValidation(source, variableName) {
  assert.ok(["security_rules", "rules"].includes(variableName), "Unexpected input contract.");
  assert.equal(source.split(BEGIN).length, 2, "Expected exactly one ingress BEGIN marker.");
  assert.equal(source.split(END).length, 2, "Expected exactly one ingress END marker.");
  const start = source.indexOf(BEGIN);
  const end = source.indexOf(END) + END.length;
  assert.ok(end > start + BEGIN.length, "Ingress markers must be ordered.");
  const bounded = source.slice(start, end);
  assert.ok(bounded.includes(`var.${variableName}`), "Marker must bound the intended variable validation.");
  const original = 'rule.direction == "Inbound" && rule.access == "Allow" ? try(';
  assert.equal(bounded.split(original).length, 2, "Expected exactly one unmodified ingress predicate.");
  const newline = source.includes("\r\n") ? "\r\n" : "\n";
  const weakened = bounded
    .replace(BEGIN, `${BEGIN}${newline}  # SEEDED DEFECT: TEMPORARY MOCK COPY ONLY; wildcard sources bypass this guard.`)
    .replace(original, 'rule.direction == "Inbound" && rule.access == "Allow" && rule.source_address_prefix != "*" ? try(');
  // Only this bounded predicate is weakened. Other Internet/CIDR, priority,
  // protocol and port checks stay intact; the original files are never touched.
  return source.slice(0, start) + weakened + source.slice(end);
}

export function parseTerraformEvents(stdout) {
  assert.equal(typeof stdout, "string", "Expected Terraform JSON output.");
  const lines = stdout.split(/\r?\n/u).filter((line) => line.trim());
  assert.ok(lines.length > 0, "Terraform emitted no JSON events.");
  const events = lines.map((line) => {
    let event;
    try {
      event = JSON.parse(line);
    } catch {
      throw new Error("Terraform emitted non-JSON output; this is not seeded-defect evidence.");
    }
    assert.ok(event && typeof event === "object" && !Array.isArray(event), "Malformed Terraform event.");
    return event;
  });
  const versions = events.filter((event) => event.type === "version");
  assert.equal(versions.length, 1, "Expected exactly one Terraform UI version event.");
  assert.equal(versions[0].terraform, EXPECTED_TERRAFORM, "Use the pinned Terraform CLI.");
  assert.equal(String(versions[0].ui).split(".")[0], "1", "Unsupported Terraform JSON UI major version.");
  return events;
}

function readTestResult(result) {
  assert.ok(!result.error, "Terraform could not run or timed out; not seeded-defect evidence.");
  assert.ok(!result.signal, "Terraform was interrupted; not seeded-defect evidence.");
  assert.ok(Number.isInteger(result.status), "Terraform did not return a normal exit status.");
  const events = parseTerraformEvents(result.stdout);
  assert.ok(!events.some((event) => event.type === "test_interrupt"), "Tests were interrupted.");
  assert.ok(!events.some((event) => event.type === "test_cleanup"), "Mock cleanup failed.");
  const summaries = events.filter((event) => event.type === "test_summary");
  assert.equal(summaries.length, 1, "Expected one completed Terraform test summary.");
  const completed = events
    .filter((event) => event.type === "test_run" && event.test_run?.progress === "complete")
    .map((event) => event.test_run);
  const errors = events.filter((event) => event.type === "diagnostic" && event.diagnostic?.severity === "error");
  return { events, summary: summaries[0].test_summary, completed, errors };
}

export function assertMockSuitePassed(result) {
  assert.equal(result.status, 0, "The complete/repaired checkpoint must pass before crediting a seeded failure.");
  const { summary, completed, errors } = readTestResult(result);
  assert.equal(errors.length, 0, "Unexpected error diagnostic in the passing mock suite.");
  assert.equal(summary.status, "pass");
  assert.ok(summary.passed > 0, "An empty suite is not positive evidence.");
  for (const key of ["failed", "errored", "skipped"]) assert.equal(summary[key], 0, `Unexpected ${key} tests.`);
  assert.equal(completed.length, summary.passed);
  assert.ok(completed.every((run) => run.status === "pass"));
  assert.ok(completed.some((run) => isTargetFile(run.path) && run.run === TARGET_RUN), "The regression did not execute.");
  return summary;
}

export function assertSeededFailure(result, variableName) {
  assert.ok(["security_rules", "rules"].includes(variableName), "Unexpected input contract.");
  assert.equal(result.status, 1, "Seeded failure must be Terraform's normal test-failure exit, not an arbitrary nonzero.");
  assert.equal(String(result.stderr ?? "").trim(), "", "Unexpected stderr is not accepted as seeded-defect evidence.");
  const { summary, completed, errors } = readTestResult(result);
  // Observed Terraform 1.16.1 JSON: missing expect_failures is an error, not
  // an assertion failure (human output still says "1 failed"). Match exactly.
  assert.equal(summary.status, "error");
  assert.equal(summary.errored, 1);
  for (const key of ["passed", "failed", "skipped"]) assert.equal(summary[key], 0, `Unexpected ${key} tests.`);
  assert.equal(completed.length, 1, "Only the isolated regression must execute.");
  assert.equal(completed[0].run, TARGET_RUN);
  assert.ok(isTargetFile(completed[0].path), "Wrong test file failed.");
  assert.equal(completed[0].status, "error");
  assert.equal(errors.length, 1, "Unrelated errors must not masquerade as the seeded defect.");
  const error = errors[0];
  assert.equal(error.diagnostic.summary, "Missing expected failure");
  assert.match(String(error.diagnostic.detail), new RegExp(`\\bvar\\.${variableName}(?![\\w-])`, "u"), "The wrong validation was bypassed.");
  assert.ok(isTargetFile(error["@testfile"] ?? error.diagnostic.range?.filename), "Diagnostic belongs to another file.");
  if (error["@testrun"] !== undefined) assert.equal(error["@testrun"], TARGET_RUN);
  return summary;
}

export function makeOfflineEnvironment(original, scratch, dataDirectory) {
  // Allow only process/runtime and public download settings, not ARM_*, AZURE_*,
  // ACTIONS_*, GitHub tokens, TF_VAR_*, TF_CLI_ARGS*, TF_LOG or inherited state.
  const allowed = new Set([
    "PATH", "PATHEXT", "SYSTEMROOT", "WINDIR", "COMSPEC", "TEMP", "TMP",
    "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "SSL_CERT_FILE", "SSL_CERT_DIR",
    "TF_PLUGIN_CACHE_DIR",
  ]);
  const env = Object.fromEntries(Object.entries(original).filter(([key]) => allowed.has(key.toUpperCase())));
  return {
    ...env,
    HOME: join(scratch, "home"),
    USERPROFILE: join(scratch, "home"),
    APPDATA: join(scratch, "home", "AppData", "Roaming"),
    LOCALAPPDATA: join(scratch, "home", "AppData", "Local"),
    TF_CLI_CONFIG_FILE: join(scratch, "offline.tfrc"),
    TF_DATA_DIR: dataDirectory,
    TF_INPUT: "0",
    TF_IN_AUTOMATION: "true",
    CHECKPOINT_DISABLE: "1",
  };
}

async function copyCheckpoint(sourceRoot, destinationRoot) {
  const copied = [];
  const ignoredDirectories = new Set([".terraform", ".git", "node_modules", "docs", "evidence"]);
  async function visit(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      if (ignoredDirectories.has(entry.name)) continue;
      assert.ok(!entry.isSymbolicLink(), "Refuse symlinks in the checkpoint copy.");
      const source = join(directory, entry.name);
      if (entry.isDirectory()) {
        await visit(source);
      } else if (entry.isFile() && /(?:\.tf|\.tftest\.hcl|\.tfmock\.hcl|\.tfvars\.example|^\.terraform\.lock\.hcl)$/u.test(entry.name)) {
        const path = relative(sourceRoot, source);
        const destination = join(destinationRoot, path);
        await mkdir(dirname(destination), { recursive: true });
        await copyFile(source, destination);
        copied.push(normalizePath(path));
      } else if (/(?:\.tf\.json|\.tftest\.json|\.tfvars(?:\.json)?)$/u.test(entry.name)) {
        throw new Error("Unexpected auto-loaded Terraform input in the checkpoint; review it instead of silently omitting it.");
      }
      // Do not read/copy state, saved plans, credentials, caches or non-code files.
    }
  }
  await visit(sourceRoot);
  return copied;
}

export function assertMockOnlySource(path, code) {
  // A lightweight regression guard, not an HCL parser or a sandbox for hostile
  // code. Credential-free, unprivileged CI remains the actual trust boundary.
  // Match block syntax, not input-map keys such as data = { ... }.
  assert.ok(!/^\s*(?:(?:provider|backend|data|provisioner|action|ephemeral)\s+"|cloud\s*\{)/mu.test(code), `Unexpected live-capable block in ${path}.`);
  for (const match of code.matchAll(/^\s*source\s*=\s*"([^"]+)"/gmu)) {
    assert.ok(["hashicorp/azurerm", "./modules/subnet-security", "./tests/mocks"].includes(match[1]), `Unexpected dependency source in ${path}.`);
  }
  for (const match of code.matchAll(/^\s*resource\s+"([^"]+)"/gmu)) {
    assert.ok([
      "azurerm_virtual_network", "azurerm_subnet", "azurerm_network_security_group",
      "azurerm_network_security_rule", "azurerm_subnet_network_security_group_association",
    ].includes(match[1]), `Unexpected resource type in ${path}.`);
  }
  if (path.endsWith(".tftest.hcl")) {
    assert.equal([...code.matchAll(/^mock_provider "azurerm"\s*\{/gmu)].length, 1, `Missing unique mock provider in ${path}.`);
    assert.ok(!/^\s*(?:module\s*\{|providers\s*=|alias\s*=|override_module\s*\{)/mu.test(code), `Unexpected provider/module redirection in ${path}.`);
    const runs = [...code.matchAll(/^run "[^"]+"\s*\{/gmu)];
    const plans = [...code.matchAll(/^\s*command\s*=\s*plan\s*$/gmu)];
    assert.ok(runs.length > 0 && runs.length === plans.length, `Every run must explicitly use mock-only plan in ${path}.`);
  }
}

async function assertMockOnlyCheckpoint(directory, copied) {
  for (const path of copied) {
    if (!/\.(?:tf|tftest\.hcl|tfmock\.hcl)$/u.test(path)) continue;
    // Examples have their own configured provider but are never test targets.
    if (path.startsWith("examples/")) continue;
    assertMockOnlySource(path, await readFile(join(directory, path), "utf8"));
  }
  for (const prefix of ["", "modules/subnet-security/"]) {
    for (const file of ["main.tf", "outputs.tf", "variables.tf", "versions.tf", TARGET_TEST_FILE]) {
      assert.ok(copied.includes(`${prefix}${file}`), `Incomplete checkpoint: ${prefix}${file}.`);
    }
  }
}

function executeTerraform(binary, args, cwd, env) {
  const result = spawnSync(binary, args, {
    cwd,
    env,
    encoding: "utf8",
    shell: false,
    windowsHide: true,
    timeout: 600_000,
    maxBuffer: 32 * 1024 * 1024,
  });
  assert.ok(!result.error, "Terraform failed to start or timed out. Check TERRAFORM_BIN and provider download access.");
  assert.ok(!result.signal, "Terraform was interrupted.");
  return result;
}

export async function runSeededDefect() {
  const scratch = await mkdtemp(join(tmpdir(), "ws2-seeded-defect-"));
  try {
    const copy = join(scratch, "v1.0.0");
    const copied = await copyCheckpoint(CHECKPOINT, copy);
    await assertMockOnlyCheckpoint(copy, copied);
    await mkdir(join(scratch, "home", "AppData", "Roaming"), { recursive: true });
    await mkdir(join(scratch, "home", "AppData", "Local"), { recursive: true });
    await writeFile(join(scratch, "offline.tfrc"), "disable_checkpoint = true\n", "utf8");
    const configuredBinary = process.env.TERRAFORM_BIN || "terraform";
    // Resolve explicit relative paths before child processes use temporary cwd.
    const binary = /[\\/]/u.test(configuredBinary) ? resolve(configuredBinary) : configuredBinary;
    const roots = [
      { name: "baseline", path: copy, variable: "security_rules" },
      { name: "subnet-security", path: join(copy, "modules", "subnet-security"), variable: "rules" },
    ];
    const execute = (root, args) => executeTerraform(
      binary, args, root.path,
      makeOfflineEnvironment(process.env, scratch, join(scratch, `terraform-data-${root.name}`)),
    );
    const version = execute(roots[0], ["version", "-json"]);
    assert.equal(version.status, 0, "Unable to determine Terraform version.");
    assert.equal(JSON.parse(version.stdout).terraform_version, EXPECTED_TERRAFORM, "Use Terraform 1.16.1.");

    for (const root of roots) {
      const init = execute(root, ["init", "-backend=false", "-input=false", "-no-color"]);
      assert.equal(init.status, 0, `Offline ${root.name} initialization failed; this is not seeded-defect evidence.`);
      const versionAfterInit = execute(root, ["version", "-json"]);
      assert.equal(versionAfterInit.status, 0);
      assert.equal(JSON.parse(versionAfterInit.stdout).provider_selections?.["registry.terraform.io/hashicorp/azurerm"], "5.4.0", "Use AzureRM 5.4.0.");
      const summary = assertMockSuitePassed(execute(root, ["test", "-json", "-no-color"]));
      console.log(JSON.stringify({ phase: "original", module: root.name, ...summary }));
      root.original = await readFile(join(root.path, "variables.tf"), "utf8");
    }

    // Both public boundaries validate ingress. Weaken only the wildcard branch
    // in BOTH temporary copies so the parent test is not rescued by the child.
    for (const root of roots) {
      await writeFile(join(root.path, "variables.tf"), weakenIngressValidation(root.original, root.variable), "utf8");
    }
    for (const root of roots) {
      const summary = assertSeededFailure(execute(root, ["test", "-json", "-no-color", `-filter=${nativeTestFilter()}`]), root.variable);
      console.log(JSON.stringify({ phase: "seeded-defect-detected", module: root.name, diagnostic: "Missing expected failure", ...summary }));
    }

    for (const root of roots) await writeFile(join(root.path, "variables.tf"), root.original, "utf8");
    for (const root of roots) {
      const summary = assertMockSuitePassed(execute(root, ["test", "-json", "-no-color"]));
      console.log(JSON.stringify({ phase: "repaired", module: root.name, ...summary }));
    }
    console.log("AgentAlvine: the bounded wildcard defect was detected at both input boundaries; restored mock suites passed. No Azure integration was performed.");
  } finally {
    // Never clean a source directory. This is only the fresh OS temporary tree.
    await rm(scratch, { recursive: true, force: true, maxRetries: 3 });
  }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  runSeededDefect().catch((error) => {
    console.error(`Seeded-defect verification failed: ${error.message}`);
    process.exitCode = 1;
  });
}
