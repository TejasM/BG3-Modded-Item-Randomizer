# MIR build + install script (Phase 2)
$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$src    = Join-Path $root "src"
$outPak = Join-Path $root "MIR.pak"
$divine = "C:\bg3-sidecar-work\Tools\Divine.exe"
$gameMods = Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3\Mods"

if (-not (Test-Path (Join-Path $src "Mods\MIR\meta.lsx"))) { throw "meta.lsx missing" }
$luac = Get-Command luac -ErrorAction SilentlyContinue
if ($luac) {
    Get-ChildItem (Join-Path $src "Mods\MIR\ScriptExtender\Lua") -Recurse -Filter "*.lua" | ForEach-Object {
        & luac -p $_.FullName
        if ($LASTEXITCODE -ne 0) { throw "Lua syntax error in $($_.Name)" }
    }
    Write-Host "Lua syntax OK (all files)"
}

if (Test-Path $outPak) { Remove-Item $outPak -Force }
& $divine -a create-package -g bg3 -s $src -d $outPak
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outPak)) { throw "Divine create-package failed" }

$sha = (Get-FileHash $outPak -Algorithm SHA256).Hash
Write-Host ("Built {0}  size={1}  SHA256={2}" -f $outPak, (Get-Item $outPak).Length, $sha)

# v0.9: verify the PAK CONTENTS against src before installing. The hash check below only
# proves the install copy matches the build output - it cannot notice that the build output
# predates the last source edit, which happened once during v0.9 (a pak shipped two fixes
# stale with every hash agreeing, because they agreed with each other).
$verifyDir = Join-Path $env:TEMP ("mir_verify_" + [System.Guid]::NewGuid().ToString("N"))
& $divine -a extract-package -g bg3 -s $outPak -d $verifyDir | Out-Null
if ($LASTEXITCODE -ne 0) { throw "verification extract failed" }
$diff = @()
Get-ChildItem -Recurse -File $src | ForEach-Object {
    $rel = $_.FullName.Substring($src.Length).TrimStart('')
    $other = Join-Path $verifyDir $rel
    if (-not (Test-Path $other)) { $diff += "missing in pak: $rel" }
    elseif ((Get-FileHash $_.FullName -Algorithm SHA256).Hash -ne (Get-FileHash $other -Algorithm SHA256).Hash) {
        $diff += "differs: $rel"
    }
}
Remove-Item $verifyDir -Recurse -Force -ErrorAction SilentlyContinue
if ($diff.Count -gt 0) { $diff | ForEach-Object { Write-Host $_ }; throw "PAK DOES NOT MATCH SRC - build is stale" }
Write-Host "Pak contents verified against src (all files identical)"

Copy-Item $outPak (Join-Path $gameMods "MIR.pak") -Force
if ((Get-FileHash (Join-Path $gameMods "MIR.pak") -Algorithm SHA256).Hash -ne $sha) { throw "Installed pak hash mismatch" }
Write-Host "Installed to $gameMods\MIR.pak (hash verified)"
