# GitHub Pages site for adept — design

Date: 2026-08-25 · Issue: [#234](https://github.com/randomparity/adept/issues/234) · ADR: [0034](../../adr/0034-the-site-publishes-a-staged-copy.md)

## Goal

Someone who has never heard of adept can be sent one URL —
`https://randomparity.github.io/adept/` — and learn from it what adept is, what it ships,
what makes it different from other workflow tooling, and how to install and run it in the
next five minutes. The page they land on is `README.md`, restructured for that reader and
published without a second copy of its prose existing anywhere.

## Current state

`README.md` is 105 lines written for someone already standing in the repository: it opens
with the distribution mechanism and an ADR link, states install and update commands, and
carries one paragraph ("What ships") plus one paragraph on the `$quest` pipeline. There is
no feature list, nothing that compares adept to anything else, and no worked example.

Two of its factual claims have gone stale — it says "27 skills" and "3 references" where
`ls skills | wc -l` reports 28 and `ls references | wc -l` reports 4.

GitHub Pages is off for this repository: `gh api repos/randomparity/adept/pages` returns
404. There is one workflow, `.github/workflows/verify.yml`. There is no `CHANGELOG`, no git
tag, and no GitHub release — [ADR 0006](../../adr/0006-release-management-out-of-scope.md)
and [ADR 0001](../../adr/0001-distribution-via-plugin-marketplace.md) hold that ground, and
this change does not reopen it.

## Scope

Frozen in the `WORK:SCOPE` annotation on issue #234, token `q234-2dda3086`. The two design
questions the issue left open were settled by the operator before this design started:

- **The site is two pages** — the README-derived landing page and `docs/cheatsheet.md`.
  ADRs, specs, plans, and benchmarks are excluded.
- **No changelog link.** The issue asked for one; the repository has nothing to link, and
  ADR 0001 and ADR 0006 are not reopened to create one.

## Decision

### Architecture

Four pieces, each with one job.

| Piece | Answerable for |
|---|---|
| `README.md` | The landing page's prose. The single source; nothing copies it. |
| `site/_config.yml` | Jekyll's view of the staged site: title, description, theme, `baseurl`. |
| `scripts/build-site.sh` | Assembling a staged site directory from tracked sources, and refusing to assemble one whose links do not resolve. |
| `.github/workflows/pages.yml` | Running that assembly on `main`, rendering it, and deploying it. |

Pages source is **GitHub Actions**, and the workflow publishes a staged directory rather
than the repository. [ADR 0034](../../adr/0034-the-site-publishes-a-staged-copy.md) records
that decision and the alternatives; this spec does not restate its reasoning.

### `scripts/build-site.sh`

```
usage: build-site.sh <output-dir>
```

The output directory must not exist, or must exist and be empty. The script creates it and
writes only inside it; it never modifies a tracked file.

**Exit contract**, matching the gate scripts already in `scripts/`:

- `0` — the staged site was assembled.
- `1` — a content finding: a Markdown link in a staged source names a path that is not a
  tracked file. The message names the source file and the unresolved target.
- `2` — a fault: wrong arguments, a missing source file, an output directory that exists
  and is not empty, or a failure to create or write the output.

**What it stages**, and nothing else:

| Source | Destination |
|---|---|
| `site/_config.yml` | `<out>/_config.yml` |
| `README.md` | `<out>/index.md` |
| `docs/cheatsheet.md` | `<out>/cheatsheet.md` |
| `docs/assets/adept-logo-grimoire.png` | `<out>/assets/adept-logo-grimoire.png` |
| `docs/assets/adept-quest-map.png` | `<out>/assets/adept-quest-map.png` |

**Transformations**, applied to the two staged Markdown pages in this order:

1. **Leading H1 removal, `index.md` only.** If the first line of `README.md` is an ATX H1,
   that line and any blank line following it are dropped. The theme's header renders the
   site title above the page content, so an unmodified `README.md` would show "adept"
   twice. `cheatsheet.md` keeps its H1 (`# Skill cheat sheet`), which distinguishes the page
   from the site title rather than repeating it.
2. **Front matter injection.** Each staged page gains a three-line front-matter block
   naming `layout: default` and the page's `title`, which becomes the browser tab title.
3. **Link rewriting**, applied to every `](target)` occurrence, first match wins:
   1. `docs/cheatsheet.md` → `cheatsheet.html` — the other page of this site.
   2. `docs/assets/<file>` → `assets/<file>` — staged alongside.
   3. Any target that does not begin with `http://`, `https://`, `#`, `/`, or `mailto:` →
      `https://github.com/randomparity/adept/blob/main/<target>`.

   Rules 1 and 2 produce site-relative links with no leading slash, so they resolve under
   the project page's `/adept/` prefix without the script knowing what that prefix is.

**Link verification** runs before rewriting and is what earns exit 1: every target matched
by rule 1, 2, or 3 must be a tracked file (`git ls-files --error-unmatch`). A `README.md`
link to a deleted ADR therefore reddens `just verify` rather than shipping a 404. Targets
matched by no rule — absolute URLs, fragments, `mailto:` — are not checked; they are
outside the repository and this gate makes no claim about them.

**Self-check** runs after rewriting: no relative link may remain in a staged page other
than `cheatsheet.html` and `assets/…`. A failure here means the script's own rules
disagreed with each other and reports exit 2, not exit 1 — it is a fault in the tool, not a
finding about the content.

The repository slug and branch in rule 3 are constants at the top of the script. Deriving
them from `git remote get-url origin` would produce a different answer for an SSH remote, an
HTTPS remote, and a CI checkout, so the constant is pinned and its suite pins it too.

### `site/_config.yml`

```yaml
title: adept
description: Development-workflow skills for Claude Code and Codex, distributed as a plugin.
theme: jekyll-theme-cayman
baseurl: /adept
```

`baseurl` is what makes the theme's own stylesheet resolve: `jekyll-theme-cayman`'s layout
links its CSS through Jekyll's `relative_url` filter, which prepends `site.baseurl`. Left
empty, the project page at `randomparity.github.io/adept/` would request the stylesheet
from the domain root and render unstyled. `/adept` is correct for any fork that keeps the
repository name, which is what a project page's path is built from.

### `.github/workflows/pages.yml`

Two jobs, so the elevated grant sits only on the one that needs it.

```yaml
name: Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: pages
  cancel-in-progress: false
```

- **`build`** (`permissions: contents: read`) — checkout with `persist-credentials: false`,
  run `./scripts/build-site.sh ./_site-src`, render with `actions/jekyll-build-pages`
  (`source: ./_site-src`, `destination: ./_site`), upload with
  `actions/upload-pages-artifact` (`path: ./_site`).
- **`deploy`** (`needs: build`, `permissions: pages: write, id-token: write`,
  `environment: github-pages`) — `actions/deploy-pages` and nothing else. It checks out no
  code and runs none of this repository's own.

Every `uses:` is pinned to a full commit SHA with a version comment, the convention
`verify.yml` already follows and `zizmor` audits under `just actions-check`. The staged
directory lives inside the workspace because `actions/jekyll-build-pages` is a Docker
action and sees only what is mounted there.

The workflow does **not** run on `pull_request`. A fork PR therefore never reaches the
`pages: write` grant, and the site only ever reflects `main`.

### Guardrail wiring

A new `site-check` recipe assembles the site into a scratch directory, discards it, and
joins the `verify` recipe's dependency list. CI reaches it the same way everything else
does — `just ci` → `just verify` — with no re-typed command string. The Pages workflow
calls `scripts/build-site.sh` by path rather than through `just`; the script is the single
implementation and both callers name it, so there is nothing to drift.

`scripts/build-site.sh` and `scripts/build-site-test.sh` are discovered automatically by
`scripts/list-shell-sources.sh`, so `just lint` and `just format-check` cover them with no
recipe edit, and `just test` discovers the suite by its `-test.sh` name.

### Enabling Pages

One time, by an operator with admin on the repository:

```sh
gh api -X POST repos/randomparity/adept/pages -f build_type=workflow
```

The workflow does not do this. `actions/configure-pages`'s `enablement` input requires a
token other than `GITHUB_TOKEN`, and this repository holds no secrets — ADR 0034 records
why that trade is refused. Until the setting exists, the `deploy` job fails naming it.

### `README.md` restructure

Same file, rewritten for a reader who has not seen adept before, in this order:

1. **What it is** — one paragraph and the logo.
2. **Install** — Claude Code and Codex CLI, as today.
3. **Quick start** — a worked first run: install, `/sort-board` to create the label set the
   pipeline needs, `/quest <issue>`, and what the operator sees at each stop. The issue asks
   for a "meaningful quick start / new user demo"; a command list without the stops is not
   one, because the stops are what the pipeline is.
4. **What makes adept different** — three claims, each stated against what it is different
   *from*: work state lives on GitHub rather than in a session, design is reviewed
   adversarially before code exists, and the vocabulary is a D&D one that names the phase
   rather than the tool.
5. **What ships** — the feature list: every skill, grouped by the phase it belongs to, one
   line each. The cheat sheet is linked from here.
6. **Working on this repository** — as today.
7. **Licence** — as today.

The stale counts go, and they go by removal rather than correction: a grouped list of the
skills is the feature list the issue asks for *and* it drops the number that was wrong.
ADR 0006's Consequences require README's workflow section to keep its pointer to that
record; the restructure keeps it, in the section describing the pipeline.

No prose gate is added. Anatomy rule 4 forbids one, and a list that names every skill can
still fall behind the directory — a structural check that `skills/<name>/` is named in the
feature list would catch it, but that is a new gate on a surface this charter does not
cover. It is filed as follow-up work instead.

## Threat model

The change adds a workflow that holds `pages: write` and `id-token: write`, adds four
third-party action references, and publishes a public website. That is security-relevant on
three of `$quest` step 6's triggers, so the controls below are acceptance criteria, not
commentary.

### Boundary inventory

**Added:**

- A GitHub Actions workflow that can write to the repository's Pages deployment and mint an
  OIDC token.
- A public HTTPS site serving content built from `main`.
- Four third-party actions executing in CI with the job's permissions.

**Widened:** none. `contents: read` and `persist-credentials: false` match `verify.yml`.

### Actor model

| Actor | Reaches | Trusted with |
|---|---|---|
| Anonymous internet | The published static site | Nothing. The site takes no input; there is no form, no query handling, no server-side code. |
| Contributor without merge rights | A pull request | Nothing new. The Pages workflow has no `pull_request` trigger. |
| Contributor with merge rights on `main` | What publishes | Everything. Merging to `main` now also publishes, and this is the trust the design places deliberately. |
| The four pinned actions | The job's token and the workspace | Their pinned revision, and no more. |

### Control per boundary

| Boundary | Control | Fails how |
|---|---|---|
| Trigger | `on: push: branches: [main]` and `workflow_dispatch` only — no `pull_request`, no `pull_request_target` | An untrusted fork PR cannot start a deployment |
| Token scope | Workflow-level `contents: read`; `pages: write` and `id-token: write` on the `deploy` job alone, which runs no repository code | A compromised build step holds only read |
| Checkout credentials | `persist-credentials: false` | No checkout token left in `.git/config` for a later step |
| Third-party code | Every `uses:` pinned to a full commit SHA, audited by `zizmor` in `just actions-check` | A moved tag does not change what runs |
| Build inputs | `scripts/build-site.sh` reads only the five paths it names and writes only under its output directory; it renders no content and executes none | A file added elsewhere in the tree cannot enter the build |
| Published content | Default-closed page set (ADR 0034 decision 2) | Nothing publishes that a reviewer did not add to the script |
| Concurrent deploys | `concurrency: group: pages, cancel-in-progress: false` | Two merges cannot interleave one deployment |

Every published byte is already public: this is a public repository, and the staged sources
are five tracked files from it. The site discloses nothing that a clone does not.

### Explicitly out of scope

- **Custom domain, DNS, CNAME verification.** Not requested; the default `github.io` host
  is used, and a domain takeover risk needs a domain first.
- **Response headers and Content Security Policy.** GitHub Pages sets these and gives a
  project no way to configure them.
- **Availability of the published site.** GitHub's.
- **The Docker image behind `actions/jekyll-build-pages`.** That action resolves
  `ghcr.io/actions/jekyll-build-pages:v1.0.13` by *tag* inside its own `action.yml`, so
  pinning the action to a SHA pins the reference and not the image digest. Accepted: the
  tag is GitHub's own, and nothing here can pin a transitive image digest.
- **Secret handling.** The change introduces no secret. If a later change needs one — a
  custom domain token, `enablement: true` — this section is where the omission stops being
  true and the model needs revisiting.

## Testing

`scripts/build-site-test.sh`, a behaviour suite on the repository's existing scaffold
(`scripts/test-fixture-helpers.sh`), discovered by `just test`. It builds disposable
fixture repositories rather than asserting against the live tree, so a later `README.md`
edit does not redden it.

Cases:

| # | Behaviour |
|---|---|
| 1 | A well-formed fixture stages exactly the expected file set and no more |
| 2 | `README.md`'s leading H1 and its following blank line are dropped from `index.md` |
| 3 | `docs/cheatsheet.md`'s H1 survives in `cheatsheet.md` |
| 4 | Front matter is prepended to both pages and names `layout: default` |
| 5 | `](docs/cheatsheet.md)` becomes `](cheatsheet.html)` |
| 6 | `](docs/assets/x.png)` becomes `](assets/x.png)` |
| 7 | `](docs/adr/0001-x.md)` becomes the `blob/main` URL |
| 8 | `](https://…)`, `](#frag)`, and `](mailto:…)` are left alone |
| 9 | A link to an untracked path exits 1 and names the source file and the target |
| 10 | A missing source file exits 2 |
| 11 | A non-empty output directory exits 2 and leaves it untouched |
| 12 | No argument, and more than one argument, exit 2 |
| 13 | The live repository assembles cleanly — the case `just site-check` runs |

Case 13 is the one that runs against real content, and it is the reason the recipe joins
`verify`: it is what turns a broken README link into a red gate.

Beyond the suite, the change is proven end to end by the deployment itself. Unit tests
cannot show that `jekyll-theme-cayman` resolves, that `baseurl` is right, or that the
"View on GitHub" button the theme renders from `site.github` metadata appears — those are
claims about a build this repository does not run locally. They are verified by loading
the published page after the first `main` deployment, and until then they are stated as
expectations rather than facts.

## Acceptance criteria

1. `https://randomparity.github.io/adept/` serves the restructured `README.md`, styled, with
   its images and a working link to the cheat sheet page.
2. `https://randomparity.github.io/adept/cheatsheet.html` serves `docs/cheatsheet.md`.
3. Every other link on both pages resolves — in-repository ones to `blob/main` URLs,
   external ones unchanged.
4. `README.md` carries the feature list, the differentiators, and the quick start the issue
   asks for, and states no count that `ls skills` can contradict.
5. `just verify` is green, including `site-check` and the new suite.
6. `just actions-check` is green: `actionlint` and `zizmor` both pass on `pages.yml`.
7. No content is duplicated: `README.md` and `docs/cheatsheet.md` remain the only copies of
   their prose.
8. The Pages workflow has no `pull_request` trigger, and `pages: write` appears only on the
   `deploy` job.
9. `.claude-plugin/plugin.json` declares a version greater than `2.9.5`.
