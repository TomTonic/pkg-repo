# Succession, key custody and portability

Two properties are deliberately designed into this repository:

- it can be **handed over** to a different maintainer, and
- it can be **moved off GitHub** entirely,

in both cases without end users having to re-trust anything or change more
than nothing at all. This document records how, so that neither depends on
the current maintainer being around to explain it.

## The trust anchor is the domain and the keys — not GitHub

Everything an end user trusts is rooted in two things:

1. **`pkg.tomtonic.de`** — the DNS name they configured (registrar-managed,
   currently pointing at GitHub Pages via `CNAME`).
2. **The signing keys** — held offline by the maintainer, mirrored into
   GitHub Actions secrets only as working copies.

Neither is owned by GitHub. That is what makes everything below possible.

| Component | Coupling to GitHub | How to replace it |
|---|---|---|
| Domain (registrar) | none | — it *is* the anchor |
| Signing keys (offline custody) | none | — they *are* the anchor |
| Pages hosting | low | static files; repoint DNS, change the deploy step |
| Actions (build) | low | any CI, or run `scripts/*.sh` by hand |
| **Releases as the package source** | **medium** | `scripts/fetch-releases.sh` speaks `gh api`; a different source needs that one script rewritten |
| `brew install TomTonic/tap/<tool>` | high (shorthand only) | the long form `brew tap <name> <git-url>` works against any git host |
| winget | inherent (Microsoft) | a distribution *channel*, not the source of truth — droppable without affecting anything else |

The practical consequence: as long as users point at `pkg.tomtonic.de` and
trust a key from the maintainer's custody, the hosting underneath can be
swapped with **no user-visible change and no re-trust step**. Only
`fetch-releases.sh` is genuinely GitHub-shaped, and it is one file.

## Key custody

| Artifact | Purpose | Where it lives |
|---|---|---|
| GPG private key | signs apt `InRelease`/`Release.gpg`, rpm `repomd.xml.asc`, pacman db | maintainer's password safe **and** `GPG_PRIVATE_KEY` secret |
| GPG revocation certificate | invalidates the key if it is ever lost or compromised | maintainer's password safe **only** — never on GitHub |
| Alpine RSA private key | signs `APKINDEX.tar.gz` | maintainer's password safe **and** `ALPINE_RSA_PRIVATE_KEY` secret |

Current GPG key: `AA9C 6D63 B7B6 C0BC 18A8 9693 E372 5F71 EDDA EC03`,
UID `TomTonic package repository (signs pkg.tomtonic.de apt/rpm/pacman indices) <pkg@tomtonic.de>`,
no expiry.

Both private keys are passphrase-less, because the publish workflow imports
and uses them unattended. That is an accepted trade-off, and it is why the
revocation certificate is kept *outside* GitHub: if the secrets are ever
exposed, revocation must not depend on the same system that leaked them.

## Handing over to a new maintainer

The publisher identity is a role, so a handover does not require rewriting
anything historical. In order:

1. Transfer the `pkg.tomtonic.de` DNS record (or delegate the subdomain) to
   the successor, or transfer the domain itself.
2. Transfer this repository, and grant access to the tool repositories
   listed in `manifest.json`.
3. **Rotate the signing keys** (below). Do not simply hand over the private
   keys: a key that two parties have held can no longer attribute a
   signature to one of them.
4. Update [IDENTITY.md](IDENTITY.md) with the new publisher contact. The
   *author* identity in historical commits stays as it is — it records who
   wrote what, which does not change on handover.

## Key rotation

Rotation is also the remedy for a suspected key compromise; only the
urgency differs.

1. Generate the new key with the same role UID pattern
   (`TomTonic package repository (signs pkg.tomtonic.de …) <pkg@tomtonic.de>`),
   4096-bit RSA, no expiry, no passphrase. Keep its revocation certificate
   in the safe.
2. Publish a **signed key transition statement**: a plain-text statement
   naming both the old and the new fingerprint, signed with *both* keys, so
   that anyone who already trusts the old key can verify the new one
   without an out-of-band channel. Serve it at
   `https://pkg.tomtonic.de/key-transition.txt` and link it from
   `index.html`.
3. Replace `pubkey.gpg` / `alpine/tomtonic.rsa.pub` in this repository,
   update the fingerprint in `index.html`, `README.md` and `IDENTITY.md`,
   and update both GitHub Actions secrets.
4. Re-run the publish workflow: the indices are rebuilt and re-signed from
   scratch on every run, so one run is enough to complete the switch.
5. If rotating because of a compromise, additionally publish the old key's
   revocation certificate.

Note that end users on apt/apk must import the new public key manually —
neither format auto-rotates trusted keys. The transition statement is what
lets them do that safely, which is why step 2 is not optional.

## Retiring a distribution channel

Channels are independent. Dropping Homebrew, winget, or even the whole
Linux repository affects only that channel's users; every tool remains
installable from its own GitHub Releases, and every release asset stays
byte-identical to what this repository served. There is no state here that
anything else depends on — this repository is fully stateless and rebuilt
from scratch on every run.
