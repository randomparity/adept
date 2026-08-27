# 0041 — Keep the quest map as a 1x optimized derivative

## Status

Accepted (2026-08-27)

## Context

The optimized quest map displayed by `README.md` and GitHub Pages is an 812×812,
298,291-byte palette PNG. Pages renders it at approximately 812 CSS pixels, so it is a 1x
asset and looks softer on HiDPI displays. The two optimized README images together weigh
445,574 bytes.

The retained credential-bearing original is only 1254×1254. It cannot provide a true 2x
source for an 812-pixel rendering, while synthesizing a 1624-pixel derivative would add no
source detail. Responsive selection would require raw HTML in `README.md`, which ADR 0034
forbids for a Pages source. ADR 0037 also requires the displayed image to remain an optimized
derivative while the credential-bearing original stays linked, not embedded.

## Decision

Keep `docs/assets/adept-quest-map.png` as the single 812×812 optimized display derivative.
The quest map is deliberately 1x-only at the Pages content width. `README.md` and the Pages
build continue to embed that optimized filename unchanged; the original remains provenance,
not a delivery candidate.

Revisit this decision when a new credential-bearing source contains enough genuine detail for
twice the map's rendered width, when the README/Pages rendering contract gains a safe
responsive-image mechanism that does not require raw HTML, or when either surface materially
changes the map's display width. Any replacement must keep the 1x reader's combined image
payload near the present 445,574 bytes.

## Consequences

- HiDPI readers continue to see a softer quest map at full content-column width.
- A 1x reader downloads no additional bytes, and README and Pages rendering stay identical.
- The repository does not ship a larger file that merely interpolates the existing source.
- The final 1x trade-off and its reconsideration condition are durable rather than implicit.

## Considered & rejected

- **Add a 1624×1624 2x derivative.** verified: `file
  docs/assets/adept-quest-map-original.png` reports a 1254×1254 source, so a 1624-pixel file
  would upscale rather than restore detail.
- **Use `srcset` or `<picture>` in `README.md`.** verified: ADR 0034 requires the Pages
  workflow to reject every raw HTML tag in `README.md`; Markdown image syntax has no responsive
  source-set field.
- **Display the retained original.** verified: `wc -c` reports 3,181,261 bytes for the
  original versus 298,291 bytes for the optimized derivative, and ADR 0037 reserves the
  original as linked provenance rather than a display asset.
- **Cap the Pages rendering at 627 CSS pixels.** judgment: this would make the 1254-pixel
  original nominally 2x only on Pages, shrink a legibility-sensitive map, and leave GitHub's
  README rendering governed by a different layout.
