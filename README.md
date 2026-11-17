# Herdr on native Windows ARM64

Experimental source port of [Herdr app](https://github.com/herdrdev/herdr-app) 0.1.16 and [herdr-core](https://github.com/herdrdev/herdr-core) 0.1.21 for `aarch64-pc-windows-msvc`.

The built desktop opens on Windows ARM64, connects to its native core, renders a PowerShell terminal, and executes commands. Rust, Zig, MSVC, LLVM, Herdr, and the bundled ConPTY runtime were checked as ARM64. No x64 emulation was used for compilation or Herdr execution.

This repository preserves the exact upstream revisions, four source patches, shared compatibility sources, and scripts needed to reconstruct the port. It is an independent community experiment and is not an official Herdr or Ghostty release. No prebuilt executable is distributed here.

## Build

Use PowerShell 7 on Windows ARM64. Git is needed to fetch source. Supply your own native ARM64 toolchain; the scripts do not install tools, change system PATH, install Herdr, or enable automatic updates.

```powershell
git clone https://github.com/qike-ms/herdr-windows-arm64.git
cd herdr-windows-arm64
pwsh -NoProfile -File ./scripts/Prepare-Sources.ps1
# Create work/toolchain.json with your installed tool paths; see docs/build.md.
pwsh -NoProfile -File ./scripts/Build.ps1 -ToolchainConfig ./work/toolchain.json
pwsh -NoProfile -File ./scripts/Stage.ps1 -ConPtyPackage '<path-to-reviewed-ConPTY.nupkg>'
```

See [build instructions](docs/build.md) for exact versions, tool locations, dependency fetching, and staging. `Prepare-Sources.ps1` verifies 482 preserved source-file/lockfile hashes after reconstruction. Existing destination directories are never reset.

## What changed

| Area | Scope |
| --- | --- |
| Herdr app | ARM64 Ghostty linking, native libc input, baseline CPU, build invalidation |
| Herdr core | ARM64 static CRT, matching Ghostty integration, ARM64 OpenConsole updater paths, ConPTY staging and Windows test portability |
| Embedded Ghostty | Zig 0.17 migration across 185–186 existing files per source pin; shared compatibility helpers |
| uucode | Existing 0.2.0 dependency preserved locally and adapted; original Unicode data retained |
| Notices | Rust 1.99.1 and Zig 0.17.1 notices refreshed; Cargo lockfiles unchanged |

Direct Herdr code/config/test/script edits cover nine files, with 97 inserted and 23 removed lines. Most source edits are the Ghostty migration, approximately 1,200 inserted and 1,270 removed lines per copy, plus five new helper files with 140 lines. The two migrations largely overlap; shared new sources are stored once under `overlay/ghostty`. License text and copied dependency data are excluded from these code counts.

## Validation and limitations

The native build passed an installed-path terminal smoke test, 38 Windows end-to-end tests, 133 core unit tests, 15 Rust Ghostty bridge tests, focused Ghostty snapshot/image tests, and a real GPU pixel test. See [validation](docs/validation.md) for coverage, executable hashes and limits.

This is a tested experimental port, not a fully validated cross-platform Zig migration. The full Ghostty suite did not complete. Debug/ReleaseSafe Ghostty testing encountered a pointer-alignment compile error in the unmodified Zig 0.17.1 standard library; successful tests used production ReleaseFast mode. Other operating systems and x64 builds were not revalidated.

The tested local executables are unsigned. The inherited dependency-advisory findings remain unresolved. Telemetry was explicitly disabled in the tested configuration; ordinary source builds also disable automatic application updates. Do not treat source preservation or passing tests as a security endorsement. Read [security notes](SECURITY.md) before building or running.

## Layout and licenses

- `sources.json`: immutable upstream revisions and compatibility dependency identities.
- `patches/`: complete tracked-file changes for each Herdr and Ghostty revision.
- `overlay/`: previously untracked Rust notices, uucode sources/data, and Ghostty helper files.
- `source-manifest.json`: SHA-256 of every preserved changed/new file and Cargo lockfile, after CRLF-to-LF normalization.
- `scripts/`: source preparation/verification, isolated native environment, build and staging.
- `validation/`: sanitized structured test summaries and original tested executable hashes.

Herdr and the new repository scripts are Apache-2.0; Ghostty and uucode retain their MIT licenses. Unicode data and embedded dependencies retain their respective notices. See [NOTICE](NOTICE), [LICENSE](LICENSE), and [licenses/](licenses/). Microsoft compiler/SDK binaries are not redistributed. ConPTY is supplied separately and verified during staging.
