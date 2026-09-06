# Identity model

This repository is the distribution hub for the TomTonic command-line
tools. Because those tools include supply-chain security tooling, the
identity attached to every published artifact is itself part of the trust
chain: a reviewer must be able to check that the name in the URL, the name
in the GitHub namespace, the name on the signing key and the name in the
package metadata all agree.

This document fixes what that identity is, so it cannot drift again as
tools are added.

## Three layers, deliberately separated

| Layer | Value | Transferable? | Appears in |
|---|---|---|---|
| **Person** | the maintainer as a private individual | — | **nowhere public** |
| **Author** | `Tom Tonic <tom@tomtonic.de>` | **no** — authorship is a historical fact | git commits, copyright lines, `Author:` |
| **Publisher** | `TomTonic package repository <pkg@tomtonic.de>` | **yes** | GPG key UID, `Maintainer:` fields, repository metadata |

The split is what makes two otherwise conflicting goals compatible:

- **Standing behind the work.** The author identity is a stable pseudonym.
  It never transfers, because you cannot hand over having written
  something.
- **Being able to hand over control.** The publisher identity is a *role*,
  not a person. A successor takes over the role — the domain, the keys,
  this repository — without any end user having to re-trust anything and
  without anyone having to rewrite history. See [SUCCESSION.md](SUCCESSION.md).

The private-person layer appears in no published artifact. Notably it must
not appear in:

- `Maintainer:` / `maintainer:` fields of any package (these are served
  publicly in the apt `Packages` index and land in every user's
  `/var/lib/apt/lists/`)
- git commit author or committer fields
- GPG key user IDs

An employer email address in particular must never be used for this work:
besides deanonymizing the pseudonym, it creates an avoidable ambiguity
about who owns the copyright in a project licensed to the public.

## Naming

The public brand is **`tomtonic`** everywhere:

| Where | Value |
|---|---|
| Distribution domain | `pkg.tomtonic.de` |
| GitHub namespace | `github.com/TomTonic` |
| Repository id (apt `Origin`, rpm `[section]`, pacman db, key filenames) | `tomtonic` |
| Human-readable label | `TomTonic package repository` |
| Publisher contact | `pkg@tomtonic.de` |
| Author / `Maintainer:` | `Tom Tonic <tom@tomtonic.de>` |

The decisive criterion was consistency, not aesthetics: this is the only
candidate name that can be held identically across the GitHub namespace,
the domain, the signing key and the package metadata. An earlier iteration
used `acmelab`/`pkg.acmelab.de`, which was abandoned before it had
meaningful adoption for two reasons:

1. `github.com/acmelab` is an unrelated third party's dormant account. The
   brand could therefore never be consistent — the URL would say one
   thing and the GitHub namespace another, which is precisely the kind of
   mismatch a supply-chain attacker exploits.
2. "ACME" is the canonical placeholder name in this industry. A
   distribution domain that reads like a test fixture undermines the
   trustworthiness of the very tools it serves.

## Rules when adding a tool

1. `Maintainer:`/`maintainer:` is `Tom Tonic <tom@tomtonic.de>`; `vendor`
   is `TomTonic`.
2. Commits use the author identity above. Set it per repository
   (`git config user.email tom@tomtonic.de`) or globally, and enable
   GitHub's *Block command line pushes that expose my email* setting as a
   backstop.
3. End-user instructions reference `pkg.tomtonic.de`, never a
   `github.io` URL — the domain is the trust anchor and the thing that
   stays constant if hosting moves.
4. Nothing else about the tool's repository needs to change; it only has
   to upload `nfpm`-built `.deb`/`.rpm`/`.pkg.tar.zst`/`.apk` assets and
   be listed in `manifest.json`.
