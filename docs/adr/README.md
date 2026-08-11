# Architecture decision records

One file per decision, named `NNNN-kebab-title.md`, checked by
`.github/scripts/check-records.sh` under the `adr` profile (`just records`).

There is deliberately no index table here. The directory listing is the index,
and a table beside it is a second copy to keep in sync — the gate warns
(`W-INDEX-TABLE`) when one appears.

Records are append-only once merged. Supersede a decision with a new record and
a banner on the old one; do not rewrite history in place.
