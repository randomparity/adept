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

GitHub Pages was off when this was designed: `gh api repos/randomparity/adept/pages`
returned 404 on 2026-08-25, before the enabling step below was performed. There is one
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
  pull_request:
    branches: [main]
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

**No `paths:` filter, deliberately.** The build's link-existence check is what stops a moved or
deleted file from publishing a 404, and the change that moves such a file is exactly the change
a site-scoped path filter would skip — the guard would be off for the only edits that can trip
it, and the 404 would surface later on an unrelated pull request. Running always costs one apt
install and two `pandoc` invocations.

Two jobs:

- **`build`** — inherits `permissions: contents: read`. Checkout with
  `persist-credentials: false`, install `pandoc`, run the build step below, then
  `actions/upload-pages-artifact` with `path: _site`.
- **`deploy`** — `needs: build`,
  `if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'`,
  `permissions: {pages: write, id-token: write}`, `environment: {name: github-pages, url: <the
  deployment step's page_url>}`. It runs `actions/deploy-pages` and nothing else: no checkout,
  none of this repository's own code.

Every `uses:` is pinned to a full commit SHA with a version comment, the convention
`verify.yml` already follows and `zizmor` audits under `just actions-check`. The elevated grant
sits only on `deploy`, and no `pull_request` event ever reaches it.

### The build step

```sh
set -o pipefail

mkdir -p _site/docs/assets
find docs/assets -maxdepth 1 -type f \
  \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.webp' \) \
  -exec cp {} _site/docs/assets/ \;
cp site/style.css _site/style.css
```

`set -o pipefail` first, because every render below is a pipeline and `pandoc` succeeds on
empty input — without it the rewrite stage's failure is masked by the renderer's success.

Image types only, rather than `cp -r docs/assets`. That directory is served from the site
origin, so copying it wholesale would publish whatever lands in it later; an `.html` or an
`.svg` dropped in is active content on a host shared with every other project page under this
account, and it would need no workflow edit to get there. `-maxdepth 1` keeps the copy flat:
without it a file in a subdirectory would be flattened into `_site/docs/assets/` and a page
linking it at its real path would 404, where now it is simply not copied and the link
assertion says so.

Then one render per page, written out rather than looped — two invocations are shorter than the
loop that would generalise them:

```sh
absolutise <source> <source-directory-prefix> \
  | pandoc -f gfm -t html5 --template site/template.html \
      --metadata title="<title>" --output _site/<page>.html
```

called as `absolutise README.md ''` and `absolutise docs/cheatsheet.md 'docs/'`.

**`absolutise` makes one decision per link**, in this order:

0. Fenced code blocks are tracked exactly and skipped, because a `](…)` in an example is sample
   text and rewriting it would publish a corrupted example. Alongside that, any line indented
   four spaces or a tab is left alone — a cruder test than its name suggests, since it also
   covers nested list items, so a repository-relative link must not be written at that indent.
1. A target beginning `http://`, `https://`, `#`, or `mailto:` is left alone. A Markdown link
   title — `](path "Title")` — is valid GFM, and is preserved rather than parsed as part of the
   path. So is a trailing `#fragment`: it is split off before anything else, and re-attached to
   whatever the path maps to.
2. Otherwise the target is **resolved against the source's own directory** — `$PREFIX$path` —
   and then **normalised**: `./` dropped, `X/../` collapsed. Every remaining test applies to
   that normalised path. Normalising matters as much as prefixing: `../README.md` is the only
   correct repository-relative way for `docs/cheatsheet.md` to name the README, and
   `docs/../README.md` matches neither page mapping nor the assets rule, so it would fall
   through to a `blob/main` URL that GitHub serves with a 200 — a link that leaves the site, or
   an `<img src>` pointing at a page of HTML. `-e` does not catch it, because the dotted path
   exists on disk.
3. **The resolved path must exist**, or the rewrite dies and the build goes red naming it.
   Without this a link to a moved or deleted file becomes a perfectly well-formed `blob/main`
   URL that 404s on the published page, and no later assertion can tell it from a good one.
4. Resolved to `docs/cheatsheet.md` → `cheatsheet.html`; resolved to `README.md` →
   `index.html`, with any fragment re-attached. The two page mappings are symmetric so either
   page can link the other — verified for `](../README.md)` from the cheat sheet, which is the
   spelling that makes symmetry real rather than nominal.
5. Resolved under `docs/assets/` → left relative, because those files are copied to exactly
   that path and resolve unchanged on GitHub and on the site alike. Absolutising one would turn
   an `<img src>` into a blob page that serves HTML.
6. Anything else → `https://github.com/randomparity/adept/blob/main/<resolved>`.

Step 2 is the order that matters, and it is why the tests come after the prefix rather than
before it. A relative link is relative to the file that wrote it: `](adr/0001.md)` in
`docs/cheatsheet.md` means `docs/adr/0001.md`, and `](assets/x.png)` there means
`docs/assets/x.png`. Testing the raw target instead would absolutise both against the
repository root — producing URLs that are absolute, wrong, and invisible to the link assertion
below, which sees only links that stayed relative. The cheat sheet carries no Markdown links
today, so this closes a trap rather than fixing a live bug.

`perl` rather than `sed`: this needs a lookahead and a conditional replacement, neither of which
GNU `sed`'s ERE can express. `perl` is on every GitHub-hosted runner image.

The source is fed as `perl -pe '…' <"$1"`, not as a filename argument. Measured on this host:
`perl -pe 's/a/b/' missing-file` warns on stderr and **exits 0**, so a renamed or deleted source
would produce empty stdout, `pandoc` would substitute an empty `$body$`, and a page of pure
template chrome would be written that `test -s` still passes. The redirect fails instead, and
`pipefail` carries that failure past `pandoc`.

**Assertions.** One before rendering, three after — the step's whole verification, and the
reason it does not need a suite:

```sh
# before any render
if grep -nE '<[a-zA-Z/!]' README.md docs/cheatsheet.md; then
  echo "::error::raw HTML in a site source" >&2
  exit 1
fi

# after both renders
die() { echo "::error::$1" >&2; exit 1; }

test -s _site/index.html || die 'index.html is empty or missing'
test -s _site/cheatsheet.html || die 'cheatsheet.html is empty or missing'
test -s _site/style.css || die 'style.css was not copied'
test -s _site/docs/assets/adept-logo-grimoire.png || die 'the logo was not copied'
test -s _site/docs/assets/adept-quest-map.png || die 'the quest map was not copied'

test "$(wc -c <_site/index.html)" -gt 3000 ||
  die 'index.html is smaller than the template chrome; its body is missing'
test "$(wc -c <_site/cheatsheet.html)" -gt 3000 ||
  die 'cheatsheet.html is smaller than the template chrome; its body is missing'

missing=0
while IFS= read -r attr; do
  target=${attr#*\"}; target=${target%\"}
  case $target in "" | http://* | https://* | \#* | mailto:*) continue ;; esac
  target=${target%%#*}
  if [ ! -e "_site/$target" ]; then
    echo "::error::built page links $target, which is not in _site" >&2
    missing=1
  fi
done <<<"$(grep -ohE '(href|src)="[^"]*"' _site/index.html _site/cheatsheet.html)"
[ "$missing" -eq 0 ]
```

The **raw-HTML gate** is the control on active content, and it is an allowlist of zero rather
than a denylist of tags. It has to be, for two reasons. `pandoc -f gfm` passes raw HTML from
the source straight into the output, and `-f gfm-raw_html` does **not** suppress it — measured
on pandoc 3.10.2, the commonmark-family reader emits `<script>alert(1)</script>` verbatim with
the extension on or off, so writing that flag would put a control in the workflow that controls
nothing. And an output-side denylist of element names is walked through by the next name nobody
listed: `<base>`, `<meta http-equiv="refresh">`, an `onmouseenter`, an SVG `onbegin`. Requiring
that the sources carry no tag at all is one rule that covers every one of them, and it is
satisfiable today — `grep -nE '<[a-zA-Z/!]' README.md docs/cheatsheet.md` matches nothing. The
caveat is deliberate and belongs in the comment: it also trips on a literal `<` followed by a
letter inside a fenced code block, on a GFM autolink such as `<https://example.com>`, and on an
HTML comment. The answer then is to rewrite the line, or to exclude that shape on purpose, not
to return to a denylist of tag names.

The **size floor** is there because `test -s` cannot tell a rendered page from one whose body is
gone: the template alone is about 1 kB. 3000 sits above the chrome and below either real page,
which measure 12,033 and 9,589 bytes against the current sources.

The **link assertion** tests that each relative target exists in `_site`, rather than matching
an allowlist of permitted path shapes. That difference is the whole value: an earlier version
permitted anything under `docs/assets/`, which passed a link to an `.svg` the copy step does not
copy and a link to a file in a subdirectory it does not descend into. Both now fail, verified by
running the extracted build block against fixtures.

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

One time, by an operator with admin, **before this pull request merges**. **Performed
2026-08-25**: `gh api repos/randomparity/adept/pages` now returns `build_type: workflow`,
`status: null`, `html_url: https://randomparity.github.io/adept/`. The command was:

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
| Anonymous internet | The published static site | Nothing. The site takes no input — no form, no query handling, and no server-side code. That is not the same as no client-side code: raw HTML in a source would reach the page, which is what the active-content assertion exists to stop. |
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
| Deployment trigger (fork PR) | `deploy` carries `if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'` | A fork PR cannot deploy |
| Deployment trigger (same-repository branch) | The same `if:`, backed by the `github-pages` environment's deployment-branch policy — the `if:` alone is a line the pull request's own author can edit, so the environment is what holds while the workflow is itself under review | A branch build cannot deploy even if the workflow is edited to try |
| Manual deploy (`workflow_dispatch`) | The same `github.ref` test, plus the `github-pages` environment's deployment-branch policy naming `main` (verified 2026-08-25) | A dispatch from another ref is blocked, in the diff and again at the environment |
| Token scope | Workflow-level `contents: read`; `pages: write` and `id-token: write` on `deploy` alone, which runs no repository code | A compromised build step holds only read |
| Checkout credentials | `persist-credentials: false` | No checkout token left in `.git/config` |
| Third-party code | Every `uses:` pinned to a full commit SHA. `zizmor` runs `--offline`, so it checks the pin's shape and not its provenance; the three new pins were resolved against their repositories by hand at review time (#239) | A moved tag does not change what runs; an impostor SHA is caught by review, not by the gate |
| Build inputs | The step reads the five paths it names and writes only under `_site`; `pandoc` renders, it does not execute | A file added elsewhere cannot enter the build |
| Published content | Two rendered HTML files, `style.css`, and the image-typed files directly under `docs/assets/` | A non-image, or anything in a subdirectory, is not copied — and a page linking it fails the link assertion rather than shipping a 404 |
| Link resolution (relative) | Every relative `href`/`src` in the built pages must name a file present in `_site` | A broken link, an unstaged asset, or an unrendered page fails a PR rather than shipping |
| Link resolution (absolutised) | The rewrite refuses a repository-relative target that does not exist, before turning it into a `blob/main` URL | A link to a moved or deleted file fails a PR rather than publishing a 404 |
| Active content | Neither source may contain a raw HTML tag at all, checked before rendering | Raw HTML added to a source fails a PR rather than executing on an origin shared with every other project page under this account |
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
| 1 | The five `test -s` assertions and the two size floors pass | `build` job, every PR to `main` |
| 2 | No unresolved relative link survives the rewrite | `build` job's link `grep`, every PR to `main` |
| 2a | Neither source carries a raw HTML tag | `build` job's pre-render gate, same trigger |
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
