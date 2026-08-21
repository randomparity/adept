# Architecture decision records

One file per decision, named `NNNN-kebab-title.md`, checked by
`.github/scripts/check-records.sh` under the `adr` profile (`just records`).

There is deliberately no index table here. The directory listing is the index,
and a table beside it is a second copy to keep in sync — the gate warns
(`W-INDEX-TABLE`) when one appears.

Numbering has deliberate gaps: no 0006 was ever written, and 0023 and 0027
were cited by suite comments before any record carried them. Those comments
have since been reworded to state their rules standalone. The numbers stay
unallocated rather than being reused, so nothing silently re-points at a
record that does not exist.

Records are append-only once merged. Supersede a decision with a new record and
a banner on the old one; do not rewrite history in place.
