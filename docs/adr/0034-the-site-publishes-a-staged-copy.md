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

1. `.github/workflows/pages.yml` builds `_site` inline: copy `docs/assets/` and
   `site/style.css`, run `pandoc` twice against `README.md` and `docs/cheatsheet.md` through
   `site/template.html`, assert the outputs, upload, deploy.
2. **Rendering is `pandoc` with a template and stylesheet this repository owns**, not Jekyll
   with a GitHub theme. The template supplies the site's navigation, so neither page depends
   on the other's prose to be reachable.
3. **The build job runs on `pull_request` as well as `push`**, and only the deploy job is
   gated with `if: github.event_name != 'pull_request'`. The site build is therefore
   exercised on every branch before it can reach `main`.
4. **Repository-relative links are absolutised at build time**, in one `perl` expression:
   `docs/cheatsheet.md` becomes `cheatsheet.html`, and every remaining relative target becomes
   a `blob/main` URL — excluding `docs/assets/`, which is copied to the path `README.md`
   already names and therefore resolves unchanged on both GitHub and the site. A post-build
   check fails the job on any relative `href` or `src` the rewrite did not resolve.
5. **Pages is enabled once, out of band, by an operator with admin, before the pull request
   merges**, so the first run on `main` is green. The workflow does not enable it:
   `actions/configure-pages`' `enablement` input requires a token other than `GITHUB_TOKEN`,
   and this repository holds no secrets.

## Consequences

- The whole site build is one workflow file plus `site/template.html` and `site/style.css`.
  There is no site generator, no `Gemfile`, no `_config.yml`, no base-path configuration, and
  no staging script to test — decision 3 puts the build itself under review on every PR.
- This repository owns the stylesheet. Nothing about the site's appearance changes upstream,
  and nothing themes it for us either: the CSS is ours to maintain.
- `README.md` keeps its relative links, which is what a reader inside the plugin cache needs —
  `docs/adr/0001-…md` is a local file there, not a URL. Decision 4 is the one line that buys
  that.
- Adding a page is an edit to the workflow's build step. That is the intended cost: the page
  set is reviewable in a diff, and a new skill, ADR, or top-level directory publishes nothing.
- Three pinned third-party action references (`actions/checkout`,
  `actions/upload-pages-artifact`, `actions/deploy-pages`) plus `pandoc` from the runner's apt
  repository. This repository has no `.github/dependabot.yml`, so nothing automated tracks
  those pins — tracked as #236, and off this change's surface.
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
  obvious choice, and the one this record first made. Rejected — verified: nothing in that
  arrangement supplies a project page's base path, because
  `jekyll-build-pages`' `entrypoint.sh` at v1.0.13 runs `github-pages build` with no base-URL
  argument and `GitHubPages::Configuration` sets neither `url` nor `baseurl`, so the value must
  be pinned by hand and a wrong one builds green and renders unstyled; and the theme's version
  is resolved inside `ghcr.io/actions/jekyll-build-pages:v1.0.13`, a mutable tag no SHA pin
  reaches. `pandoc` with an owned template has neither property.
- **Stage the site with a `scripts/build-site.sh` and a fixture suite rather than inline
  workflow steps.** The variant this repository's anatomy rules demand be weighed, since a
  supporting file has to be argued for. Rejected — verified: `randomparity/bzr`'s
  `.github/workflows/site.yml` builds its site on `pull_request` and gates only the deploy
  step, so inline steps are exercised on every branch; the coverage a script was going to buy
  is available without one, and decision 4's post-build check asserts the part with a failure
  mode.
- **Write `README.md`'s in-repository links as absolute `blob/main` URLs, as
  `randomparity/bzr` does, and drop the rewrite entirely.** The simplest option of all, and
  the reason bzr's build needs no link handling: all 48 links in its `README.md` are already
  absolute. Rejected — judgment: adept's `README.md` ships inside every plugin cache, where a
  relative link resolves to the file sitting next to it and an absolute one sends the reader
  to the network for a file they already have.
- **Copy the landing prose into a site page and leave `README.md` alone.** Removes the rewrite
  and the pandoc step. Rejected — judgment: two documents stating the same thing is the drift
  this project already paid to remove once, and the issue asks for the README itself to be the
  basis for the site.
- **Do nothing — GitHub already renders `README.md` and `docs/cheatsheet.md`.** The null
  option, and it is not nothing: both are readable today at their blob URLs. Rejected —
  judgment: a blob URL is a file listing with prose in it, and the issue asks for a landing
  page a newcomer can be sent to.
