[CmdletBinding()]
param(
    [ValidateSet('Install','Uninstall','Status')][string]$Action = 'Status',
    [string]$GameRoot,
    [switch]$AllowPrivateProbe,
    [switch]$FixtureRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$maximumAssetBytes = 512 * 1024 * 1024
$Game = @{Title='Skate Story'; Process='SkateStory'; AppId='1263240'; Build='21628663'; AnyLocation=$true}
# Shared installer steps. The game part sets $Game (Title, Process, AppId, Build, AnyLocation), $GameRoot and $maximumAssetBytes.
function Assert-Hash($Value) {
    if ($Value -isnot [string] -or $Value -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid SHA-256 format.' }
}
function Assert-PositiveInteger($Value, [long]$Maximum) {
    if (($Value -isnot [int] -and $Value -isnot [long]) -or $Value -le 0 -or $Value -gt $Maximum) {
        throw 'Manifest resource bound/type violation.'
    }
}
function Assert-TrueBoolean($Value) {
    if ($Value -isnot [bool] -or $Value -cne $true) { throw 'Runtime attestation requires exact true booleans.' }
}
function Assert-Keys($Object, [string[]]$Keys) {
    if ($null -eq $Object -or $Object -isnot [pscustomobject]) { throw 'Invalid object type.' }
    $actual = @($Object.PSObject.Properties.Name)
    if ($actual.Count -ne $Keys.Count) { throw 'Unsupported object properties.' }
    foreach ($key in $Keys) { if ($actual -cnotcontains $key) { throw "Missing exact property: $key" } }
}
function Read-Json([string]$Path) {
    if ((Get-Item -LiteralPath $Path).Length -gt 1048576) { throw 'JSON resource bound exceeded.' }
    $raw = [IO.File]::ReadAllText($Path)
    # ConvertFrom-Json silently keeps the last of duplicate property names, so they are refused first.
    $sets = New-Object 'Collections.Generic.Stack[object]'
    foreach ($token in [regex]::Matches($raw, '"(?:[^"\\]|\\.)*"|[{}]')) {
        if ($token.Value -eq '{') { $sets.Push((New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase))) }
        elseif ($token.Value -eq '}') { if ($sets.Count -eq 0) { throw 'Invalid JSON nesting.' }; $null = $sets.Pop() }
        elseif ($raw.Substring($token.Index + $token.Length).TrimStart().StartsWith(':')) {
            $name = $token.Value | ConvertFrom-Json
            if ($sets.Count -eq 0 -or !$sets.Peek().Add([string]$name)) { throw 'Duplicate JSON property.' }
        }
    }
    return ($raw | ConvertFrom-Json)
}
function Assert-Identity($Identity) {
    Assert-Keys $Identity @('sha256','size')
    Assert-Hash $Identity.sha256
    Assert-PositiveInteger $Identity.size $maximumAssetBytes
}
function Assert-SafePath([string]$Path) {
    $itemPath = [IO.Path]::GetFullPath($Path)
    while ($itemPath) {
        $pathItem = Get-Item -Force -LiteralPath $itemPath -ErrorAction SilentlyContinue
        if ($pathItem -and ($pathItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Reparse point refused: $itemPath"
        }
        $parent = [IO.Path]::GetDirectoryName($itemPath)
        if ($parent -eq $itemPath) { break }
        $itemPath = $parent
    }
}
function Assert-Contained([string]$Root, [string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (!$full.StartsWith($Root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escape refused.' }
    Assert-SafePath $full
    return $full
}
function Get-Sha([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Get-BytesSha([byte[]]$Bytes) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hasher.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}
function Assert-File([string]$Path, $Identity) {
    Assert-SafePath $Path
    if (!(Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -ne $Identity.size -or (Get-Sha $Path) -cne $Identity.sha256) {
        throw "File missing or corrupt: $Path"
    }
}
function Assert-GameStopped {
    foreach ($gameProcess in @(Get-Process -Name $Game.Process -ErrorAction SilentlyContinue)) {
        # Elevated processes hide their path, so an unknown path counts as this game.
        if ($Game.AnyLocation -or !$gameProcess.Path -or [IO.Path]::GetDirectoryName($gameProcess.Path) -eq $GameRoot) {
            throw "Close $($Game.Title) before changing files."
        }
    }
}
function Find-SteamGame {
    $roots = @()
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($entry) { foreach ($property in @('SteamPath','InstallPath')) { if ($entry.PSObject.Properties.Name -contains $property) { $roots += $entry.$property } } }
    }
    $libraries = @($roots)
    foreach ($root in $roots) {
        $file = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $file) { foreach ($match in [regex]::Matches([IO.File]::ReadAllText($file), '"path"\s+"([^"]+)"')) { $libraries += $match.Groups[1].Value.Replace('\\','\') } }
    }
    $games = @()
    foreach ($library in @($libraries | Select-Object -Unique)) {
        $file = Join-Path $library ('steamapps\appmanifest_' + $Game.AppId + '.acf')
        if (Test-Path -LiteralPath $file) {
            $match = [regex]::Match([IO.File]::ReadAllText($file), '"installdir"\s+"([^"]+)"')
            if ($match.Success) { $games += Join-Path (Join-Path $library 'steamapps\common') $match.Groups[1].Value }
        }
    }
    if ($games.Count -ne 1) { throw "Cannot identify one Steam installation. Pass -GameRoot with the $($Game.Title) folder (Steam > Manage > Browse local files)." }
    return $games[0]
}
function Read-SteamBuild {
    # User decision 2026-10-26: the Steam build label only warns. File hashes decide what may be patched.
    $library = [IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($GameRoot))
    $label = $null
    if ($library) {
        $acf = Join-Path $library ('appmanifest_' + $Game.AppId + '.acf')
        Assert-SafePath $acf
        if (Test-Path -LiteralPath $acf -PathType Leaf) {
            if ((Get-Item -LiteralPath $acf).Length -gt 1048576) { throw 'Steam app manifest bound exceeded.' }
            $text = [IO.File]::ReadAllText($acf)
            $apps = [regex]::Matches($text, '"appid"\s+"([^"\r\n]+)"')
            if ($apps.Count -ne 1 -or $apps[0].Groups[1].Value -cne $Game.AppId) { throw 'Steam app mismatch.' }
            $builds = [regex]::Matches($text, '"buildid"\s+"([^"\r\n]+)"')
            if ($builds.Count -eq 1) { $label = $builds[0].Groups[1].Value }
        }
    }
    if ($label -cne $Game.Build) {
        $seen = if ($label) { "Steam reports build $label" } else { 'Steam build is unknown' }
        Write-Warning "$seen, not the tested build $($Game.Build). Continuing with file hash checks."
    }
    return [pscustomobject]@{Label = $label; Changed = ($null -ne $label -and $label -cne $Game.Build)}
}
# One Unity data file patched by a CBDLT001 delta from its verified original backup. Needs installer_core.ps1 and $Action.
$copyBuffer = New-Object byte[] 1048576
function Copy-Count($Source, $Destination, [long]$Count) {
    while ($Count -gt 0) {
        $take = [int][Math]::Min($copyBuffer.Length, $Count)
        $got = $Source.Read($copyBuffer, 0, $take)
        if ($got -eq 0) { throw 'Truncated delta/source.' }
        $Destination.Write($copyBuffer, 0, $got)
        $Count -= $got
    }
}
function Expand-Delta([string]$SourcePath, [string]$StagePath, $member, [string]$patchPath) {
    $sourceStream = $null; $patchStream = $null; $writer = $null; $reader = $null
    try {
        $sourceStream = [IO.File]::Open($SourcePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $patchStream = [IO.File]::Open($patchPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $reader = New-Object IO.BinaryReader($patchStream)
        if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(8)) -ne 'CBDLT001') { throw 'Unsupported delta magic.' }
        $count = $reader.ReadUInt32()
        if ($count -ne $member.patch.operations -or $count -gt 1000000 -or
            $count -gt [Math]::Floor(($patchStream.Length - 12) / 17)) { throw 'Invalid operation count.' }
        $writer = [IO.File]::Open($StagePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        for ($i = 0; $i -lt $count; $i++) {
            $kind = $reader.ReadByte(); $offset = $reader.ReadUInt64(); $length = $reader.ReadUInt64()
            if ($length -gt $member.output.size -or $writer.Position -gt $member.output.size - $length) { throw 'Delta output bounds exceeded.' }
            if ($kind -eq 0) {
                if ($offset -gt $sourceStream.Length -or $length -gt $sourceStream.Length - $offset) { throw 'Delta COPY bounds exceeded.' }
                $sourceStream.Position = [long]$offset
                Copy-Count $sourceStream $writer ([long]$length)
            } elseif ($kind -eq 1 -and $offset -eq 0) {
                Copy-Count $patchStream $writer ([long]$length)
            } else { throw 'Unsupported delta instruction.' }
        }
        if ($patchStream.Position -ne $patchStream.Length -or $writer.Length -ne $member.output.size) { throw 'Delta length mismatch.' }
        $writer.Flush($true)
    } finally {
        if ($writer) { $writer.Dispose() }
        if ($reader) { $reader.Dispose() }
        if ($patchStream) { $patchStream.Dispose() }
        if ($sourceStream) { $sourceStream.Dispose() }
    }
}
function Open-Shared([string]$Path) {
    return [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
}
# $Plan: Target, Backup, Stage, BackupStage, Lock (full paths), Member (original/output/patch), Previous (earlier own outputs),
# PatchPath, Support (@{path; identity} the mod reads but never writes), OriginalBackup (optional), Suffix (Status/result tag).
function Invoke-DeltaInstall($Plan) {
    $target = $Plan.Target; $backup = $Plan.Backup; $stage = $Plan.Stage; $backupStage = $Plan.BackupStage; $member = $Plan.Member
    foreach ($path in @($target,$backup,$stage,$backupStage,$Plan.Lock)) { Assert-SafePath $path }
    if (!(Test-Path -LiteralPath $target -PathType Leaf)) { throw 'Game target file missing.' }
    $name = [IO.Path]::GetFileName($target)
    $lock = $null; $held = @(); $ownStage = $false; $ownBackupStage = $false
    try {
        $held += Open-Shared $Plan.PatchPath
        $steam = Read-SteamBuild
        Assert-GameStopped
        $support = @()
        foreach ($file in @($Plan.Support)) {
            $path = Assert-Contained $GameRoot (Join-Path $GameRoot $file.path)
            $seen = $null
            if (Test-Path -LiteralPath $path -PathType Leaf) { $held += Open-Shared $path; $seen = Get-Sha $path }
            $support += [pscustomobject]@{path=$file.path; full=$path; seen=$seen; tested=($seen -ceq $file.identity.sha256 -and (Get-Item -LiteralPath $path).Length -eq $file.identity.size)}
        }
        $changed = @($support | Where-Object { !$_.tested } | ForEach-Object { $_.path })
        if ($changed.Count -and $Action -eq 'Install') { Write-Warning (($changed -join ', ') + ' differs from the tested build. Thai text may misbehave; run Uninstall if it does.') }
        $targetSha = Get-Sha $target
        if ($targetSha -ceq $member.original.sha256) { Assert-File $target $member.original; $state = 'original' }
        elseif ($targetSha -ceq $member.output.sha256) { Assert-File $target $member.output; $state = 'patched' }
        elseif (@($Plan.Previous | Where-Object { $_.sha256 -ceq $targetSha }).Count) {
            # An earlier output of this program is replaced only from the verified original backup.
            Assert-File $target @($Plan.Previous | Where-Object { $_.sha256 -ceq $targetSha })[0]; $state = 'previous'
        }
        else { $state = 'updated' }
        $backupExists = Test-Path -LiteralPath $backup
        if ($backupExists) { Assert-File $backup $member.original }
        if ($Action -eq 'Status') { return "State=$state; backup=$backupExists; tested_support=$($changed.Count -eq 0); build=$($Game.Build)$($Plan.Suffix)" }
        if ($state -eq 'updated' -and !$steam.Changed) { throw "$name is unknown or modified, and Steam does not report a newer build. The Thai backup is kept. Run Steam > Verify integrity of game files, then try again." }
        if ($state -eq 'updated' -and $Action -eq 'Install') { throw "$name changed in a Steam update; this release cannot patch it. Wait for an updated Thai release." }
        $lock = [IO.File]::Open($Plan.Lock, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        if ($lock.Length -ne 0) { throw 'Unknown lock content; refusing ownership.' }
        if ((Get-Sha $target) -cne $targetSha) { throw 'Target changed before operation lock.' }
        if ($state -eq 'updated') {
            # Steam replaced the patched file in a new build; only the verified backup is ours to remove.
            if (!$backupExists) { return 'Steam already replaced the patched file. Nothing to remove.' }
            Assert-File $backup $member.original; [IO.File]::Delete($backup)
            return 'Steam already replaced the patched file. Removed the Thai backup; game files are untouched.'
        }
        # An interrupted stage is ours only when its complete bytes match a pinned identity.
        foreach ($temporary in @($stage,$backupStage)) {
            if (Test-Path -LiteralPath $temporary) {
                $temporarySha = Get-Sha $temporary
                if ($temporarySha -cne $member.original.sha256 -and ($temporary -cne $stage -or $temporarySha -cne $member.output.sha256)) { throw 'Unknown/partial recovery stage; preserve for manual inspection.' }
                [IO.File]::Delete($temporary)
            }
        }
        if ($state -ne 'original' -and !$backupExists) {
            if (!$Plan.OriginalBackup) { throw 'Patched state requires a verified original backup.' }
            Assert-File $Plan.OriginalBackup $member.original
        }
        if ($Action -eq 'Uninstall' -and $state -eq 'original') { return 'Already original.' }
        if (!$backupExists) {
            $source = if ($state -eq 'original') { $target } else { $Plan.OriginalBackup }
            $ownBackupStage = $true
            [IO.File]::Copy($source, $backupStage, $false)
            Assert-File $backupStage $member.original
            [IO.File]::Move($backupStage, $backup)
            $ownBackupStage = $false
        }
        $held += Open-Shared $backup
        Assert-File $backup $member.original
        if ($Action -eq 'Install' -and $state -eq 'patched') { return 'Already installed.' }
        $ownStage = $true
        if ($Action -eq 'Install') { Expand-Delta $backup $stage $member $Plan.PatchPath; $expected = $member.output }
        else { [IO.File]::Copy($backup, $stage, $false); $expected = $member.original }
        Assert-File $stage $expected
        Assert-GameStopped
        if ((Get-Sha $target) -cne $targetSha) { throw 'Target changed during operation.' }
        foreach ($file in $support) {
            if ($file.seen -and (Get-Sha $file.full) -cne $file.seen) { throw "Game file changed during operation: $($file.path)" }
        }
        Assert-File $backup $member.original
        [IO.File]::Replace($stage, $target, [NullString]::Value)
        $ownStage = $false
        Assert-File $target $expected
        return "$Action complete. SHA256=$($expected.sha256)$($Plan.Suffix)"
    } finally {
        if ($ownStage -and [IO.File]::Exists($stage)) { [IO.File]::Delete($stage) }
        if ($ownBackupStage -and [IO.File]::Exists($backupStage)) { [IO.File]::Delete($backupStage) }
        foreach ($handle in $held) { $handle.Dispose() }
        if ($lock) { $lock.Dispose() }
    }
}
$Package = @{Name='public'; Schema='skate-thai-release/v1'; Status='PUBLIC_RELEASE'; Probe=$false; Suffix=''}

try {
    if ($Package.Probe -and !$AllowPrivateProbe) { throw 'PRIVATE technical probe requires -AllowPrivateProbe. Human approval is separately required before a real game test.' }
    Assert-SafePath $PSScriptRoot
    $manifestPath = Join-Path $PSScriptRoot 'manifest.json'
    Assert-SafePath $manifestPath
    $manifest = Read-Json $manifestPath
    $claims = if ($Package.Probe) { @('runtime_proven','font_visual_accepted','names_approved','complete_thai') } else { @() }
    Assert-Keys $manifest (@('schema','status','profile','binding','appid','buildid','mode','target','preview_manifest_sha256','translation_count','guards','asset') + $claims)
    Assert-Keys $manifest.binding @('project_id','game_id','adapter_id')
    if ($manifest.schema -cne $Package.Schema -or $manifest.status -cne $Package.Status -or
        $manifest.appid -cne '1263240' -or $manifest.buildid -cne '21628663' -or $manifest.mode -cne 'data-only:th' -or
        $manifest.target -cne 'SkateStory_Data/resources.assets' -or $manifest.preview_manifest_sha256 -cne '673ef135a9f0d92ca40de4fd70aab88cef16a457ffd12be46c7b63098f92a88c' -or
        $manifest.binding.project_id -cne '2cc82fbb-920c-4215-a705-b172d16dc1ac' -or $manifest.binding.game_id -cne 'skate-story' -or $manifest.binding.adapter_id -cne 'skate-story-i2' -or
        $manifest.translation_count -ne 2304) { throw 'Wrong project/package/build/frozen snapshot.' }
    foreach ($key in $claims) {
        if ($manifest.$key -isnot [bool] -or $manifest.$key -cne $false) { throw 'Private probe must not claim release acceptance.' }
    }
    $member = $manifest.asset
    Assert-Keys $member @('original','output','previous','patch')
    Assert-Identity $member.original; Assert-Identity $member.output
    if ($member.previous -isnot [array]) { throw 'Previous own outputs must be a list.' }
    $previous = @($member.previous)
    foreach ($prior in $previous) { Assert-Identity $prior }
    Assert-Keys $member.patch @('file','sha256','size','operations')
    Assert-Hash $member.patch.sha256
    Assert-PositiveInteger $member.patch.size $maximumAssetBytes
    Assert-PositiveInteger $member.patch.operations 1000000
    if ($member.patch.file -cne 'resources.cbd') { throw 'Unsupported patch path.' }
    $patchPath = Join-Path $PSScriptRoot 'resources.cbd'
    Assert-File $patchPath ([pscustomobject]@{sha256=$member.patch.sha256;size=$member.patch.size})
    if (!$GameRoot) {
        if ($FixtureRoot) { throw 'Synthetic fixture requires -GameRoot.' }
        $GameRoot = Find-SteamGame
    }
    $GameRoot = [IO.Path]::GetFullPath($GameRoot).TrimEnd([char[]]@('\','/'))
    Assert-SafePath $GameRoot
    if ($FixtureRoot) {
        if ($manifest.profile -cne 'synthetic-fixture' -or (Test-Path -LiteralPath (Join-Path $GameRoot 'SkateStory.exe')) -or
            !(Test-Path -LiteralPath (Join-Path $GameRoot '.skate-synthetic-fixture') -PathType Leaf)) { throw 'Synthetic fixture root required without executable.' }
        $marker = Assert-Contained $GameRoot (Join-Path $GameRoot '.skate-synthetic-fixture')
        if ([IO.File]::ReadAllText($marker) -cne 'skate-private-probe-fixture-v1') { throw 'Wrong synthetic marker.' }
        if ($member.original.sha256 -cne '6204198d9a2cb8c3c975dd5630467e7d6d6d6ee46b050b4acc8f70804fc2a07d' -or $member.original.size -ne 23 -or
            $member.output.sha256 -cne '99491ae537180412be4a61a2e08f5f83e1744530bb85230d0fb5391daf678bf1' -or $member.output.size -ne 22 -or
            $previous.Count -ne 1 -or $previous[0].sha256 -cne '4cde91c8e47f92754ec06d249a238b413d980042c75f37cd3dbbd1d68c80e53e' -or $previous[0].size -ne 23) { throw 'Unsupported fixture identities.' }
        $expectedGuards = [pscustomobject]@{'SkateStory_Data/sharedassets0.assets'='23ccfd339e59be92ed3d7e8f258a27268bc89fe250a91afa09c1d58440c7a630'}
    } else {
        # Assign before @(): PowerShell 5.1 emits a parsed JSON array as one object, so @(ConvertFrom-Json '[]') has one element.
        $expectedPrevious = ConvertFrom-Json '[]'
        $expectedPrevious = @($expectedPrevious)
        if ($manifest.profile -cne $Package.Name -or $member.original.sha256 -cne '3e65be29272f5879bd907a0d0c7f8134f5b5bd35902263dc65381bb0c3a7a82c' -or $member.original.size -ne 275110960 -or
            $member.output.sha256 -cne 'b7caed8b27b7345d077d6debec28ae1c078a21c85c4b0312cbec27ce6c6089c9' -or $previous.Count -ne $expectedPrevious.Count) { throw 'Unsupported production identities.' }
        for ($i = 0; $i -lt $previous.Count; $i++) {
            if ($previous[$i].sha256 -cne $expectedPrevious[$i].sha256 -or $previous[$i].size -ne $expectedPrevious[$i].size) { throw 'Unsupported previous output identity.' }
        }
        $expectedGuards = '{"SkateStory.exe":"af8a4516ca30854f59445dd7548958d18feb293a0a7fc24705e47bdb37acdb40","UnityPlayer.dll":"6ecc1a664d45abb7f8a1d3807b61ec66e8fdeef557bb8f03b526392d8c29b3d8","SkateStory_Data/sharedassets0.assets":"f6a8e39e4b18fbb614d9b11eb6cc79150b8bcdaf0ba223aece9fc52f50d20185","SkateStory_Data/globalgamemanagers.assets":"ba81a3348d6c26e2c6bfdd26c201aa19f0c15fad39875392a545524a22dcabf2","SkateStory_Data/Resources/unity default resources":"f5e29909672ea6bf47805d6fbaf716751090886f7cb39515f5d4b4eaa02ca6a9","SkateStory_Data/Managed/Assembly-CSharp.dll":"da2ae1076c492c1a5992d1a3617032510eaacb01b224cafa80c39705a2954eeb","SkateStory_Data/Managed/I2-Localization.dll":"b11f6ec256e40fe641c87ac294bfbf22cca25d370c4726c3ba98f13d8e4e26b5","SkateStory_Data/Managed/Unity.TextMeshPro.dll":"144fb6bd829421bc27a163b38f1e37c0c4d1013732e952c32b901996e7403645"}' | ConvertFrom-Json
    }
    if ($manifest.guards -isnot [array] -or $manifest.guards.Count -ne @($expectedGuards.PSObject.Properties).Count) { throw 'Required support guards missing.' }
    $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($guard in $manifest.guards) {
        Assert-Keys $guard @('path','identity')
        if ($guard.path -isnot [string] -or !$seen.Add($guard.path) -or @($expectedGuards.PSObject.Properties.Name) -cnotcontains $guard.path -or
            $guard.identity.sha256 -cne $expectedGuards.($guard.path)) { throw 'Unsupported support guard/path.' }
        Assert-Identity $guard.identity
        $null = Assert-Contained $GameRoot (Join-Path $GameRoot $guard.path)
    }
    $target = Assert-Contained $GameRoot (Join-Path $GameRoot $manifest.target)
    $data = [IO.Path]::GetDirectoryName($target)
    Write-Output (Invoke-DeltaInstall @{
        Target = $target; Backup = Join-Path $data '.skate-thai-original-21628663.bak'
        Stage = Join-Path $data '.skate-thai-stage.tmp'; BackupStage = Join-Path $data '.skate-thai-backup.tmp'; Lock = Join-Path $data '.skate-thai.lock'
        Member = $member; Previous = $previous; PatchPath = $patchPath; OriginalBackup = $null; Suffix = $Package.Suffix
        Support = @($manifest.guards)
    })
} catch {
    Write-Error -ErrorAction Continue $_
    exit 1
}
