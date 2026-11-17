# Building the preserved source

## Native toolchain

The tested configuration used:

| Component | Exact tested version |
| --- | --- |
| Rust compiler, Cargo, standard library | 1.99.1, host and target `aarch64-pc-windows-msvc` |
| Zig | 0.17.1, `aarch64-windows` |
| LLVM / Clang / libclang | 23.1.5, native Windows ARM64 |
| MSVC HostARM64/TargetARM64 tools | package 14.50.35728; tool directory 14.50.35717 |
| MSVC CRT headers | 14.50.35717 |
| ARM64 CRT and OneCore Desktop import libraries | 14.50.35727 |
| Windows SDK | package 10.0.26100.7705; include/bin/lib directory 10.0.26100.0 |
| Microsoft ConPTY | 1.24.260710001 |

Obtain tools from their official publishers under their accompanying licenses. This repository does not bootstrap or redistribute compilers. Native `rc.exe`, `fxc.exe`, ARM64 `cl.exe`/`link.exe`/`lib.exe`, and OneCore ARM64 CRT import libraries are required. The core links its CRT statically; the app uses the system's native VCRUNTIME140 runtime.

Tool archive URLs/hashes recorded during the original build are in `validation/toolchain-downloads.json`; Microsoft/LLVM package identities are in `validation/toolchain-pins.json`. The source manifests and `.zon` hashes pin build dependencies, including translate-c 2.0.0 at `02ff0c523fb92a38939b04d0145c4a9602a74d56` and its Aro dependency at `d0c8c4d9c55daa7ef6e40cf0f630a5b5e900989b`.

## Prepare

```powershell
pwsh -NoProfile -File ./scripts/Prepare-Sources.ps1
pwsh -NoProfile -File ./scripts/Verify-Sources.ps1
```

The script clones both projects, checks out their pinned commits, initializes their pinned Ghostty source, applies patches, and copies shared overlays. It fails if either destination already exists. Choose a new `-WorkRoot` to reconstruct again. Git hooks from upstream repositories are not installed or executed by this script.

`-LocalSourceRoot` is an optional offline reconstruction aid: point it at a folder containing existing `herdr-app` and `herdr-core` clones with their Ghostty checkouts. It clones committed objects with no hard links and applies this repository's patches; it does not copy local changes from those clones. The resulting origin URLs are restored to the canonical public upstreams.

## Configure

Create an untracked `work/toolchain.json`. Each placeholder below is an absolute directory path on your machine:

```json
{
  "RustRoot": "<rust-install-root-containing-bin>",
  "ZigRoot": "<zig-directory-containing-zig.exe>",
  "VcRoot": "<VC/Tools/MSVC/14.50.35717>",
  "SdkRoot": "<SDK-root-containing-Include-and-bin>",
  "SdkLibRoot": "<SDK-library-root-containing-ucrt-and-um>",
  "OneCoreLib": "<VC/Tools/MSVC/14.50.35717/lib/onecore/arm64>",
  "LlvmRoot": "<LLVM-root-containing-bin>",
  "CargoHome": "<cargo-registry-cache-directory>",
  "ZigCacheRoot": "<zig-global-cache-directory>",
  "ScratchRoot": "<scratch-output-directory>",
  "SdkVersion": "10.0.26100.0"
}
```

For a conventional SDK install, `SdkRoot` usually contains the include/bin directories while `SdkLibRoot` is its `Lib` directory. The original build used extracted Microsoft packages, where these roots were separate. `OneCoreLib` must supply the ARM64 OneCore Desktop CRT libraries.

The environment script verifies native ARM64 PE headers, checks Rust/Cargo/Zig/LLVM version strings, constructs a process-local PATH/INCLUDE/LIB and Zig libc description, and isolates app/test state. Run it through `Build.ps1` in a disposable PowerShell process. It changes no user or system environment variables persistently.

## Compile

```powershell
pwsh -NoProfile -File ./scripts/Build.ps1 -ToolchainConfig ./work/toolchain.json
```

Both projects use `cargo build --release --locked --target aarch64-pc-windows-msvc`. The first build can fetch dependencies from pinned Cargo/Git/Zig sources and execute their reviewed build scripts. `--locked` does not mean network-free. Use `-Offline` when the Cargo cache is populated; Zig can still require its separately populated dependency cache. A fully disconnected build needs both caches prepared beforehand.

No package-manager tool installation or npm lifecycle execution is part of these scripts. Original Cargo.lock files remain unchanged. Compiler paths, build directory, timestamps, and environment can affect executable bytes; this repository does not claim bit-for-bit reproducible binaries.

## Stage and try

Supply the separately downloaded ConPTY archive from:

`https://github.com/microsoft/terminal/releases/download/v1.24.11911.0/Microsoft.Windows.Console.ConPTY.1.24.260710001.nupkg`

SHA-256: `9382ad7becb7e4d84e300578d8e4f4df28f43d979d9055d978c42913c47e0e9d`.

```powershell
pwsh -NoProfile -File ./scripts/Stage.ps1 -ConPtyPackage '<absolute-archive-path>'
```

Staging verifies the archive, ARM64 member hashes and signatures, and both Herdr PE headers. It writes a new `dist` tree with license notices and file hashes. It does not install, create shortcuts, alter existing settings, or launch Herdr. The source-built app disables automatic update checks. App settings must explicitly select the newly staged native core and turn telemetry off.

To try it with isolated state, start a new ordinary PowerShell process and use:

```powershell
$stage = (Resolve-Path ./dist).Path
$env:HERDR_APP_HOME = [IO.Path]::GetFullPath('./work/try/app-home')
$env:XDG_STATE_HOME = [IO.Path]::GetFullPath('./work/try/state')
$env:XDG_CONFIG_HOME = [IO.Path]::GetFullPath('./work/try/config')
$env:HC_SESSION = 'herdr-arm64-public-try'
$env:HERDR_TELEMETRY = '0'
$env:DO_NOT_TRACK = '1'
New-Item -ItemType Directory -Path $env:HERDR_APP_HOME -Force | Out-Null
@{core="$stage/core/herdr-core.exe";telemetry=$false} | ConvertTo-Json |
    Set-Content -LiteralPath "$env:HERDR_APP_HOME/settings.json" -Encoding utf8
& "$stage/app/herdr-app.exe"
# After closing the app, stop only this isolated core session:
& "$stage/core/herdr-core.exe" server stop
```

Herdr's core keeps terminals running after its window closes. Review upstream documentation before using a persistent normal profile. Never stop another profile's core as part of testing.

## Verification commands

From a configured native environment, run the focused Rust checks in the reconstructed core root:

```powershell
cargo test --release --locked --offline --target aarch64-pc-windows-msvc -p herdr-core --bin herdr-core
cargo test --release --locked --offline --target aarch64-pc-windows-msvc -p herdr-core --test windows
cargo test --release --locked --offline --target aarch64-pc-windows-msvc -p ghostty-vt
```

Use scratch `HC_SESSION`, `HERDR_APP_HOME`, `XDG_STATE_HOME` and `XDG_CONFIG_HOME` values when testing. The native environment helper sets test temp paths but does not replace your XDG variables. See [validation](validation.md) for checks already completed and known gaps.
