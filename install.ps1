<#
  install.ps1 — a Windows Terminal Claude-indítóinak telepítése vagy frissítése, offline.
  Többször is futtatható (idempotens). Hálózatot nem használ, git-távoli tárolót nem állít be.

  Két mód, a futás helyéből adódik:
    - Git-klónból (van .git): helyben telepít, a profilok a klónra mutatnak.
    - Letöltött csomagból (ZIP, pendrive, megosztó): a fájlokat a
      %LOCALAPPDATA%\claude-terminal mappába másolja, és onnan köti be. Frissítéskor a
      programfájlokat felülírja, a gép projektlistájához (claude-projektek.txt) és
      beállításához (gep.json) nem nyúl.
      Indítás: dupla kattintás a telepites.cmd-re.

  A projektlista (claude-projektek.txt) gépenkénti, repóba nem kerül; ha még nincs, a
  claude-projektek.minta.txt-ből készül.

  A gép munkamappái (gep.json a telepítési mappában, repóba nem kerül):
    első telepítéskor megkérdezi a Céges és a Magán profil mappáját (Enter = javaslat,
    "-" = az a profil ne legyen), később ezeket használja. Újrakérdezés: -Ujrakonfig.
    Paraméterrel is megadható: -Ceges <mappa> -Magan <mappa|->. Ha nincs kitől
    kérdezni (átirányított bemenet), a javaslatot veszi.

  A wt-claude.json alapján a Terminal settings.json-jában (előtte mentés):
    - a profilokat guid szerint cseréli / a lista elejére teszi;
    - az actionöket id szerint cseréli vagy hozzáadja;
    - a gyorsbillentyűket id szerint cseréli, az azonos billentyűn ülő mást törli;
    - a New Tab Menu tetejére teszi a profilokat egy elválasztóval;
    - végül a claude-projekt.ps1 -CsakPaletta frissíti a parancspaletta projekt-almenüit.
#>
[CmdletBinding()]
param([string]$Ceges, [string]$Magan, [string]$Cel, [switch]$Ujrakonfig, [switch]$NincsIkon, [switch]$WhatIf)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) { throw 'PowerShell 7 (pwsh) szükséges: winget install Microsoft.PowerShell' }
    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @PSBoundParameters
    exit $LASTEXITCODE
}

function Say($m) { Write-Host "  $m" }
$interactive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected

$GuidProjekt = '{c1a0de00-0000-4c1a-8000-0000000b0a1d}'
$GuidCeges   = '{c1a0de00-0000-4c1a-8000-00000000ce9e}'
$GuidMagan   = '{c1a0de00-0000-4c1a-8000-0000000a9a40}'

$verFile = Join-Path $PSScriptRoot 'VERSION'
$ver = if (Test-Path $verFile) { ' v' + (Get-Content $verFile -TotalCount 1).Trim() } else { '' }
Write-Host "Claude Windows Terminal-indítók telepítése$ver"

# --- 0. előfeltételek -----------------------------------------------------------
# A telepítő maga nem tölt le semmit, csak megmondja, mi hiányzik és hogyan pótolható.
if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    Say 'HIÁNYZIK: Windows Terminal. Telepítés: winget install Microsoft.WindowsTerminal'
    Say '          (vagy a Microsoft Store-ból), utána indítsd el egyszer, és futtasd újra ezt a telepítőt.'
    return
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Say 'FIGYELEM: a claude parancs nem található, a profilok ettől még települnek, de Claude nélkül nem indulnak.'
    Say '          Claude Code telepítése (PowerShell): irm https://claude.ai/install.ps1 | iex'
    Say '          Ha telepítve van, de nincs a PATH-on, nyiss új ablakot, vagy jelentkezz ki és be.'
}

# --- 1. hova ------------------------------------------------------------------
$src = $PSScriptRoot
$dst = if (Test-Path (Join-Path $src '.git')) { $src }
       elseif ($Cel) { [IO.Path]::GetFullPath($Cel) }
       else { Join-Path $env:LOCALAPPDATA 'claude-terminal' }

if ($dst -ne $src) {
    $isUpdate = Test-Path (Join-Path $dst 'claude-projekt.ps1')
    Say "$(if ($isUpdate) { 'Frissítés' } else { 'Telepítés' }): $dst"
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Force (Join-Path $dst 'icons') | Out-Null
        foreach ($f in 'claude-projekt.ps1', 'kepernyokep.ps1', 'install.ps1', 'wt-claude.json', 'README.md', 'telepites.cmd', 'claude-projektek.minta.txt', 'VERSION', 'CHANGELOG.md') {
            if (Test-Path (Join-Path $src $f)) { Copy-Item (Join-Path $src $f) (Join-Path $dst $f) -Force }
        }
        Copy-Item (Join-Path $src 'icons\*') (Join-Path $dst 'icons') -Force
        # Letöltött fájlok "internetről jött" jelölése le, különben a pwsh nem futtatja őket
        Get-ChildItem $dst -Recurse -File | Unblock-File
    }
} else {
    Say "Helyben (git-klón): $dst"
}

# A gép saját projektlistája (repóba nem kerül); ha még nincs, a mintából készül
$dstList = Join-Path $dst 'claude-projektek.txt'
if (-not (Test-Path $dstList) -and -not $WhatIf) {
    Copy-Item (Join-Path $dst 'claude-projektek.minta.txt') $dstList
    Say 'projektlista létrehozva a mintából: claude-projektek.txt'
}

# --- 2. a gép munkamappái -------------------------------------------------------
$gepFile = Join-Path $dst 'gep.json'
$gep = if (Test-Path $gepFile) { [IO.File]::ReadAllText($gepFile, [Text.Encoding]::UTF8) | ConvertFrom-Json } else { $null }

function Resolve-WorkDir([string]$label, [string]$given, [string]$stored, [string]$suggest) {
    if ($given) { return $given }
    $gone = $stored -and $stored -ne '-' -and -not (Test-Path -LiteralPath $stored -PathType Container)
    if ($gone) {
        Write-Host "  A(z) $label profil elmentett mappája ($stored) már nem létezik." -ForegroundColor Yellow
        if (-not $interactive) { return $stored }
        $stored = $null
    }
    if ($stored -and -not $Ujrakonfig) { return $stored }
    $def = if ($stored) { $stored } else { $suggest }
    if (-not $interactive) { return $def }
    while ($true) {
        $a = (Read-Host "  $label munkamappa (Enter = $def, - = ne legyen ilyen profil)").Trim().Trim('"')
        if (-not $a) { $a = $def }
        if ($a -eq '-') { return '-' }
        if (Test-Path -LiteralPath $a -PathType Container) { return (Resolve-Path -LiteralPath $a).Path.TrimEnd('\') }
        if ((Read-Host "  A(z) $a nem létezik. Létrehozzam? (i/n)").Trim() -match '^[iIyY]') {
            if (-not $WhatIf) { New-Item -ItemType Directory -Force $a | Out-Null }
            return $a.TrimEnd('\')
        }
    }
}
$sugCeges = if (Test-Path 'D:\CLAUDE') { 'D:\CLAUDE' } else { $env:USERPROFILE }
$sugMagan = Join-Path $env:USERPROFILE 'claude-workspace'; if (-not (Test-Path $sugMagan)) { $sugMagan = $env:USERPROFILE }
$Ceges = Resolve-WorkDir 'Céges' $Ceges $gep.Ceges $sugCeges
$Magan = Resolve-WorkDir 'Magán' $Magan $gep.Magan $sugMagan
if (-not $WhatIf) {
    [IO.File]::WriteAllText($gepFile, ([ordered]@{ Ceges = $Ceges; Magan = $Magan } | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
}
Say "Céges: $(if ($Ceges -eq '-') { '(nincs)' } else { $Ceges }), Magán: $(if ($Magan -eq '-') { '(nincs)' } else { $Magan })  (a gép saját beállítása, gep.json; módosítás: -Ujrakonfig)"

# --- 3. Windows Terminal settings.json ------------------------------------------
$wt = @(
    'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json',
    'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json',
    'Microsoft\Windows Terminal\settings.json'
) | ForEach-Object { Join-Path $env:LOCALAPPDATA $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $wt) { Say 'FIGYELEM: a Windows Terminal beállításfájlja nem található. Indítsd el egyszer a Terminalt, zárd be, és futtasd újra.'; return }

$esc = { param($s) ($s | ConvertTo-Json).Trim('"') }
$raw = [IO.File]::ReadAllText((Join-Path $dst 'wt-claude.json'), [Text.Encoding]::UTF8)
$raw = $raw.Replace('{{REPO}}', (& $esc $dst)).Replace('{{CEGES}}', (& $esc $Ceges)).Replace('{{MAGAN}}', (& $esc $Magan))
$frag = $raw | ConvertFrom-Json

# Kihagyott profilok és a hozzájuk tartozó action / billentyű / menütétel
$allGuids = @($frag.profiles.guid)
$skip = @(); if ($Ceges -eq '-') { $skip += $GuidCeges }; if ($Magan -eq '-') { $skip += $GuidMagan }
$skipActs = @($frag.actions | Where-Object { $_.command.profile -in $skip } | ForEach-Object id)
$profiles = @($frag.profiles | Where-Object { $_.guid -notin $skip })
$actions  = @($frag.actions | Where-Object { $_.id -notin $skipActs })
$keys     = @($frag.keybindings | Where-Object { $_.id -notin $skipActs })
$menuTop  = @($frag.newTabMenuTop | Where-Object { $_ -notin $skip })

$cfg = [IO.File]::ReadAllText($wt, [Text.Encoding]::UTF8) | ConvertFrom-Json
function Ensure-Prop($obj, $name, $value) {
    if (-not ($obj.PSObject.Properties.Name -contains $name)) { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}
Ensure-Prop $cfg 'profiles' ([pscustomobject]@{ list = @() })
if ($cfg.profiles -is [array]) { $cfg.profiles = [pscustomobject]@{ list = $cfg.profiles } }
Ensure-Prop $cfg.profiles 'list' @()
Ensure-Prop $cfg 'actions' @()
Ensure-Prop $cfg 'keybindings' @()

# Globális beállítások (pl. windowingBehavior: új ablak helyett a meglévő ablak új füle)
if ($frag.PSObject.Properties.Name -contains 'globals') {
    foreach ($p in $frag.globals.PSObject.Properties) {
        if ($cfg.PSObject.Properties.Name -contains $p.Name) { $cfg.($p.Name) = $p.Value }
        else { $cfg | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value }
    }
}

$cfg.profiles.list = @($profiles) + @($cfg.profiles.list | Where-Object { $_.guid -notin $allGuids })

$byId = @{}; foreach ($a in $actions) { $byId[$a.id] = $a }
$done = @{}
$acts = foreach ($a in $cfg.actions) {
    if ($a.id -in $skipActs) { continue }
    if ($a.id -and $byId.ContainsKey($a.id)) { $byId[$a.id]; $done[$a.id] = 1 } else { $a }
}
$cfg.actions = @($acts) + @($actions | Where-Object { -not $done.ContainsKey($_.id) })

$ourIds = @($frag.keybindings.id); $ourKeys = @($keys.keys)
$cfg.keybindings = @($cfg.keybindings | Where-Object { $_.id -notin $ourIds -and $_.keys -notin $ourKeys }) + @($keys)

$menu = if ($cfg.PSObject.Properties.Name -contains 'newTabMenu') { @($cfg.newTabMenu) } else { @([pscustomobject]@{ type = 'remainingProfiles' }) }
$rest = @($menu | Where-Object { -not ($_.type -eq 'profile' -and $_.profile -in $allGuids) })
if ($rest.Count -and $rest[0].type -eq 'separator') { $rest = @($rest | Select-Object -Skip 1) }
$top = @($menuTop | ForEach-Object { [pscustomobject][ordered]@{ profile = $_; type = 'profile' } }) + [pscustomobject]@{ type = 'separator' }
if ($cfg.PSObject.Properties.Name -contains 'newTabMenu') { $cfg.newTabMenu = @($top + $rest) }
else { $cfg | Add-Member -NotePropertyName newTabMenu -NotePropertyValue @($top + $rest) }

$json = $cfg | ConvertTo-Json -Depth 50
$null = $json | ConvertFrom-Json
if ($WhatIf) { Say "Írná: $wt"; return }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item $wt "$wt.bak-$stamp"
[IO.File]::WriteAllText($wt, $json, [Text.UTF8Encoding]::new($false))
Say "Windows Terminal bekötve (mentés: settings.json.bak-$stamp)"

& (Join-Path $dst 'claude-projekt.ps1') -CsakPaletta
Say 'Parancspaletta projekt-almenüi frissítve.'

# --- 4. asztali indító ikon ---------------------------------------------------------
# "Claude projektek": a Terminalt a projektválasztó fülével nyitja, előtte rákérdez, hogy új
# munka vagy az előző munkamenet folytatása (-Indito). -NincsIkon: kihagyja.
if (-not $NincsIkon) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-Path $desktop 'Claude projektek.lnk'
    $wtExe = (Get-Command wt.exe).Source
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($lnkPath)
    $lnk.TargetPath = $wtExe
    $lnk.Arguments = "-p $GuidProjekt pwsh.exe -NoExit -File `"$(Join-Path $dst 'claude-projekt.ps1')`" -Indito"
    $lnk.WorkingDirectory = $env:USERPROFILE
    $lnk.IconLocation = "$(Join-Path $dst 'icons\claude.ico'),0"
    $lnk.Description = 'Claude Code indítása: projektválasztó vagy az előző munkamenet folytatása'
    $lnk.Save()
    Say "Asztali ikon: $lnkPath"
}
Say 'Kész: asztali ikon „Claude projektek”, Ctrl+Shift+3 = projektválasztó, Ctrl+Shift+P → „Claude: projekt…”.'
