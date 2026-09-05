# MIR release-bundle assembler.
# Collects the built pak + the current docs + the licence into a versioned folder
# ready for upload, and writes a manifest with SHA256s so the uploaded contents
# can always be traced back to a specific build.
#
# The version is READ FROM THE SOURCE BANNER in Server\Main.lua by default, because
# the banner is what the running code actually prints and is therefore the one
# version string that cannot silently drift from the build. It is cross-checked
# against meta.lsx's Description. Passing -Version overrides both and skips the check.
#
# Usage:  .\assemble_bundle.ps1                 (version taken from Main.lua's banner)
#         .\assemble_bundle.ps1 -Version 0.6.7  (explicit override)
param([string]$Version)

$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Version) {
    $mainLua = Join-Path $root "MIR_Build\src\Mods\MIR\ScriptExtender\Lua\Server\Main.lua"
    if (-not (Test-Path $mainLua)) {
        throw "cannot derive version: $mainLua not found (pass -Version to override)"
    }
    $m = [regex]::Match((Get-Content $mainLua -Raw), 'MIR v(\d+\.\d+\.\d+)')
    if (-not $m.Success) {
        throw "cannot derive version: no 'MIR v<x.y.z>' banner found in Main.lua (pass -Version to override)"
    }
    $Version = $m.Groups[1].Value
    Write-Host ("Version from Main.lua banner: " + $Version)

    # cross-check meta.lsx, so a half-finished version bump cannot ship mislabelled
    $metaPath = Join-Path $root "MIR_Build\src\Mods\MIR\meta.lsx"
    if (Test-Path $metaPath) {
        $meta = Get-Content $metaPath -Raw
        if ($meta -notmatch [regex]::Escape("v$Version.")) {
            throw ("version mismatch: Main.lua banner says v$Version but meta.lsx's Description " +
                   "does not mention it. Reconcile them, or pass -Version to override.")
        }
    }
}

$pak    = Join-Path $root "MIR_Build\MIR.pak"
$docs   = Join-Path $root "dist_docs"
$out    = Join-Path $root ("MIR-" + $Version)

if (-not (Test-Path $pak)) { throw "MIR.pak not found - run MIR_Build\build_mir.ps1 first" }

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out | Out-Null

# the pak, named as the user will see it
Copy-Item $pak (Join-Path $out "MIR.pak") -Force

# user-facing documents
# v1.0.1: the .docx/.pdf renderings and the third-party notices ship too (same set as the CCNS bundle)
foreach ($f in @("README.md", "README.docx", "README.pdf", "INSTALL.md", "INSTALL.docx", "INSTALL.pdf", "CHANGELOG.md", "LICENSE-THIRD-PARTY.md")) {
    $src = Join-Path $docs $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $out $f) -Force }
    else { Write-Warning "missing doc: $f" }
}
Copy-Item (Join-Path $root "LICENSE") (Join-Path $out "LICENSE") -Force

# the Nexus description is for the mod PAGE, not the download - kept beside the
# bundle rather than inside it
Copy-Item (Join-Path $docs "NexusMods_BBCode.txt") (Join-Path $root ("MIR-" + $Version + "_NexusDescription.txt")) -Force

# manifest
$lines = @()
$lines += "MIR - Modded Item Randomizer - release bundle manifest"
$lines += ("version: " + $Version)
$lines += ("assembled: " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
$lines += ""
$lines += "SHA256                                                            bytes  file"
Get-ChildItem $out -File | Sort-Object Name | ForEach-Object {
    $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    $lines += ("{0}  {1,7}  {2}" -f $h, $_.Length, $_.Name)
}
$lines += ""
$lines += "REQUIREMENTS: BG3 Script Extender; Mod Configuration Menu (Nexus 9162), loaded ABOVE MIR."
$lines += "MIR disables itself if MCM is not installed."
$lines | Set-Content (Join-Path $out "MANIFEST.txt") -Encoding utf8

Write-Host ("Bundle assembled: " + $out)
Get-ChildItem $out | Select-Object Name, Length | Format-Table -AutoSize
