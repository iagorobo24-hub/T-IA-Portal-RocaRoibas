# TIA-Claude System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the current TIA-Claude workspace into a reproducible, safety-bounded system that lets an AI harness inspect, modify, compile, export and validate TIA Portal V20 projects through MCP, with Computer Use as the graphical fallback.

**Architecture:** Keep `AGENTS.md`, `10-kb/` and `20-standards/` as the harness-independent source of truth. Add an explicit MCP profile layer (`read`, `write`, `full`) generated from one manifest, a safe write runner that owns backup/preview/compile/save/export, and a golden E2E project used as the acceptance fixture. Keep HMI/runtime work separate from PLC/Openness work because the current machine does not have a matching V20 Runtime Advanced installation.

**Tech Stack:** Windows PowerShell, TIA Portal V20, Siemens Openness V20, .NET Framework 4.8, `tia-inspect` from `heilingbrunner/tiaportal-mcp`, optional `tia-create` V20 lite, MCP stdio/JSON-RPC, PLCSIM/PLCSIM Advanced, Markdown, JSON, Pester-compatible PowerShell tests.

**Spec:** `AGENTS.md`, `00-meta/01-arquitectura.md`, `00-meta/02-plan.md`, `00-meta/03-tdd.md`.

## Global Constraints

- TIA target is V20; V19 remains inspection-only until a separate compatibility phase is justified.
- Never invent Openness paths; derive them from `GetProjectTree`/`GetSoftwareTree`.
- Never write a project without a backup, a read/preview step, a minimal change, compilation and explicit persistence.
- Never edit know-how-protected blocks, F-blocks or safety tags.
- PLCSIM may be used without hardware permission; physical hardware always requires confirmation immediately before download.
- SCL is the preferred generated language; LAD is only imported from known-good sources/recipes.
- `.ap20` is an artifact; exported sources and reports are the reviewable evidence.
- Original V16 repositories and customer projects remain immutable and out of public packages by default.
- Every phase ends with a command or runtime observation that proves its acceptance criteria.

---

## Phase 0: Establish the actual baseline

### Task 0.1: Create a machine-state report

**Files:**
- Create: `30-tools/scripts/Write-TiaEnvironmentReport.ps1`
- Create: `70-runs/environment/latest.json`
- Modify: `30-tools/scripts/README.md`
- Test: `30-tools/tests/Test-EnvironmentReport.ps1`

**Interfaces:**
- Consumes: installed TIA/PLCSIM registry and filesystem state, `tia-inspect --doctor`.
- Produces: stable JSON with installed TIA versions, Openness group membership, MCP binaries, Runtime Advanced versions, PLCSIM versions and report timestamp.

- [x] Write a failing test that invokes the report with a temporary output path and asserts the JSON contains `tiaMajor`, `installedTia`, `mcpServers` and `runtimeAdvanced`.
- [x] Run the test and verify it fails because the script does not exist.
- [x] Implement the script using read-only PowerShell queries and invoke the existing MCP doctor through the checked-in executable.
- [x] Run the test and verify the output is valid JSON and contains the current V20 installation.
- [x] Run the report against `C:\Users\jose.mellid\TIA-Claude\70-runs\environment\latest.json` and record the actual current values.

### Task 0.2: Correct stale status documentation

**Files:**
- Modify: `30-tools/mcp/tia-inspect/README.md`
- Modify: `README.md`
- Modify: `AGENTS.md` only where the current verified state contradicts the text.
- Test: `30-tools/tests/Test-DocumentationState.ps1`

**Interfaces:**
- Consumes: `70-runs/environment/latest.json` and the existing Doctor output.
- Produces: documentation that distinguishes implemented, verified, pending and blocked items.

- [x] Add a test that fails when `tia-inspect/README.md` claims the Openness group is false while the current report says true.
- [x] Update the stale claim and the top-level status table.
- [x] Run the documentation test and scan for contradictory `False`/`True` claims.

### Task 0.3: Add an explicit current-state decision record

**Files:**
- Create: `00-meta/decisiones/ADR-009-estado-real-2026-09.md`
- Modify: `00-meta/01-arquitectura.md`
- Modify: `00-meta/02-plan.md`

**Interfaces:**
- Consumes: the environment report and the existing audit findings.
- Produces: a dated source of truth for the initial baseline. The current operational state is
  maintained by ADR-010 and the acceptance-status report; it supersedes the initial claims about
  absent `tia-create` and Git.

- [x] Write the ADR with evidence paths and explicit non-claims.
- [x] Link it from architecture and plan documents.
- [x] Verify every status sentence against the report or filesystem.

## Phase 1: Safe MCP write loop

### Task 1.1: Build the write-profile manifest

**Files:**
- Create: `30-tools/mcp/servers.json`
- Create: `30-tools/mcp/profiles/read.json`
- Create: `30-tools/mcp/profiles/write.json`
- Modify: `.mcp.json` to be generated/read-only and clearly marked.
- Test: `30-tools/tests/Test-ServerManifest.ps1`

**Interfaces:**
- Consumes: the V20 `tia-inspect` binary path relative to workspace root.
- Produces: a manifest that can generate a read-only config and a write config with `--allow-write` without hard-coded user names.

- [x] Write tests for relative path resolution and for the invariant that the read profile never contains `--allow-write`.
- [x] Verify the tests fail because the manifest/profiles do not exist.
- [x] Implement JSON manifest loading relative to the workspace root.
- [x] Run the tests and verify both profiles resolve to the current executable.

### Task 1.2: Add the profile synchronizer

**Files:**
- Create: `30-tools/scripts/Sync-HarnessConfigs.ps1`
- Modify: `30-tools/scripts/README.md`
- Test: `30-tools/tests/Test-SyncHarnessConfigs.ps1`

**Interfaces:**
- Consumes: `30-tools/mcp/servers.json`, profile name and destination workspace.
- Produces: `.mcp.json`, Claude Code MCP config, OpenCode MCP config and a local manifest with resolved absolute paths.

- [x] Write failing tests for `read` generation and for rejection of an unknown profile.
- [x] Verify failure.
- [x] Implement minimal generation for `.mcp.json` and local manifest; add other harness formats only when their schema is known.
- [x] Verify generated JSON parses and the read profile exposes no write flag.

### Task 1.3: Create the golden copy of the IOT PLC project

**Files:**
- Create: `90-tmp/e2e/README.md`
- Create by filesystem copy: `90-tmp/e2e/IOT2050_S7_CompleteProject_E2E_V20/`
- Create: `90-tmp/e2e/baseline.json`

**Interfaces:**
- Consumes: `50-examples/npatel-iot/02_S7_Project/IOT2050_S7_CompleteProject_V20/`.
- Produces: disposable E2E fixture with baseline project tree, block count, consistency and source hashes.

- [x] Verify source and project files exist before copying.
- [x] Copy the project to `90-tmp/e2e` without touching the original.
- [x] Run read-only MCP inventory on the copy and write `baseline.json`.
- [x] Verify the fixture has `PLC_1`, 8 consistent blocks and no safety/know-how-protected objects.

### Task 1.4: Prove a reversible write through MCP

**Files:**
- Create: `90-tmp/e2e/import/FB_AgentWorkflowProbe.scl`
- Create: `30-tools/scripts/Invoke-TiaWriteE2E.ps1`
- Create: `30-tools/tests/Test-TiaWriteE2E.ps1`
- Create: `70-runs/e2e/<timestamp>/report.json`

**Interfaces:**
- Consumes: golden project, `FB_AgentWorkflowProbe.scl`, `Invoke-TiaMcp.ps1`.
- Produces: a block generated in TIA memory, compile result, save result, exported source and machine-readable report.

- [x] Write the failing test asserting the report has `backup`, `preview`, `import`, `compile`, `save` and `export` results.
- [x] Verify it fails before the runner exists.
- [x] Implement the runner as staged MCP sessions: preflight, path inspection, backup, source import, compile, save, export and read-back verification.
- [x] Ensure the runner aborts before save if compile returns any error or inconsistent object.
- [x] Run it against the disposable copy with `--allow-write`.
- [x] Verify the new block is present, compilation has zero errors, the project is saved, and the export contains the block.
- [x] Preserve the report and leave the original example untouched.

### Task 1.5: Add failure recovery

**Files:**
- Modify: `30-tools/scripts/Invoke-TiaWriteE2E.ps1`
- Create: `30-tools/scripts/Restore-TiaBackup.ps1`
- Test: `30-tools/tests/Test-TiaBackupRecovery.ps1`

**Interfaces:**
- Consumes: a backup path and project path.
- Produces: refusal to restore an active/open project unless explicitly forced, and a verified restored copy.

- [x] Write tests for missing backup, active project guard and successful restore to a disposable destination.
- [x] Verify failure.
- [x] Implement restore with explicit path validation and no broad recursive deletion.
- [x] Run the tests and compare restored project file hashes with the backup source.

## Phase 2: Verification and standards gates

### Task 2.1: Add standards checker

**Files:**
- Create: `30-tools/scripts/Check-TiaStandards.ps1`
- Create: `30-tools/tests/Test-CheckTiaStandards.ps1`
- Modify: `20-standards/definition-of-done.md`

**Interfaces:**
- Consumes: MCP inventory JSON and exported sources.
- Produces: exit code 0 only when project naming, grouping, consistency, comments and export requirements pass; exit code 1 with structured findings otherwise.

- [x] Write tests covering a passing fixture and a fixture with an inconsistent block, default tag table usage and missing source export.
- [x] Verify failure.
- [x] Implement the smallest checks supported by currently available MCP data.
- [x] Run against all seven migrated examples and record findings without modifying them. Evidence: `70-runs/standards/sweep-20260915-all/sweep-report.json` — 7/7 collected, 0 collection errors, 3 blocking findings and 36 documentation warnings.

### Task 2.2: Create the ten-question knowledge evaluation

**Files:**
- Create: `00-meta/eval/kb-quiz.md`
- Create: `00-meta/eval/kb-answer-key.md`
- Create: `30-tools/tests/Test-KnowledgeIndex.ps1`

**Interfaces:**
- Consumes: `10-kb/` and the known Openness findings.
- Produces: a deterministic checklist proving that each important limitation and runbook is indexed.

- [x] Define questions for paths, sessions, backups, LAD/SCL, safety, compile/export and simulation.
- [x] Add answer references to exact files.
- [x] Run the index test and verify every answer reference exists.

## Phase 3: Creation server and project bootstrap

### Task 3.1: Obtain and verify the V20 `tia-create` runtime

**Files:**
- Modify: `30-tools/mcp/servers.json`
- Create: `30-tools/mcp/tia-create/README.md`
- Modify: `AGENTS.md` environment table.
- Test: `30-tools/tests/Test-TiaCreateAvailability.ps1`

**Interfaces:**
- Consumes: official/local V20 lite runtime or a source build validated against installed Openness.
- Produces: a version-pinned `tia-create` entry and a doctor check; if unavailable, a precise blocking report rather than a fake configuration.

- [x] Write the availability test before adding the server entry.
- [x] Verify it fails because the runtime is currently absent.
- [x] Install or build only after the exact artifact is identified and authorized: `2.7.2` from `bulaofen0036-coder/TIA_Portal_Openness_MCP` V20 source.
- [x] Run its doctor/bootstrap command and verify the server starts and publishes its expected tools: MCP smoke, 55 lite tools.

### Task 3.2: Add a project scaffold acceptance fixture

**Files:**
- Create: `50-examples/agent-demo/specs/scaffold.json`
- Create: `50-examples/agent-demo/README.md`
- Create: `30-tools/tests/Test-AgentDemoScaffold.ps1`

**Interfaces:**
- Consumes: `tia-create`, the standards and library.
- Produces: a V20 project with a PLC, symbolic tags, standard groups, a motor/valve pattern and a compile report.

- [x] Write the fixture assertions before scaffold implementation.
- [x] Verify the original failure while `tia-create` was absent; retain the availability gate.
- [x] Implement the smallest scaffold supported by the selected server, including a hard guard
  against replacing a visible user TIA instance and a post-apply verification pipeline.
- [x] Compile, inspect and export the generated project. Evidence: `70-runs/e2e/agent-demo-scaffold-20260915-102334/scaffold-report.json` — 0 errors, 0 warnings, tree/readback, source-tree export and individual `FB_AgentDemo.xml` export.
- [x] Verify the generated project can be opened and inspected by V20 Openness and that the standards checker passes. The checker leaves one non-blocking `MISSING_BLOCK_COMMENT` warning because the scaffold source comments are not imported as block header metadata.
- [x] Add a reusable single-session MCP sequence runner and document the mixed LAD/SCL export fallback discovered during acceptance.

## Phase 4: HMI and simulation

### Task 4.1: Build the HMI knowledge base

**Files:**
- Create: `10-kb/40-hmi/README.md`
- Create: `10-kb/40-hmi/runtime-version-matrix.md`
- Create: `10-kb/40-hmi/comfort-advanced.md`
- Create: `10-kb/40-hmi/unified.md`
- Create: `10-kb/20-recetas/R13-pantalla-hmi.md`
- Create: `10-kb/20-recetas/R14-binding-hmi-plc.md`

**Interfaces:**
- Consumes: installed TIA/WinCC versions, official Siemens documentation and verified Computer Use observations.
- Produces: recipes that explicitly distinguish Unified, Comfort/Advanced and Runtime Advanced simulation.

- [x] Add version/device/license preconditions to each recipe.
- [x] Add the current Runtime V17/V20 mismatch as a known failure.
- [x] Verify all referenced tools and paths exist or are marked unavailable.

### Task 4.2: Validate PLC simulation with the sorting-plant example

**Files:**
- Modify: `50-examples/npatel-sorting-plant/FICHA.md`
- Create: `70-runs/simulation/sorting-plant-acceptance.md`
- Create: `30-tools/scripts/Test-SortingPlantSimulation.ps1`

**Interfaces:**
- Consumes: TIA V20, PLCSIM Advanced V6.0, migrated sorting project.
- Produces: evidence for compile, virtual PLC startup, HMI connection and at least one sequence transition; NX MCD remains explicitly out of scope unless installed.

- [x] Write the acceptance checklist first.
- [x] Run the safe TIA/Openness preflight without replacing the user's open project: attach by
  exact project name, compile with 0 errors/0 warnings, and confirm `CheckDownloadReadiness=true`.
- [x] Discover and initialize the installed PLCSIM Advanced V6 runtime API with a read-only probe.
- [x] Add and verify a native C++ lifecycle adapter that registers and unregisters a disposable
  virtual CPU without powering it on or downloading to it.
- [x] Verify a disposable virtual CPU PowerOn/PowerOff cycle with no project download and no
  remaining PLCSIM instance/process.
- [ ] Register a disposable virtual CPU, download only to that virtual target, observe a sequence
  transition, and write verified behavioral evidence.
- [x] Record the current blocker and keep behavioral simulation unverified rather than marking it successful from compilation alone.

The live acceptance state is generated by `30-tools/scripts/Write-TiaAcceptanceStatus.ps1` and is
intentionally independent from the green local workspace checks.

### Task 4.3: Resolve or document WinCC Runtime Advanced V20

**Files:**
- Create: `70-runs/simulation/runtime-advanced-v20.md`
- Modify: `50-examples/orsin-wincc-games/FICHA.md`
- Modify: `10-kb/50-errores/README.md`

**Interfaces:**
- Consumes: official TIA V20 installation media if available.
- Produces: verified Runtime Advanced V20 installation or a documented incompatibility/workaround.

- [x] Inspect the current installed runtimes and record the exact V17/V20 mismatch.
- [x] Inspect the available installation locations with a read-only media scanner; no official V20
  Runtime Advanced medium is currently present.
- [x] Add a deterministic simulation-readiness preflight that keeps PLC, HMI, behavior and session
  safety as separate gates.
- [x] Add a read-only PLCSIM virtual-adapter gate; the current machine reports the Siemens adapter
  present but `Not Present`, so no download route is accepted yet.
- [ ] Install only after a candidate is reviewed and the user confirms the action at that time.
- [ ] Retry the games simulation and record whether the device is supported.

## Phase 5: Portable distribution and harnesses

### Task 5.1: Split the portable package into core and examples

**Files:**
- Modify: `TIA-Claude_Portable/install/Install-TIA-Claude.ps1`
- Modify: `TIA-Claude_Portable/install/Verify-TIA-Claude.ps1`
- Modify: `TIA-Claude_Portable/manifests/package-info.json`
- Create: `TIA-Claude_Portable/build/Build-PortablePackage.ps1`
- Create: `TIA-Claude_Portable/tests/Test-PortablePackageContent.ps1`

**Interfaces:**
- Consumes: server manifest, workspace files and optional examples bundle.
- Produces: a smaller core package, a separately hashable examples package and installer-generated local configs.

- [x] Write tests that assert core contains no project `.ap20`/customer artifacts and that examples has an explicit manifest.
- [x] Verify failure against the current monolithic package.
- [x] Implement deterministic package generation with SHA-256 manifests.
- [x] Run package structure and hash tests.

### Task 5.2: Generate Claude Code, Codex and OpenCode configurations

**Files:**
- Modify: `30-tools/scripts/Sync-HarnessConfigs.ps1`
- Create: `30-tools/harnesses/claude-code.md`
- Create: `30-tools/harnesses/codex.md`
- Create: `30-tools/harnesses/opencode.md`
- Create: `TIA-Claude_Portable/docs/harnesses.md`

**Interfaces:**
- Consumes: the profile manifest.
- Produces: documented generated config for each harness and a smoke test that checks paths, arguments and profile.

- [x] Add one schema fixture per supported harness, based on the verified Claude JSON, Codex TOML
  and OpenCode local-MCP formats.
- [x] Generate read-only configs first.
- [x] Generate write configs only when explicitly selected.
- [x] Run deterministic adapter tests for Claude Code, Codex and OpenCode. They export fragments
  but do not mutate personal harness configuration; Antigravity remains an unverified adapter.

## Phase 6: Repository and release discipline

### Task 6.1: Initialize Git with confidentiality boundaries

**Files:**
- Create: `.git/` via `git init` only after confirming repository policy.
- Modify: `.gitignore`
- Create: `40-projects/.gitignore`
- Create: `SECURITY.md`
- Create: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: the decision in `00-meta/03-tdd.md` about public/private workspace and customer data.
- Produces: a repository where `_ref`, `70-runs`, `90-tmp`, binary TIA projects and customer projects are excluded by default.

- [x] Verify no customer project is staged before the first commit.
- [x] Add the ignore rules and a staged-file audit script.
- [x] Run the audit and commit only after the boundary passes.

### Task 6.2: Add CI-independent local release checks

**Files:**
- Create: `30-tools/scripts/Run-WorkspaceChecks.ps1`
- Create: `30-tools/tests/Test-WorkspaceChecks.ps1`
- Modify: `README.md`

**Interfaces:**
- Consumes: environment report, package verifier, standards checker and documentation index.
- Produces: one command with clear PASS/WARN/BLOCKED sections and non-zero exit on unsafe release state.

- [x] Write the failing test for an incomplete or unsafe aggregate report.
- [x] Implement the aggregator.
- [x] Run it on this machine and record the current aggregate state: 25 PASS, 0 WARN, 0 BLOCKED.

## Phase 7: Semantic engineering workflows

### Task 7.1: Generate a deterministic read-only project dossier

**Files:**
- Create: `30-tools/scripts/Invoke-TiaProjectAnalysis.ps1`
- Create: `30-tools/tests/Test-TiaProjectAnalysis.ps1`
- Modify: `30-tools/scripts/Run-WorkspaceChecks.ps1`
- Modify: `30-tools/scripts/README.md`

**Interfaces:**
- Consumes: a `readOnly` inventory from `tia-inspect` and exported `.s7dcl`, `.s7res` and XML sources.
- Produces: `analysis.json` plus `analysis.md` with PLC/block/language inventory, source coverage,
  call references, safety/protection findings and next actions.

- [x] Write a test for a clean SCL fixture, an individual XML block export and a protected-block gate.
- [x] Verify the missing analyzer fails before implementation.
- [x] Implement the analyzer without connecting to or modifying TIA.
- [x] Run it against the agent-demo acceptance evidence and correct the XML/export coverage case.
- [x] Add it to the aggregate workspace checks.

### Task 7.2: Build a proposal-only SCL change workflow

**Files:**
- Create: `30-tools/scripts/New-TiaSclProposal.ps1`
- Create: `30-tools/tests/Test-TiaSclProposal.ps1`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: a read-only project dossier, one complete SCL source and a user objective.
- Produces: a proposed patch/diff and a human-readable impact report; it must not import, save or
  download anything. Applying the proposal remains a separate write-gated operation.

- [x] Define the proposal schema and refusal cases (protected, inconsistent, ambiguous or missing source).
- [x] Add failing tests for a minimal SCL change and for refusal to propose against protected data.
- [x] Implement deterministic patch generation with no direct TIA side effect.
- [x] Validate the proposal against the SCL style and naming standards.

### Task 7.3: Add a semantic workflow runner

**Files:**
- Create: `30-tools/scripts/Invoke-TiaWorkflow.ps1`
- Create: `30-tools/tests/Test-TiaWorkflow.ps1`
- Modify: `TIA-Claude_Portable/docs/funcionamiento.md`

**Interfaces:**
- Consumes: workflow name, project snapshot and explicit profile.
- Produces: one traceable report linking discovery, dossier, proposal, optional write E2E and export.

- [x] Implement `analyze` as the first workflow and keep `propose`/`apply` explicit.
- [x] Enforce the `read` profile and keep snapshot workflows free of TIA mutation; live MCP lease enforcement remains required for the future apply workflow.
- [x] Add a disposable end-to-end workflow test before enabling real project application.

## Final acceptance gate

The system is complete only when all of the following are evidenced:

- A cold-start Doctor passes on a clean TIA V20 machine.
- Read-only MCP configuration works in at least two harnesses.
- Write E2E on a disposable project performs backup, import, compile, save and export.
- A failed compile prevents saving.
- A restore returns the fixture to the baseline hash set.
- The standards checker evaluates the acceptance project.
- A read-only semantic dossier can be regenerated from the same inventory and exports.
- Proposal and apply remain separate operations with a traceable report.
- `tia-create` is either verified or explicitly excluded with a maintained blocker.
- PLC simulation has one demonstrated behavioral test.
- HMI simulation has a version-compatible demonstrated test or a documented missing prerequisite.
- The portable core package installs from a relative location without the original user name.
- No customer project or physical hardware is touched automatically.
