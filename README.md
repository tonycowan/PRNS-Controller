# PRNS Controller (release shell)

Product surface for **PRNS Controller** downloads, signing, and GitHub Releases.

Application source, `hopspot-flash`, firmware trees, and **unsigned** portable
builds stay in the Prns monorepo (`tonycowan/Prns` packaging workflows for now;
not landed on KenAKAFrosty/Prns). This repo does **not** rebuild the app from
source for releases.

## Branches

| Branch | Role |
|--------|------|
| `main` | Long-lived stable line. Default branch. Cut **GitHub Releases** (tags) from here — that is what people should download. |
| `trunk` | Day-to-day work. Promote into `main` when a release is ready. |

Branch names are local to this repo (Ken’s Prns `trunk` is unrelated). Do not treat either tip as an installable binary — install from **Releases**.

## Unsigned artifact contract (Prns → this repo)

Canonical unsigned packages (built in Prns):

| Platform | Artifact name | Archive |
|----------|---------------|---------|
| macOS | `PRNS-Controller-macos-unsigned` | `PRNS-Controller-macos-unsigned.zip` |
| Linux | `PRNS-Controller-linux-unsigned` | `PRNS-Controller-linux-unsigned.tar.gz` |
| Windows | `PRNS-Controller-windows-unsigned` | `PRNS-Controller-windows-unsigned.zip` |

Produced by Prns workflows (fork-side today):

- `controller-macos-package`
- `controller-linux-package`
- `controller-windows-package`

**Pin (preferred):** a Prns **git tag** (or immutable commit SHA) on
`tonycowan/Prns` that includes the packagers, plus the three successful Actions
runs that uploaded the artifacts above for that ref.

**Pin (interim):** an explicit Actions run ID per platform while packaging still
lives on a WIP/fork branch (`wip/controller-packages-on-ken` / portable-package
CI). Record the Prns SHA and run IDs in the Release notes for every product
release.

Each release in this repo should record:

1. Prns ref (tag or SHA)
2. macOS / Linux / Windows artifact digests (SHA-256)
3. Whether the build is unsigned-only or Developer ID + notarized (macOS)

## Signing secrets (this repo)

Apple (and later Windows) credentials live as **GitHub Actions secrets on
`tonycowan/PRNS-Controller`**, not in Prns:

- Developer ID Application certificate + notarization (`notarytool`) credentials
- Optional later: Windows Authenticode

Prns keeps producing unsigned archives; this repo downloads, signs/notarizes,
and publishes Releases from `main`.

## Status

Scaffold only: branch model and artifact contract. Signing workflows and the
first published Release come next, once a pinned unsigned triple exists for a
stable Prns ref.
