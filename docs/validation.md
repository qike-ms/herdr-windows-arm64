# Native ARM64 validation

The preserved source was built and installed on a Windows ARM64 machine. The installed app opened, connected to the native core, rendered PowerShell, executed `echo HERDR_NATIVE_ARM64_OK`, and returned app status with no errors. A second installed-path smoke used ordinary inherited PATH without build-tool directories. Scratch app/core processes were stopped afterward.

Both Herdr executables, ConPTY DLL, OpenConsole, compilers and the system VCRUNTIME140 were checked as ARM64 (`0xAA64`). Microsoft ConPTY signatures were valid. All 12 installed candidate files matched their recorded SHA-256 hashes. Telemetry was explicitly false, the core path was explicitly pinned, and source-build startup confirmed automatic updates disabled. This repository does not include that machine's settings, raw logs, screenshots or installation receipts.

## Original checks

| Check | Result |
| --- | --- |
| Core Windows end-to-end | 38 passed |
| Core unit tests | 133 passed |
| Rust Ghostty bridge | 15 passed |
| Core Ghostty snapshot suite | 338 passed |
| App Ghostty snapshot suite | 340 passed |
| Ghostty image loading | 105 passed, 10 platform-specific skips |
| Desktop GPU pixel test | Passed with real GPU readback |
| App command/manual and mod-state isolation | Passed |
| App license freshness/completeness | Passed |
| Core non-Cargo notices embedded | Passed after newline normalization |
| Changed Zig formatting/AST and Git whitespace checks | Passed in original build workflow |

Windows tests included Unicode/exact-byte terminal input, OSC 7501 status, Ctrl+C, cleanup, crash/restart recovery, update/rollback, and mocked local SSH transport. Paid real coding-agent workflows, additional mods, and real remote SSH connections were not covered by this port validation.

Original test counts are historical evidence for the pinned preserved source, not a claim that every suite is rerun on each checkout. The public packaging scripts are validated separately by clean source reconstruction and source-file hashes.

## Executable identity

| Tested artifact | SHA-256 |
| --- | --- |
| App 0.1.16 | `83afea94b77dfc89c101aa0a3bb9265bb1cd0da519c485158b79e744dd9ebc20` |
| Core 0.1.21 | `46b66bffba8e261bd6a353ffa6d6622cde9bfe4ae1400e317001b419c35dc684` |
| Original 12-file candidate manifest | `0839fcadb50c8a98a76e3213c61f1b325ff380d1afcc78d6d8eecce553e2a770` |

These identify the tested local binaries. Binaries are not distributed here, and rebuilt executable hashes can differ. The source manifest uses LF-normalized hashes to allow Windows checkout line endings.

## Limits

- The full unfiltered Ghostty suite was attempted but stopped during an oversized compilation. Focused suites completed.
- Debug/ReleaseSafe Ghostty tests hit an ARM64 pointer-alignment compile error in unmodified Zig 0.17.1 standard-library source. Successful Ghostty tests used production ReleaseFast mode. Compiler source was not patched.
- Rustfmt/clippy were absent from the isolated toolchain; their checks were not run.
- Linux, macOS, x64, and the full Ghostty desktop are not validated by this Windows VT-library port.
- The local Herdr builds are unsigned; security-advisory concerns in inherited dependencies remain. See [security notes](../SECURITY.md).
- An independent code review of the original build was unavailable. The owner explicitly allowed that exact local installation. This statement does not claim that a reviewer approved the code.
