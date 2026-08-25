# GitHub Pages site for adept — design

Date: 2026-08-25 · Issue: [#234](https://github.com/randomparity/adept/issues/234) · ADR: [0034](../../adr/0034-the-site-publishes-a-staged-copy.md)

## Goal

Someone who has never heard of adept can be sent one URL —
`https://randomparity.github.io/adept/` — and learn from it what adept is, what it ships, what
makes it different from other workflow tooling, and how to install and run it in the next five
minutes. The page they land on is `README.md`, restructured for that reader and published
without a second copy of its prose existing anywhere.

## Current state

`README.md` is 105 lines written for someone already standing in the repository: it opens with
the distribution mechanism and an ADR link, states install and update commands, and carries one
paragraph ("What ships") plus one paragraph on the `$quest` pipeline. There is no feature list,
nothing that compares adept to anything else, and no worked example.

Two of its claims have gone stale — it says "27 skills" and "3 references" where
`ls skills | wc -l` reports 28 and `ls references | wc -l` reports 4.

Of its ten Markdown links, nine are repository-relative: five ADRs, two images under
`docs/assets/`, `docs/cheatsheet.md`, and `LICENSE`.

GitHub Pages is off: `gh api repos/randomparity/adept/pages` returns 404. There is one
workflow, `.github/workflows/verify.yml`. There is no `CHANGELOG`, no git tag, and no GitHub
release — [ADR 0006](../../adr/0006-release-management-out-of-scope.md) and
[ADR 0001](../../adr/0001-distribution-via-plugin-marketplace.md) hold that ground, and this
change does not reopen it.

## Scope

Frozen in the `WORK:SCOPE` annotation on issue #234, token `q234-2dda3086`. The two design
questions the issue left open were settled by the operator before design started:

- **The site is two pages** — the README-derived landing page and `docs/cheatsheet.md`.
- **No changelog link.** The issue asked for one; the repository has nothing to link.

## Reference implementation

`randomparity/bzr` publishes a Pages site of exactly this shape, and this design follows it
rather than inventing one. Its `.github/workflows/site.yml` installs `pandoc`, copies assets
and a stylesheet into `_site`, renders `README.md` and `CHANGELOG.md` through
`site/template.html`, asserts the outputs with `test -s`, then uploads and deploys. Its
supporting files are `site/template.html` (1,041 bytes) and `site/style.css` (2,392 bytes).
There is no script and no site generator.

One difference decides what adept has to add. Of the 48 Markdown links in bzr's `README.md`, 32
are absolute and 16 are same-page anchors — none repository-relative — so its build needs no
link handling at all. Nine of adept's ten are relative, so adept adds one rewrite step — and
keeps them relative, because `README.md` ships inside every plugin cache, where a relative link
resolves to the file next to it. bzr's two relative asset paths are `src="docs/assets/…"`
attributes, handled by copying `docs/assets` — the mechanism adept uses for its images too.

## Decision

### Files

| Path | Answerable for | State |
|---|---|---|
| `README.md` | The landing page's prose. The single source; nothing copies it. | modified |
| `site/template.html` | Page chrome: head, header, navigation, footer. | new |
| `site/style.css` | The site's appearance. Owned here, themed by nobody. | new |
| `.github/workflows/pages.yml` | Building, asserting, and deploying the site. | new |
| `.claude-plugin/plugin.json` | Version bump. | modified |

No `scripts/` entry, no suite, no `just` recipe. ADR 0034 decision 3 puts the build itself on
every pull request, which is the coverage a script was going to buy.

### `.github/workflows/pages.yml`

```yaml
name: Pages

on:
  push:
    branches: [main]
    paths: &site-paths
      - 'README.md'
      - 'docs/cheatsheet.md'
      - 'docs/assets/**'
      - 'site/**'
      - '.github/workflows/pages.yml'
  pull_request:
    branches: [main]
    paths: *site-paths
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: >-
    ${{ github.event_name == 'pull_request'
        && format('pages-pr-{0}', github.event.pull_request.number)
        || 'pages' }}
  cancel-in-progress: false
```

YAML anchors are written out in full in the real file rather than aliased; `actionlint` reads
the workflow, and a duplicated five-line path list is cheaper to read than an anchor.

Two jobs:

- **`build`** — inherits `permissions: contents: read`. Checkout with
  `persist-credentials: false`, install `pandoc`, run the build step below, then
  `actions/upload-pages-artifact` with `path: _site`.
- **`deploy`** — `needs: build`, `if: github.event_name != 'pull_request'`,
  `permissions: {pages: write, id-token: write}`, `environment: {name: github-pages, url: <the
  deployment step's page_url>}`. It runs `actions/deploy-pages` and nothing else: no checkout,
  none of this repository's own code.

Every `uses:` is pinned to a full commit SHA with a version comment, the convention
`verify.yml` already follows and `zizmor` audits under `just actions-check`. The elevated grant
sits only on `deploy`, and no `pull_request` event ever reaches it.

### The build step

```sh
mkdir -p _site/docs
cp -r docs/assets _site/docs/assets
cp site/style.css _site/style.css

for page in "README.md:index.html:adept" \
            "docs/cheatsheet.md:cheatsheet.html:adept — skill cheat sheet"; do
  ...
done
```

Written out per page rather than looped, in fact — two pandoc invocations are shorter and
clearer than the loop that would generalise them. Each is:

```sh
absolutise <source> <source-directory-prefix> \
  | pandoc -f gfm -t html5 --template site/template.html \
      --metadata title="<title>" --output _site/<page>.html
```

called as `absolutise README.md ''` and `absolutise docs/cheatsheet.md 'docs/'`.

**The two substitutions**, in one `perl -pe` expression, in this order:

1. `](docs/cheatsheet.md)` → `](cheatsheet.html)` — the site's other page.
2. `](<target>)` → `](https://github.com/randomparity/adept/blob/main/<prefix><target>)` for
   every target that does not begin with `http://`, `https://`, `#`, `mailto:`,
   `docs/assets/`, or `cheatsheet.html`.

`perl` rather than `sed` because rule 2 needs a negative lookahead, which GNU `sed`'s ERE has
no way to express; `perl` is present on every GitHub-hosted runner image.

`<prefix>` is the source file's own directory, and it is what makes rule 2 correct for a file
that is not at the repository root. A relative link is relative to the file that wrote it, so
`](adr/0001.md)` in `docs/cheatsheet.md` means `docs/adr/0001.md`. Without the prefix it would
absolutise to `blob/main/adr/0001.md` — a URL that is absolute, wrong, and invisible to the
post-build check below, which only sees links that stayed relative. The cheat sheet carries no
links today, so this is a trap being closed rather than a bug being fixed; the exclusion list
in rule 2 is still written from the repository root, which is `README.md`'s perspective, so a
`](assets/x.png)` added to the cheat sheet would be absolutised rather than left alone.

`docs/assets/` is excluded because those files are copied to `_site/docs/` — the same relative
path `README.md` already writes — so image references resolve unchanged on GitHub and on the
site alike, and absolutising one would turn an `<img src>` into a blob page that serves HTML.

**Assertions**, after both renders — the step's whole verification, and the reason it does not
need a suite:

```sh
test -s _site/index.html
test -s _site/cheatsheet.html
test -s _site/style.css
test -s _site/docs/assets/adept-logo-grimoire.png
test -s _site/docs/assets/adept-quest-map.png

if grep -ohE '(href|src)="[^"]*"' _site/*.html |
   grep -vE '"(https?://|#|mailto:|index\.html|cheatsheet\.html|style\.css|docs/assets/)'; then
  echo "::error::unresolved relative link in the built site" >&2
  exit 1
fi
```

The `grep -v` is the one that bites: it lists every link the rewrite failed to resolve and
fails the job, on a pull request, before the page could ship a 404. `grep -o` is given `-h` so
the filename prefix does not defeat the leading `"` in the second pattern. Under `bash -e` the
pipeline sits inside an `if` condition, where `-e` does not apply, so a clean run — where the
second `grep` exits 1 for no matches — passes rather than failing the step.

### `site/template.html`

A pandoc HTML5 template with `$title$` and `$body$` placeholders, carrying:

- `<head>`: charset, viewport, `$title$`, a description meta, the favicon at
  `docs/assets/adept-logo-grimoire.png`, and `style.css`.
- A header with the adept mark linking to `index.html` and a nav: **Home** (`index.html`),
  **Cheat sheet** (`cheatsheet.html`), **GitHub**
  (`https://github.com/randomparity/adept`).
- `<main>$body$</main>`.
- A footer linking the repository and the MIT licence.

The nav is what makes the second page reachable, so no page depends on another page's prose to
be navigable. Every path in the template is relative, which is why the site needs no base-path
configuration: the pages sit at `/adept/index.html` and `/adept/cheatsheet.html`, and
`style.css` and `docs/assets/…` resolve beside them.

`README.md`'s leading `# adept` stays in the body. The template's header carries a small brand
mark, not a page title, so nothing is duplicated and nothing has to be stripped.

### `site/style.css`

One stylesheet, hand-written, in the neighbourhood of bzr's 2.4 KB. Readable measure, a header
band, code blocks, tables, and a `prefers-color-scheme: dark` block. It has no build step and
no dependencies.

### Enabling Pages

One time, by an operator with admin, **before this pull request merges**:

```sh
gh api -X POST repos/randomparity/adept/pages -f build_type=workflow
```

Order matters. Enabled first, the first run on `main` is green. Enabled afterwards, that run
fails and leaves a red default branch needing a manual `workflow_dispatch`. Enabling early is
harmless: with no workflow yet, nothing deploys and the site 404s until the first run.

### `README.md` restructure

Same file, rewritten for a reader who has not seen adept before, in this order:

1. **What it is** — one paragraph and the logo.
2. **Install** — Claude Code and Codex CLI, as today.
3. **Quick start** — a worked first run: install, `/sort-board` to create the label set the
   pipeline needs, `/quest <issue>`, and what the operator sees at each stop. The issue asks
   for a "meaningful quick start / new user demo"; a command list without the stops is not one,
   because the stops are what the pipeline is.
4. **What makes adept different** — three claims, each stated against what it is different
   *from*: work state lives on GitHub rather than in a session, design is reviewed
   adversarially before code exists, and the vocabulary names the phase rather than the tool.
5. **What ships** — the feature list: every skill, grouped by the phase it belongs to, one line
   each. The cheat sheet is linked from here.
6. **Working on this repository** — as today.
7. **Licence** — as today.

The stale counts go by removal rather than correction: a grouped list naming each skill is the
feature list the issue asks for *and* it drops the number that was wrong. ADR 0006's
Consequences require README's workflow section to keep its pointer to that record; the
restructure keeps it.

Both images stay embedded. They total 4,535,676 bytes at `bdcc640`; ADR 0034 accepts that and
#237 tracks reducing them.

No prose gate is added — anatomy rule 4 forbids one. A list naming every skill can still fall
behind the directory; a structural check that each `skills/<name>/` is named in it would catch
that, and is filed as #238 rather than built here.

## Threat model

The change adds a workflow holding `pages: write` and `id-token: write`, adds three pinned
action references and an apt package, and publishes a public website. That is security-relevant
on three of `$quest` step 6's triggers, so the controls below are acceptance criteria.

### Boundary inventory

**Added:** a workflow that can write to the repository's Pages deployment and mint an OIDC
token; a public HTTPS site built from `main`; three third-party actions and one apt package
executing in CI with the job's permissions.

**Widened:** none. `contents: read` and `persist-credentials: false` match `verify.yml`.

### Actor model

| Actor | Reaches | Trusted with |
|---|---|---|
| Anonymous internet | The published static site | Nothing. The site takes no input — no form, no query handling, no server-side code. |
| Contributor without merge rights | A pull request, and the `build` job it triggers | Running the build under `contents: read`, with no path to the deploy job. |
| Contributor with merge rights on `main` | What publishes | Everything. Merging now also publishes; that trust is placed deliberately. |
| The pinned actions and `pandoc` | The job's token and the workspace | Their pinned revision, and no more. |

The `pull_request` trigger is the one place this design gives an untrusted actor more than the
previous one did, so it is stated plainly: a fork PR can cause the `build` job to run. That job
holds `contents: read`, checks out the PR's own code, writes only into `_site`, and uploads an
artifact the deploy job never consumes on a `pull_request` event. It is the same exposure
`verify.yml` already accepts for the guardrail suite.

### Control per boundary

| Boundary | Control | Fails how |
|---|---|---|
| Deployment trigger | `deploy` carries `if: github.event_name != 'pull_request'` | A fork PR cannot deploy |
| Token scope | Workflow-level `contents: read`; `pages: write` and `id-token: write` on `deploy` alone, which runs no repository code | A compromised build step holds only read |
| Checkout credentials | `persist-credentials: false` | No checkout token left in `.git/config` |
| Third-party code | Every `uses:` pinned to a full commit SHA, audited by `zizmor` | A moved tag does not change what runs |
| Build inputs | The step reads the five paths it names and writes only under `_site`; `pandoc` renders, it does not execute | A file added elsewhere cannot enter the build |
| Published content | The page set is two named files | Nothing publishes that a reviewer did not add to the workflow |
| Link resolution | The post-build `grep` fails the job on any unresolved relative link | A broken link fails a PR rather than shipping |
| Concurrent deploys | `concurrency` group `pages`, `cancel-in-progress: false`, with PR builds on their own group | Two merges cannot interleave one deployment |

Every published byte is already public: this is a public repository and the sources are tracked
files from it. The site discloses nothing a clone does not.

### Explicitly out of scope

- **Custom domain, DNS, CNAME verification.** Not requested; the default `github.io` host is
  used, and a domain takeover risk needs a domain first.
- **Response headers and Content Security Policy.** GitHub Pages sets these and gives a project
  no way to configure them.
- **Availability of the published site.** GitHub's.
- **`pandoc`'s provenance.** It comes from the runner image's apt repository, unpinned, as it
  does in `randomparity/bzr`. Accepted: it renders Markdown to HTML in a job holding no
  secrets, and pinning an apt package version on a rolling runner image breaks on image
  updates more often than it protects.
- **Secret handling.** The change introduces none. If a later change needs one, this section is
  where the omission stops being true.

## Testing

There is no unit suite, and that is the design rather than an omission: the build is a workflow
step, it runs on every pull request touching the site's inputs, and it asserts its own outputs.
What that gives up is running the build on a workstation: iterating on it costs a push.
What proves this change is:

| # | Proof | Where |
|---|---|---|
| 1 | The five `test -s` assertions pass | `build` job, every PR touching the site's inputs |
| 2 | No unresolved relative link survives the rewrite | `build` job's `grep`, every PR touching the site's inputs |
| 3 | `actionlint` and `zizmor` accept `pages.yml` | `just actions-check`, local and CI |
| 4 | `just verify` stays green | local and CI |
| 5 | Both pages render, styled, with working navigation and images | loading the deployed site after the first `main` run |

Row 5 is the one no local gate reaches, and it is the reason the hand-off says to open the URL
rather than trusting a green workflow. A green build proves the files exist and their links
resolve; it does not prove the page looks right.

## Acceptance criteria

1. `https://randomparity.github.io/adept/` serves the restructured `README.md`, styled, with
   its images and working navigation to the cheat sheet.
2. `https://randomparity.github.io/adept/cheatsheet.html` serves `docs/cheatsheet.md`.
3. Every other link on both pages resolves — in-repository ones to `blob/main` URLs, external
   ones unchanged.
4. `README.md` carries the feature list, the differentiators, and the quick start the issue
   asks for, and states no count that `ls skills` can contradict.
5. `just verify` is green, `just actions-check` included.
6. No content is duplicated: `README.md` and `docs/cheatsheet.md` remain the only copies of
   their prose.
7. The Pages workflow deploys only on non-`pull_request` events, and `pages: write` appears
   only on the `deploy` job.
8. `.claude-plugin/plugin.json` declares a version greater than `2.9.5`.
