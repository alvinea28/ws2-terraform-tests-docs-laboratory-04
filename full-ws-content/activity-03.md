# Activity 03 — Generate the actual module interface

[Review index](README.md) · [Full setup](00-start-here.md) · [Previous activity](activity-02.md) · [Next activity](activity-04.md) · [Simulation record](simulation.md)

> Review copy; follow your private copy’s live Exercise issue to do the lab.

<!-- FULL-WS-LESSON:START -->
## Laboratory 04 - Step 3/4

**Goal:** Generate the actual module API twice, then verify freshness without writing.

**Work:** your private copy's root, branch `lab/tests-docs`.
**Files:** generate [docs/module-api.md](../docs/module-api.md); read [scripts/generate-docs.mjs](../scripts/generate-docs.mjs) and [exercises/terraform-docs.yml](../exercises/terraform-docs.yml).

[Setup](../docs/start-here.md) · [Git help](../docs/git-workflow.md) · [Toolchain](../docs/toolchain.md) · [Recovery](../docs/troubleshooting.md)

### Do 1 — Read the renderer

Read `renderDocumentation` and `generateDocumentation`: the script uses canonical terraform-docs standard output with the supplied configuration. Compare [variables.tf](../variables.tf) and [outputs.tf](../outputs.tf), but do not edit their interface, validations or locks.

Keep Node **24.16.0**, Terraform **1.16.1**, AzureRM **5.4.0**, and terraform-docs **0.24.0**. Generate from **this root**, not a solution directory or another lab. Resolve any unsaved API buffer before generation.

### Do 2 — Generate once

In **Terminal → New Terminal** at the clone root:

```powershell
node scripts/generate-docs.mjs
```
**Why:** The published script checks terraform-docs 0.24.0 and writes the actual root's canonical API. **Expect:** a generation-success message and an updated document. If the tool/version/root is wrong, stop and use the toolchain guide; do not hand-type a table.

### Do 3 — Inspect the generated contract

Open [docs/module-api.md](../docs/module-api.md) and its **Source Control** diff. Check:

| Section | Required content |
| --- | --- |
| Requirements / Providers | Terraform `= 1.16.1`, AzureRM `= 5.4.0`. |
| Inputs | Name, existing resource group, location, address space, subnet map, tags, optional `security_rules`. |
| Outputs | `vnet_id`, `subnet_ids`, `nsg_id`, `association_ids`. |
| Modules / Resources | The included subnet-security child and actual resource addresses. |

Stable map keys and caller-owned group/provider/state boundaries must remain clear. Empty custom rules retain Azure defaults, not zero trust or a full egress policy. This complete baseline has four outputs; do not copy another lab's interface.

### Do 4 — Generate again, then check

Run the exact generator a **second time**:

```powershell
node scripts/generate-docs.mjs
```
**Why:** Repeating generation checks stability. **Expect:** another success message with no further content change from the first output. Compare the diff; if it changes again, resolve editor/formatter interference before continuing.

Then check without writing:

```powershell
node scripts/generate-docs.mjs --check
```
**Why:** `--check` compares the saved API with the same renderer's output. **Expect:** `Generated module API is current.` and exit 0. A stale/missing document fails; regenerate from this root and inspect it, never patch expected rows or add wrappers.

Never substitute raw terraform-docs output-file mode, wrapper comments or reference tables. Keep freshness checks and pins intact. No Azure login, backend/state access or real plan/apply is needed.

### Do 5 — Save and advance

**Save → stage → commit → push → refresh the SAME Exercise.** Review/stage only the generated API; use `lab: generate the canonical module API` and [Git help](../docs/git-workflow.md).

In **Actions → Lab checks → newest commit → Test learner module**, find the helper's actual `Canonical generated module API is current.` line or first error. AgentAlvine checks the required sections, four output names and absence of `TODO`; final CI verifies freshness. If stale remotely, check which saved file/commit was pushed. README work remains separate even with green CI.

![Microsoft reference showing Stage Changes](../docs/images/vscode-stage.png)
*REFERENCE — Microsoft, CC BY 3.0 US; not your staged document. [Attribution](../docs/images/NOTICE.md).*

**Next:** [Step 4 — consumer guidance and full checks](activity-04.md).
<!-- FULL-WS-LESSON:END -->

## Recorded simulation outcome

**2026-09-08 — Cycle A: recorded verified; Cycle B: recorded verified.** Both Revision 4 private simulations recorded the generated API gate and completed the canonical freshness lane. These completed A/B results must not be relabelled as an unresolved documentation-generator blocker from an earlier run.

Whole-lab Node and mocked case/fixture totals are not per-activity tests or separate proof of every generator experiment. Fresh 2026-09-14 checks remain separate; see the [simulation record and documentation-evidence limits](simulation.md).
