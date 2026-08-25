# 0034 — The site publishes a staged copy, not the repository

## Status

Accepted (2026-08-25)

## Context

Issue #234 asks for a GitHub-hosted website built from `README.md`, carrying a feature list,
what distinguishes adept from other workflow tools, and a quick start. The operator scoped it
to two pages: the README-derived landing page and `docs/cheatsheet.md`.

GitHub Pages offers two source modes. *Deploy from a branch* points Pages at a branch and a
root — `/` or `/docs` — and GitHub runs Jekyll over everything it finds there. *Deploy from
GitHub Actions* publishes whatever artifact a workflow uploads.

The branch modes are unusable here, and the reason is this repository's shape: it is a plugin,
and both harnesses copy the **whole** tree into their plugin cache. At `bdcc640`,
`git ls-files '*.md' | wc -l` reports 141 tracked Markdown files. Every one of them would
render as a page, because `jekyll-optional-front-matter` sits in the `github-pages` gem's
`DEFAULT_PLUGINS` and exists precisely to render Markdown that carries no front matter.

`README.md` also has to stay the single source for the landing page. CLAUDE.md's
instruction-file rule — two documents stating the same thing is the drift problem this project
spent real effort removing — binds a second copy of the landing prose exactly as it binds a
second `AGENTS.md`.

`randomparity/bzr` already publishes a Pages site of this shape, and it is the reference this
record follows.

## Decision

**Pages source is GitHub Actions, and one workflow renders two named files into a site
directory.** Nothing reaches the site because it happens to be in the repository.

1. `.github/workflows/pages.yml` builds `_site` inline: copy `site/style.css` and the image
   files under `docs/assets/` — image types only, since that directory is served from the site
   origin and copying it wholesale would publish whatever lands in it later — run `pandoc`
   twice against `README.md` and `docs/cheatsheet.md` through `site/template.html`, assert the
   outputs, upload, deploy.
2. **Rendering is `pandoc` with a template and stylesheet this repository owns**, not Jekyll
   with a GitHub theme. The template supplies the site's navigation, so neither page depends
   on the other's prose to be reachable.
3. **The build job runs on every `pull_request` to `main` and every `push` to it**, with no
   `paths` filter, and only the deploy job is gated with
   `if: github.event_name != 'pull_request'`. The filter was deliberately removed: decision 4's
   link-existence check is what stops a moved or deleted file from publishing a 404, and the
   change that moves such a file is exactly the change a site-scoped filter would skip — the
   guard would be off for the only edits that can trip it. The cost of always running is one
   apt install and two `pandoc` invocations.
4. **Repository-relative links are absolutised at build time**, in one `perl` expression, and
   the rewrite refuses a target that does not exist. A relative link is relative to the file
   that wrote it, so every target is **first** resolved against its source's own directory, and
   every subsequent test applies to the resolved path: one resolving to `docs/cheatsheet.md`
   becomes `cheatsheet.html`, one resolving to `README.md` becomes `index.html`, one under
   `docs/assets/` stays relative because those files are copied to exactly that path, and
   anything else becomes a `blob/main` URL — but only after the file is confirmed to exist.
   Resolving first is what the order buys: testing the raw target would leave `](assets/x.png)`
   in the cheat sheet absolutised into a blob URL, absolute and wrong. The existence check is
   what makes a `blob/main` URL trustworthy at all: a link to a moved or deleted file
   absolutises into a perfectly well-formed URL that 404s, and no later assertion can tell it
   from a good one. Code blocks are skipped — fenced and indented alike — because a `](…)`
   inside an example is sample text, and rewriting it would publish a corrupted example.
5. **Three assertions, each an allowlist rather than a denylist.**
   - *Before rendering*: neither source may contain a raw HTML tag at all. `pandoc`'s `gfm`
     reader passes raw HTML straight into the output — measured on 3.10.2, `-f gfm-raw_html`
     does not suppress it — and these pages are served from `randomparity.github.io`, an origin
     shared with every other project page under this account, so a script here is not scoped to
     this site. Naming forbidden tags would be a denylist that the next unnamed tag walks
     through; requiring none is one rule that holds for all of them.
   - *After rendering*: each page must exceed a size floor a page of bare template chrome
     cannot clear, because `test -s` cannot tell a rendered page from one whose body is gone.
   Each scan captures its own exit status rather than branching on it directly: `grep` exits 1
   for "no matches" and greater than 1 for a scan that could not run, and `if grep …` reads both
   as clean — [ADR 0005](0005-scan-faults-are-reported-not-collapsed.md) decision 1. Every
   assertion names what failed, rather than exiting 1 silently.
   - *After rendering*: every relative `href` and `src` in the built pages must name a file
     that is actually in `_site`. Testing existence rather than matching permitted path shapes
     is what makes this cover the class — an asset whose type the copy step skipped, one in a
     subdirectory it did not descend into, and a link the rewrite resolved to a path that was
     never staged all fail here, where a pattern permitting `docs/assets/` passed them.
6. **Pages is enabled once, out of band, by an operator with admin, before the pull request
   merges**, so the first run on `main` is green. The workflow does not enable it:
   `actions/configure-pages`' `enablement` input requires a token other than `GITHUB_TOKEN`,
   and this repository holds no secrets. Nothing checks the ordering, and a pull request is
   green either way, because the deploy job does not run on one. If it is missed, the first
   push to `main` deploys nothing and leaves a red run; enabling Pages and re-running the
   workflow is the whole fix. Enabling Pages also creates the `github-pages` environment with
   a deployment-branch policy naming `main`, which is load-bearing and not to be widened —
   the deploy job's `github.ref` test states the same restriction inside the diff so that
   review can see it and a settings edit cannot silently remove it.

## Consequences

- The whole site build is one workflow file plus `site/template.html` and `site/style.css`.
  There is no site generator, no `Gemfile`, no `_config.yml`, no base-path configuration, and
  no staging script to test — decision 3 puts the build itself under review on the pull
  requests that touch it. The cost accepted with the script is that the build runs only in
  CI, so iterating on it costs a push.
- This repository owns the stylesheet. Nothing about the site's appearance changes upstream,
  and nothing themes it for us either: the CSS is ours to maintain.
- `README.md` keeps its relative links, which is what a reader inside the plugin cache needs —
  `docs/adr/0001-…md` is a local file there, not a URL. Decision 4 is the one line that buys
  that.
- Adding a page is an edit to the workflow's build step. That is the intended cost: the page
  set is reviewable in a diff, and a new skill, ADR, or top-level directory publishes nothing.
- Three pinned third-party action references (`actions/checkout`,
  `actions/upload-pages-artifact`, `actions/deploy-pages`). This repository has no
  `.github/dependabot.yml`, so nothing automated tracks those pins — tracked as #236, and off
  this change's surface.
- `pandoc` is installed unpinned from the runner's apt repository, which #236 would not cover
  either way. Decision 5's assertions bound what a renderer change can do silently — a page
  cannot come back empty, shrink to chrome, carry an unresolved link, or gain active content —
  but nothing pins the rendering itself, so a change in how `pandoc` formats a table or a code
  block reaches the published page unremarked. Accepted rather than answered with a golden-file
  test, on the same reasoning that declines a smoke test: two static pages do not earn one.
- `zizmor` runs `--offline` in `just actions-check`, which confirms a pin's *shape* — a full
  40-character SHA rather than a mutable tag — and not its provenance, because the audits that
  check whether a SHA is reachable in the repository the `uses:` names need the API. All three
  new pins were resolved against their repositories by hand at review time; the next bump gets
  the offline subset unless that changes. Tracked as #239 rather than altering the gate here.
- Reachability is observed rather than asserted: `actions/deploy-pages` outputs the deployed
  `page_url`, and a failed deploy is a red run on `main` for whoever merged to read. No
  smoke-test workflow is added — two static pages do not earn one.
- The landing page embeds both README images verbatim, 4,535,676 bytes together at `bdcc640`,
  so it weighs about 4.5 MB before a byte of CSS. The build adds no image handling either way;
  reducing them is a change to the assets themselves, tracked as #237.

## Considered & rejected

- **Deploy from a branch with the repository root as the source, excluding the rest in
  `_config.yml`.** The cheapest to set up — no workflow at all. Rejected — verified: at
  `bdcc640`, `git ls-files '*.md' | wc -l` reports 141 tracked Markdown files, and
  `jekyll-optional-front-matter` in the `github-pages` gem's `DEFAULT_PLUGINS`
  (`github/pages-gem`, `lib/github-pages/plugins.rb`) renders every one of them; an exclusion
  list publishes them all by default and leaks silently the first time a directory is added.
- **Deploy from a branch with `/docs` as the source.** Narrower, and needs no workflow.
  Rejected — verified: `README.md` is not under `docs/`, so that source cannot serve the
  landing page at all, which is the issue's first completion criterion. The 104 Markdown files
  it would serve instead are the ADRs, specs, plans and benchmarks the operator's scope
  decision excluded, plus `docs/cheatsheet.md`.
- **Render with Jekyll via `actions/jekyll-build-pages` and a GitHub Pages theme.** The
  obvious choice, and the one this record first made. Rejected — verified: the theme's version
  is resolved inside `ghcr.io/actions/jekyll-build-pages:v1.0.13`, a mutable Docker tag named
  in that action's own `action.yml`, which no SHA pin reaches; and the renderer supplies no
  base path of its own — `jekyll-build-pages`' `entrypoint.sh` at v1.0.13 runs
  `github-pages build` with no base-URL argument and `GitHubPages::Configuration` sets neither
  `url` nor `baseurl` — so a project page's base path has to be supplied by the workflow,
  by hand or from `actions/configure-pages`' `base_path` output, and a wrong one builds green
  and renders unstyled. `pandoc` with an owned template and relative paths has neither
  property.
- **Stage the site with a `scripts/build-site.sh` and a fixture suite rather than inline
  workflow steps.** The variant this repository's anatomy rules demand be weighed, since a
  supporting file has to be argued for. Rejected — verified: `randomparity/bzr`'s
  `.github/workflows/site.yml` builds its site on `pull_request` and gates only the deploy
  step, so inline steps are reviewable before they can reach `main`; the coverage a script was
  going to buy is available without one, and decision 5's post-build assertions cover the parts
  with a failure mode. What the script would genuinely have bought, and what is given up with
  it, is running the build on a workstation: iterating on it costs a push.
- **Write `README.md`'s in-repository links as absolute `blob/main` URLs, as
  `randomparity/bzr` does, and drop the rewrite entirely.** The simplest option of all, and
  close to why bzr's build needs no link handling — verified: of the 48 Markdown links in its
  `README.md`, 32 are absolute and 16 are same-page anchors, none repository-relative, and its
  two relative asset paths are `src="docs/assets/…"` attributes handled by copying
  `docs/assets`, which is the mechanism decision 4 uses too. Rejected — judgment: adept's
  `README.md` ships inside every plugin cache, where a relative link resolves to the file
  sitting next to it and an absolute one sends the reader to the network for a file they
  already have.
- **Copy the landing prose into a site page and leave `README.md` alone.** Removes the rewrite
  and the pandoc step. Rejected — judgment: two documents stating the same thing is the drift
  this project already paid to remove once, and the issue asks for the README itself to be the
  basis for the site.
- **Do nothing — GitHub already renders `README.md` and `docs/cheatsheet.md`.** The null
  option, and it is not nothing: both are readable today at their blob URLs. Rejected —
  judgment: a blob URL is a file listing with prose in it, and the issue asks for a landing
  page a newcomer can be sent to.
