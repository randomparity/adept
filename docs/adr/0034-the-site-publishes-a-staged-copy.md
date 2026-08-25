# 0034 — The site publishes a staged copy, not the repository

## Status

Accepted (2026-08-25)

## Context

Issue #234 asks for a GitHub-hosted website for adept, built from `README.md`, carrying a
feature list, what distinguishes adept from other workflow tools, and a quick start. The
operator scoped the site to two pages: the README-derived landing page and
`docs/cheatsheet.md`.

GitHub Pages offers two source modes. *Deploy from a branch* points Pages at a branch and a
root — either `/` or `/docs` — and GitHub runs Jekyll over everything it finds there.
*Deploy from GitHub Actions* publishes whatever artifact a workflow uploads.

The choice matters more here than in an ordinary repository, because this one is a plugin
and both harnesses copy the **whole** tree into their plugin cache. Every tracked Markdown
file is therefore a live candidate page under a branch source, and there are a lot of them:
at `bdcc640`, `git ls-files '*.md' | wc -l` reports 141, of which 28 are `skills/*/SKILL.md`
files that already carry YAML front matter, and 104 sit under `docs/` — ADRs, specs, plans,
and benchmarks the operator's scope decision excludes from this site.

`README.md` also has to stay the single source for the landing page. CLAUDE.md's
instruction-file rule — two documents stating the same thing is the drift problem this
project spent real effort removing — binds a second copy of the landing prose exactly as it
binds a second `AGENTS.md`.

## Decision

**Pages source is GitHub Actions, and the workflow publishes a staged directory assembled
from named sources.** Nothing reaches the site because it happens to be in the repository.

1. `scripts/build-site.sh <output-dir>` assembles the staged site from tracked files:
   `site/_config.yml`, `README.md` → `index.md`, `docs/cheatsheet.md` → `cheatsheet.md`,
   and the two images under `docs/assets/` → `assets/`. It injects the Jekyll front matter
   each staged page needs and rewrites the links that only make sense inside the
   repository. It writes only into the output directory and never edits a tracked file.
2. **Publication is default-closed.** Only the paths that script names can reach the site.
   A new skill, a new ADR, a new top-level directory publishes nothing until someone edits
   the script and its suite — the opposite of an exclusion list, where the same events
   publish by default and the leak is silent.
3. Rendering is `actions/jekyll-build-pages` with `jekyll-theme-cayman`. The action carries
   the `github-pages` gem set, so this repository gains no `Gemfile`, no lockfile, and no
   vendored CSS.
4. **Pages is enabled once, out of band, by an operator with admin.** The workflow does not
   enable it, but it does keep `actions/configure-pages` as its first build step — with
   `enablement` left off, that step is what turns a missing setting into an error naming it,
   and it is the only reason the step is there, since it feeds nothing into the Jekyll build.

## Consequences

- Adding a page to the site is an edit to `scripts/build-site.sh` and its suite, not a
  settings change. That is the intended cost: the page set is reviewable in a diff.
- The staged copy is where site-only concerns live — front matter, the stripped leading H1
  the theme's header would otherwise duplicate, links rewritten to GitHub blob URLs. None of
  it lands in `README.md`, which stays readable on GitHub and inside the plugin cache.
- The link rewriting is a real behaviour with a real failure mode, so it is testable and
  tested: `scripts/build-site-test.sh` runs under `just test`, and `just site` runs the
  assembly under `just verify`, where a `README.md` link to a path that no longer exists
  goes red before it reaches the site as a 404.
- The repository gains three pinned third-party action references
  (`actions/configure-pages`, `actions/upload-pages-artifact`, `actions/deploy-pages`) plus
  `actions/jekyll-build-pages`. Each is a supply-chain surface `$restock` and Dependabot now
  track, and `zizmor` audits the workflow's `pages: write` and `id-token: write` grants. The
  fourth is pinned less than the other three and the difference is worth stating: its
  `action.yml` at v1.0.13 is a Docker action pulling the mutable tag
  `ghcr.io/actions/jekyll-build-pages:v1.0.13`, so a SHA pin fixes the action and not the
  image behind it, and Dependabot watches the reference rather than the tag. Accepted for a
  two-page static build with no secrets in the job; no machinery is added for it.
- The first deployment cannot succeed until an operator enables Pages. That is a documented
  one-time step, and a workflow run that fails on it names the missing setting rather than
  publishing a half-site — verified from `actions/configure-pages` at v6.0.0, whose
  `findOrCreatePagesSite` raises "Please verify that the repository has Pages enabled and
  configured to build using GitHub Actions" and rethrows when `enablement` is off, before
  any artifact is uploaded.
- The theme is GitHub's, not this repository's, and it is frozen at the version the pinned
  `actions/jekyll-build-pages` reference carries — a cayman release does not reach the site
  on its own. The appearance changes only when that pin is bumped, which arrives as a
  reviewable pull request. Accepted: the alternative is CSS nobody here wants to own.
- The staged landing page embeds both README images verbatim — 4,535,676 bytes together at
  `bdcc640` — so the page a newcomer is sent to weighs about 4.5 MB before a byte of theme
  CSS. Accepted here rather than managed by a resizing step in the build script, which would
  add an image toolchain to a two-page site. Reducing it is a README change in the
  implementation, not a change to this decision.

## Considered & rejected

- **Deploy from a branch with the repository root as the source, excluding the rest in
  `_config.yml`.** The cheapest to set up — no workflow at all. Rejected — verified: at
  `bdcc640`, `git ls-files '*.md' | wc -l` reports 141 tracked Markdown files, 28 of them `SKILL.md`
  files that already carry YAML front matter and would render as pages; an exclusion list
  publishes every one of them by default and leaks silently the first time a directory is
  added, which is the failure mode this repository's construction rules exist to refuse.
- **Deploy from a branch with `/docs` as the source.** Narrower, and needs no workflow.
  Rejected — verified: at `bdcc640`, `git ls-files 'docs/*.md' 'docs/**/*.md' | wc -l` reports
  104 files under `docs/`, comprising the ADRs, specs, plans, and benchmarks the operator's
  scope decision excluded; the folder source publishes exactly the set that was ruled out.
- **Keep the GitHub Actions source but stage inline in the workflow** — a handful of `run:`
  steps doing the same copy, front-matter injection and link rewriting, with no
  `scripts/build-site.sh`, no suite, and no `just` recipe. The variant this repository's
  anatomy rules most directly demand be weighed, since a supporting file has to be argued
  for. Rejected — judgment: the workflow fires only on `push` to `main`, so inline steps are
  first exercised after the merge that would break the site, while a script is a thing
  `just verify` runs on every branch and a suite can drive with fixtures — the link
  rewriting is the part with a failure mode, and it is exactly the part inline staging
  leaves untested.
- **An orphan `gh-pages` branch as a deploy-from-a-branch source.** The alternative that
  attacks this record's own two arguments hardest: it is default-closed by construction, so
  the 141-file leak does not arise, and it needs no `pages: write`, no `id-token: write`,
  and none of the four action references booked above as supply-chain surface. Rejected —
  judgment: it puts generated output in git, where a reader cannot tell it from source and
  no gate covers it, and it moves the sync problem from a reviewable script to a branch
  someone has to remember to regenerate.
- **Copy the landing prose into a site page and leave `README.md` alone.** Removes the
  staging step entirely. Rejected — judgment: two documents stating the same thing is the
  drift this project already paid to remove once, and the issue asks for the README itself
  to be the basis for the site.
- **Render with `pandoc` and a hand-written HTML template plus CSS.** Avoids Jekyll and
  Ruby. Rejected — judgment: it trades a maintained theme for stylesheet and template
  authorship this repository would then own forever, to produce the same two pages.
- **Enable Pages from the workflow with `actions/configure-pages`'s `enablement: true`.**
  Would remove the one-time manual step. Rejected — verified: that action's own `action.yml`
  at v6.0.0 documents the input as requiring "a token other than `GITHUB_TOKEN`" — a PAT
  with `repo` scope or a GitHub App; this repository holds no secrets and adding one to
  spare a single setting click is a standing credential in exchange for a one-off.
- **Publish the ADRs, specs, plans, and benchmarks under `docs/` as further site pages.**
  Rejected — verified: the operator's scope decision recorded in the `WORK:SCOPE`
  annotation on issue #234 excludes them, naming the landing page and the cheat sheet as
  the whole site.
- **Do nothing — GitHub already renders `README.md` and `docs/cheatsheet.md`.** The null
  option, and it is not nothing: both files are readable today at their blob URLs. Rejected
  — judgment: a blob URL is a file listing with prose in it, and the issue asks for a
  landing page a newcomer can be sent to, which is a different artifact from the file that
  happens to contain the same words.
