# 0037 — Preserve original image provenance beside optimized derivatives

## Status

Accepted (2026-08-26)

## Context

The logo and quest-map PNGs were generated with OpenAI's image-generation tooling. Their
original files contain `caBX` chunks carrying C2PA Content Credentials. Recompressing the
images for the README and GitHub Pages reduced the logo from 1,354,415 to 147,283 bytes
and the quest map from 3,181,261 to 298,291 bytes, but the encoder produced only image
data chunks and omitted `caBX`.

That omission cannot be repaired by copying the original chunk into a derivative. PNG
marks `caBX` unsafe to copy when image data changes, and the credential describes the
original asset rather than newly quantized pixels. Issuing a credential for a derivative
would require signing capability this repository does not have.

The artwork is decorative and its optimized copies are presentation assets. The
repository nevertheless retains the credential-bearing source files, so provenance can
remain inspectable without making large files part of the README or Pages rendering path.

## Decision

The credential-bearing source PNGs are retained beside their optimized derivatives under
names ending in `-original.png`. The README and Pages site continue to display only the
optimized filenames.

The README's licensing area identifies the artwork as AI-generated, explains that the
display copies may not retain their original C2PA credentials, and links directly to each
credential-bearing original without embedding it.

Loss of embedded credentials from an optimized or otherwise modified derivative is
accepted. Contributors must not copy an unsafe-to-copy provenance chunk from an original
into changed image data. If artwork is replaced, its newly issued credential-bearing file
becomes the retained original and any display copy remains an explicitly documented
derivative.

This policy is enforced through the durable decision record and review, not through a CI
check over image metadata.

## Consequences

- The repository grows by approximately 4.5 MB to keep the two source PNGs.
- GitHub visitors can inspect or download the originals, while normal README and Pages
  loads continue to use the smaller derivatives.
- The optimized files do not make a cryptographic provenance claim. The nearby README
  disclosure supplies human-readable provenance but is not a replacement C2PA manifest.
- Future image optimization may continue without signing infrastructure, provided the
  original remains available and the derivative is not represented as credentialed.
- Reviewers must apply this policy when image assets change; CI does not detect divergence
  between an original and a derivative.

## Considered & rejected

- **Display the credential-bearing originals directly** — verified: the retained logo is
  1,354,415 bytes and the retained quest map is 3,181,261 bytes, versus 147,283 and
  298,291 bytes for their optimized derivatives. Serving the originals would undo the
  page-weight reduction that created the derivatives.
- **Copy `caBX` into each optimized file** — verified: a local PNG chunk walk finds
  `caBX` in both originals and not in either derivative; the chunk's uppercase fourth
  letter marks it unsafe to copy when image data changes. Copying it would contradict the
  PNG chunk contract rather than preserve a valid claim.
- **Fail CI when an image loses `caBX`** — judgment: automated enforcement is
  disproportionate for two decorative assets whose originals are retained. It would
  detect metadata absence but could not issue a valid credential for changed pixels.
- **Extract the original credential into a sidecar file** — judgment: the original PNG
  already preserves the credential in its native context. A detached copy adds another
  artifact and could be mistaken for authentication of the derivative.
- **Add a visible disclosure block to the artwork** — judgment: persistent marking is not
  needed for these decorative repository assets, and adding it would alter the artwork.
  The README disclosure is clearer at its actual point of use.
