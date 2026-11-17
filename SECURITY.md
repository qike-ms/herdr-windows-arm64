# Security status

This experimental port preserves an older, exactly pinned Herdr dependency set. It is not a security maintenance fork and must not be presented as a patched or audited release.

The original review found unresolved dependency-advisory concerns, including TLS/compression-related dependencies. The owner accepted those concerns for a local build and installation. This does not resolve advisories or extend that risk decision to other users. Reevaluate current upstream advisories and reachability before deploying. Cargo.lock files are intentionally unchanged so the tested source remains identifiable.

The native Herdr executables built locally are unsigned. ConPTY comes from Microsoft's pinned release archive; staging checks SHA-256 and Authenticode status. Toolchains are obtained separately from their publishers, run as the invoking user, and can access that user's files and network. Do not run these scripts elevated.

Herdr terminals, core, agent integrations and mods can run commands with your user access. Telemetry is enabled by default in upstream settings; the documented try configuration disables it explicitly. Ordinary source builds disable application self-updates. Build scripts clear release-related environment flags and do not install background services or change system PATH.

The preparation script fetches source but does not build it. Building can execute Cargo/Zig dependency build logic and fetch locked dependencies. Review dependencies before execution. Cargo's `--offline` is not a guarantee that Zig's dependency resolution is offline too.

No compiler binaries, user profiles, credentials, raw workstation logs, or local installation configuration belong in this public repository. Report vulnerabilities in upstream components through their respective maintainers' security channels.
