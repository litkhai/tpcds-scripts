# AGENTS.md

> Harness: khai-harness core@8f514e8 · context public · bilingual no

Instructions for coding agents working in this repository.

<!-- harness:core start — khai-harness core@8f514e8 · context public · 손으로 고치지 마세요 -->
**Context: public.** Public sources only — nothing from company connectors, internal hosts, internal wikis or
private repositories, and no link to them. gitleaks must pass before every commit. Claims name what was run.

## core — procedure for every repository and agent

The repository's own `AGENTS.md` adds its norms; this file does not repeat them.
Details are read on demand from `reference/`, never loaded automatically.

### Principles
<!-- from: runpod-hols AGENTS.md "Never" (3 of 5; the other two stay there) -->
- **Never spend without asking.** Deploying, launching paid compute, `terraform apply`. Read-only queries need no permission.
- **Never state a version, API shape or limit from memory.** Read the installed source, the live API or the published spec, and record in the page how it was confirmed.
- **Never commit secrets** — see Secrets.

### Evidence
<!-- from: runpod-hols AGENTS.md "Mistakes already made" (6 rows) -->
| What happened | Lesson |
|---|---|
| A log limit was documented as 10 MB, copying the SDK's own comment; the constant was 4096 | Vendor comments are not evidence |
| An SDK pin was bumped and "read at 1.11.0" stayed in six files | Version claims have locations; grep for all of them |
| A section was inserted at an anchor a previous trim had removed — the edit silently no-op'd | Assert the anchor exists before replacing |
| "The index lacks the repo" was claimed; the control query also returned zero | A negative with no positive control is not a result |
| A docs checker passed on its first run | Passing proves nothing. Inject the fault and watch it fire |
| Paths were flip-flopped instead of reading the build documentation | Find the documentation first. When it does not exist, say so |

### Verification claims
<!-- from: clickhouse-hols AGENTS.md "Verification claims" + "Running labs" (same rule in the 4 split repos) -->
Docs state the version a thing was verified against (e.g. *"Verified on <product> <version>"*).
Only write or update that line when it was actually executed end to end against that version.
If you change something without running it, leave the existing claim alone and say what was not re-run.
A green run of a narrower check (a smoke run on a newer image, a plan or validate) is not a reason to change it.

### Tracking work
<!-- from: clickhouse-hols AGENTS.md "Tracking work" (same text in the 4 split repos) -->
Planned work, re-verification and follow-ups are **issues**; every change lands through a
**pull request** that references its issue (`Closes #N`). `STATUS.md` is a snapshot of the
current state and links to the open issues instead of keeping its own to-do list. When you find
something to do that you are not doing now, open an issue rather than writing it into a README
or `STATUS.md`. Labels: `re-verify` (changed but not re-run), `enhancement`, `docs`, `ops`, `security`.

### Model roles
<!-- from: clickhouse-hols AGENTS.md "Model roles" (same text in the 4 split repos) -->
| Role | Model | Does |
|---|---|---|
| Lead | **Opus** | Plans and designs, writes and updates docs (READMEs, `AGENTS.md`, `STATUS.md`, issues, PR descriptions), splits the work into tasks, reviews what comes back |
| Implementer | **Sonnet** | Writes the code, scripts and SQL for a task the lead hands over, runs the checks, opens the PR |
| Status checker | **Haiku** | Read-only: CI results (and `smoke`, where the repository has one), open issues and PRs, link and syntax checks, what changed since the last look |

The lead gives the implementer one issue at a time with the design and the files to touch; the
implementer does not change the design or the docs' claims on its own. Only a real end-to-end
run updates a verification claim, whichever model ran it.
A repository whose `AGENTS.md` has its own model-roles table uses that table instead (models differ between personal and company work).

### Bilingual docs
<!-- from: clickhouse-hols AGENTS.md "Bilingual parity" -->
In a repository that declares `bilingual yes`: one README per lab, English first, `## English` / `## 한국어`.
When you edit substance in one language, edit the other. Details: `reference/bilingual.md`.

### Secrets
<!-- from: clickhouse-hols AGENTS.md "Before you commit" (gitleaks, core.hooksPath, hygiene) + runpod-hols "Never" (.env) -->
- Enable the guard once per clone: `git config core.hooksPath .githooks` (gitleaks).
- Never track a file that a `.gitignore` rule matches — ignore rules do not apply retroactively.
- No host paths (`/Users/…`, `/home/…`) in non-markdown files — derive paths from `BASH_SOURCE` or `__file__`.
- Never commit Terraform state or any zip-shaped file (a saved `tfplan` embeds the whole state).
- `.env` holds a live key, mode 600, gitignored.

### Customer identifiers
<!-- new: DESIGN v2 decision 6 -->
No customer names, hosts, accounts or alias maps in any repository. When text looks like one —
a name, a domain, a number with no source — do not write it; stop and ask.

### Roles (for runtimes that read only this file)
<!-- new: DESIGN v2 §4.1 — Claude Code reads the same roles from runtime/claude-code/agents/ -->
- `dev` implements one task from its `spec.md`; touches only `allowed`; runs every `verify` line and pastes the output; reports files changed, commands and output, what was not run, gaps in the spec.
- `sa` designs deliverables; every number carries its grade: measured (when, configuration) · vendor doc (link, date read) · unmeasured (marked as a hypothesis).
- `status` is read-only: CI (pick runs by `headSha`), open issues and PRs, drift, changes since the last check.
- If `AGENTS.md` and `spec.md` conflict, stop and ask.
<!-- harness:core end -->
