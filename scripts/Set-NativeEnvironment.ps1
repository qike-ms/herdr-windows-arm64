#Requires -Version 7.0
# Dot-source inside a disposable PowerShell process. No downloads or global changes.
param(
    [Parameter(Mandatory)][string]$RustRoot,
    [Parameter(Mandatory)][string]$ZigRoot,
    [Parameter(Mandatory)][string]$VcRoot,
    [Parameter(Mandatory)][string]$SdkRoot,
    [Parameter(Mandatory)][string]$SdkLibRoot,
    [Parameter(Mandatory)][string]$OneCoreLib,
    [Parameter(Mandatory)][string]$LlvmRoot,
    [Parameter(Mandatory)][string]$CargoHome,
    [Parameter(Mandatory)][string]$ZigCacheRoot,
    [Parameter(Mandatory)][string]$ScratchRoot,
    [string]$SdkVersion = '10.0.26100.0'
)
. "$PSScriptRoot/Common.ps1"
if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'Arm64') { throw 'Native Windows ARM64 required' }
foreach ($name in @('RustRoot','ZigRoot','VcRoot','SdkRoot','SdkLibRoot','OneCoreLib','LlvmRoot','CargoHome','ZigCacheRoot','ScratchRoot')) {
    Set-Variable -Name $name -Value ([IO.Path]::GetFullPath((Get-Variable -Name $name -ValueOnly)))
}
$vcBin = Join-Path $VcRoot 'bin/Hostarm64/arm64'
$sdkBin = Join-Path $SdkRoot "bin/$SdkVersion/arm64"
$rustBin = Join-Path $RustRoot 'bin'
$llvmBin = Join-Path $LlvmRoot 'bin'
$gitBin = Split-Path (Get-Command git -ErrorAction Stop).Source -Parent
foreach ($file in @("$rustBin/rustc.exe","$rustBin/cargo.exe","$ZigRoot/zig.exe", "$vcBin/cl.exe",
    "$vcBin/link.exe","$vcBin/lib.exe","$llvmBin/clang.exe","$llvmBin/libclang.dll","$sdkBin/rc.exe","$sdkBin/fxc.exe")) {
    Assert-NativeArm64 $file
}
foreach ($dir in @("$SdkRoot/Include/$SdkVersion/ucrt","$VcRoot/include","$SdkLibRoot/ucrt/arm64",
    "$SdkLibRoot/um/arm64",$OneCoreLib)) { if (!(Test-Path -LiteralPath $dir -PathType Container)) { throw "Missing directory: $dir" } }
$env:PATH = (@($rustBin,$ZigRoot,$vcBin,$sdkBin,$llvmBin,$gitBin,"$env:SystemRoot/System32",$env:SystemRoot,
    "$env:SystemRoot/System32/WindowsPowerShell/v1.0","$env:SystemRoot/System32/OpenSSH") -join ';')
$rust = & "$rustBin/rustc.exe" -Vv
if ($LASTEXITCODE -or $rust -notcontains 'release: 1.99.1' -or $rust -notcontains 'host: aarch64-pc-windows-msvc') { throw 'Rust pin mismatch' }
$cargo = & "$rustBin/cargo.exe" --version
if ($LASTEXITCODE -or $cargo -notmatch '^cargo 1\.99\.1 ') { throw 'Cargo pin mismatch' }
$zig = & "$ZigRoot/zig.exe" version
if ($LASTEXITCODE -or $zig -ne '0.17.1') { throw 'Zig pin mismatch' }
$clang = & "$llvmBin/clang.exe" --version
if ($LASTEXITCODE -or ($clang -join "`n") -notmatch 'clang version 23\.1\.5') { throw 'LLVM pin mismatch' }
$env:INCLUDE = (@("$VcRoot/include","$SdkRoot/Include/$SdkVersion/ucrt","$SdkRoot/Include/$SdkVersion/shared",
    "$SdkRoot/Include/$SdkVersion/um","$SdkRoot/Include/$SdkVersion/winrt") -join ';')
$env:LIB = (@("$VcRoot/lib/arm64",$OneCoreLib,"$SdkLibRoot/ucrt/arm64","$SdkLibRoot/um/arm64") -join ';')
$env:LIBPATH = $env:LIB
$env:VCINSTALLDIR = [IO.Path]::GetFullPath((Join-Path $VcRoot '../../..')) + '\'
$env:VCToolsInstallDir = $VcRoot + '\'
$env:WindowsSdkDir = $SdkRoot + '\'
$env:WindowsSdkBinPath = "$SdkRoot/bin/"
$env:WindowsSDKVersion = "$SdkVersion\"
$env:WindowsSDKLibVersion = "$SdkVersion\"
$env:UCRTVersion = $SdkVersion
$env:UniversalCRTSdkDir = $SdkRoot + '\'
$env:CARGO_HOME = $CargoHome
$env:CARGO_TARGET_AARCH64_PC_WINDOWS_MSVC_LINKER = "$vcBin/link.exe"
$env:CC_aarch64_pc_windows_msvc = "$vcBin/cl.exe"
$env:CXX_aarch64_pc_windows_msvc = "$vcBin/cl.exe"
$env:AR_aarch64_pc_windows_msvc = "$vcBin/lib.exe"
$env:LIBCLANG_PATH = $llvmBin
$env:CLANG_PATH = "$llvmBin/clang.exe"
$env:GPUI_FXC_PATH = "$sdkBin/fxc.exe"
$env:RC = "$sdkBin/rc.exe"
$env:RC_PATH = $env:RC
$env:ZIG = "$ZigRoot/zig.exe"
$env:ZIG_GLOBAL_CACHE_DIR = $ZigCacheRoot
$env:CARGO_INCREMENTAL = '0'
$env:LINK = $null
$env:VSCMD_SKIP_SENDTELEMETRY = '1'
$env:NPM_CONFIG_IGNORE_SCRIPTS = 'true'
$env:HERDR_APP_HOME = Join-Path $ScratchRoot 'app-home'
$env:HC_SESSION = 'herdr-arm64-source-build'
$env:HC_TEST_TMPDIR = Join-Path $ScratchRoot 'core-tests'
$env:HERDR_TEST_TMPDIR = Join-Path $ScratchRoot 'app-tests'
$env:HERDR_TELEMETRY = '0'
$env:DO_NOT_TRACK = '1'
$env:HERDR_APP_RELEASE = $null
$env:HERDR_RELEASES_URL = $null
New-Item -ItemType Directory -Path $ScratchRoot,$CargoHome,$ZigCacheRoot -Force | Out-Null
$libc = @"
include_dir=$SdkRoot/Include/$SdkVersion/ucrt
sys_include_dir=$VcRoot/include
cc_dir=
crt_dir=$SdkLibRoot/ucrt/arm64
msvc_lib_dir=$OneCoreLib
kernel32_lib_dir=$SdkLibRoot/um/arm64
darwin_sdk_dir=
"@
$env:HERDR_ZIG_LIBC_FILE = Join-Path $ScratchRoot 'native-libc.txt'
[IO.File]::WriteAllText($env:HERDR_ZIG_LIBC_FILE,$libc.Replace("`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
Write-Output 'Configured isolated native ARM64 build environment.'
