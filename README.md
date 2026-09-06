# TomTonic package repository

Signed `apt`/`dnf`/`zypper`/`pacman`/`apk` repository, served at
[pkg.tomtonic.de](https://pkg.tomtonic.de), aggregating packages from
multiple independent tool repositories (see `manifest.json`).

See [pkg.tomtonic.de](https://pkg.tomtonic.de) for end-user install
instructions.

## How it works

`.github/workflows/publish.yml` runs hourly (and on demand). It is fully
stateless: on every run it reads `manifest.json`, downloads the *current*
and *previous* GitHub release of every listed tool, rebuilds all four
package indices from scratch, signs them, and deploys the result to
GitHub Pages. Nothing is accumulated between runs - older versions stay
available forever via each tool's own GitHub Releases, not through this
repo.

Onboarding a new tool: add one entry to `manifest.json`. That tool's own
release workflow just needs to upload `nfpm`-built `.deb`/`.rpm`/
`.pkg.tar.zst`/`.apk` assets for `amd64`/`arm64` (`x86_64`/`aarch64`) -
nothing else changes.

## Why only the index is signed, not every package

- **apt** has no mechanism to sign individual `.deb` files at all - trust
  is *always* rooted in the signed `Release`/`InRelease` file, which
  contains checksums of `Packages`, which contains checksums of every
  `.deb`. This isn't a simplification, it's how apt works.
- **apk** (Alpine) is the same by convention - even the official Alpine
  repositories only sign `APKINDEX`, never individual packages.
- **rpm** and **pacman** *could* additionally sign every package
  individually, but don't need to: their repodata/db already embeds a
  checksum of every package, so once the (signed) index is trusted,
  tampering with any individual package is already detected via checksum
  mismatch - the same guarantee, with one signature instead of many, and
  far simpler to automate reliably in headless CI (rpm's own per-package
  signing tooling is notoriously fragile with `gpg-agent`/pinentry in CI).

The one real gap: someone who downloads a bare `.rpm`/`.pkg.tar.zst`
straight from a tool's GitHub Release (bypassing this repo entirely) has
no *offline* way to verify it standalone. The same is already true for
`.deb`/`.apk`, which are never individually signed either - so this isn't
a weakness specific to rpm/pacman, it's consistent across all four
formats.

## Identity, succession and portability

- [IDENTITY.md](IDENTITY.md) - which identity appears where, and why the
  brand is `tomtonic`.
- [SUCCESSION.md](SUCCESSION.md) - key custody, handover and key rotation
  procedures, and what it would take to move off GitHub.

## Key custody

The two signing keys (GPG for apt/rpm/pacman, a separate RSA key in
Alpine's own format for apk) are what make this repository portable off
GitHub if that's ever needed - as long as the *same* keys keep signing the
index, no end user ever has to re-trust anything, only the DNS target
(`pkg.tomtonic.de`) would need to change. Because GitHub Actions secrets
are write-only, both private keys are also kept outside GitHub (the
maintainer's personal password safe), not solely as repository secrets.

## Signing keys

- GPG (apt/rpm/pacman): fingerprint
  `AA9C 6D63 B7B6 C0BC 18A8 9693 E372 5F71 EDDA EC03`, public key at
  [`pubkey.gpg`](pubkey.gpg).
- Alpine RSA (apk): public key at
  [`alpine/tomtonic.rsa.pub`](alpine/tomtonic.rsa.pub).
