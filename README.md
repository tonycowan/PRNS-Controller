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

**Pin:** one Prns commit SHA, plus the three successful Actions run IDs that
uploaded the artifacts above **for that same SHA**. Record the SHA, run IDs,
and SHA-256 digests in every Release.

Known gap: a separate CI artifact named `inspect-windows` has come down empty (206 bytes, one directory entry). The shippable `PRNS-Controller-windows-unsigned.zip` from the same effort was not empty. `release.yml` checks that zip for a real `hopspot-flash.exe`, not for an embedded `firmware/` tree.

## Open from the 2026-09-18 trial

Detail is in `notes/package-trial-2026-09-18.md`. These are not release-shell work.

- Linux desktop needs `libxdo` and the GTK/WebKit libraries, and the tarball never says so. Add a note in the archive, or a launcher that checks for them.
- Windows USB Auto stays silent in the UI when `adb` holds the phone (Windows error 5) or the accessory interface is not bound to WinUSB. The log already has the reason. Show it on the interface card. Operator docs should cover `adb kill-server` and the WinUSB binding order.
- The 64×128 pairing code is too small, and the screen does not show time remaining. A slow entry and a rejection look the same.
- Pixel Controller aborted twice in `WryActivity_create` on launch. One restore after an adoption attempt logged `persistence_restored` with `dropped=1`.

## Actions secrets and variables

Credentials are **not** stored in git. Secrets are encrypted and masked in logs. Variables are plain configuration, visible to people who can see the repository settings.

**Secrets**

| Name | Purpose |
|------|---------|
| `PRNS_ACTIONS_TOKEN` | Token with Actions read access on `tonycowan/Prns` |
| `APPLE_CERTIFICATE_P12_BASE64` | Developer ID Application `.p12`, base64 |
| `APPLE_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `APPLE_API_KEY_BASE64` | App Store Connect API key (`.p8`), base64 |

**Variables**

| Name | Purpose |
|------|---------|
| `APPLE_SIGNING_IDENTITY` | `Developer ID Application: … (TEAMID)` |
| `APPLE_TEAM_ID` | Apple team ID |
| `APPLE_API_KEY_ID` | App Store Connect key ID |
| `APPLE_API_ISSUER` | App Store Connect issuer ID |

`PRNS_ACTIONS_TOKEN` is required for every run. The Apple secrets and variables are required only when `sign_macos=true`.

`release.yml` publishes a GitHub Release only when it runs on `main` and
`publish=true`. Develop the workflow on `trunk`; promote to `main` before
cutting a Release.
