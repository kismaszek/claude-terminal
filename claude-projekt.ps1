# Claude Code indító projektmappa-választóval (Windows Terminal "Claude – projekt" profil).
# A Terminal-beállítást az install.ps1 köti be (README).
# A rögzített lista a gép saját claude-projektek.txt-jéből jön (repóba nem kerül; ha nincs,
# a claude-projektek.minta.txt-ből készül), alatta a legutóbb használt mappák
# a ~/.claude/projects transcriptjeinek "cwd" mezőjéből, frissesség szerint.
# Minden indításkor frissíti a Windows Terminal parancspalettáján a "Claude: …" almenüket
# (settings.json, csak ha változott).
#   -CsakPaletta              csak a paletta frissítése, menü nélkül
#   -Muvelet <m> [-Utvonal]   egyetlen listakezelő művelet (a palettáról hívva):
#                             uj | keres | rogzit | atnevez | torol | athelyez | fix
#   -Inditas <mappa> [-Mod]   Claude indítása közvetlenül a mappában (paletta, Céges/Magán
#                             profil, munkamenet-visszaállítás); -Mod: uj | folytat | korabbi
#   -Indito                   az asztali ikon belépője: előbb rákérdez, hogy új munka
#                             (projektválasztó) vagy az előző munkamenet folytatása
# Minden futó Claude-fülhöz jelzőfájlt tart (munkamenetek\, gépenkénti); az előző munkamenet
# a legutóbb egyszerre bezárt fülek (ablakbezárás, leállás) — a szabályosan kilépettek nem.
# pwsh 7-re készült.
param(
    [int]$MaxRecent = 15,
    [switch]$CsakPaletta,
    [ValidateSet('', 'uj', 'keres', 'rogzit', 'atnevez', 'torol', 'athelyez', 'fix')][string]$Muvelet = '',
    [string]$Utvonal,
    [string]$Inditas,
    [ValidateSet('uj', 'folytat', 'korabbi')][string]$Mod = 'uj',
    [ValidatePattern('^([0-9a-fA-F-]{36})?$')][string]$Session = '',   # -Mod folytat: ezt a sessiont
    [switch]$Indito
)

$ErrorActionPreference = 'Stop'
Remove-Item Env:CLAUDE_CODE_CHILD_SESSION, Env:NO_COLOR -ErrorAction Ignore

$PaletteTab    = 'Claude: projekt új fülön…'
$PalettePane   = 'Claude: projekt új ablakrészben…'
$PaletteCont   = 'Claude: projekt folytatása…'
$PaletteResume = 'Claude: projekt korábbi sessionje…'
$PaletteManage = 'Claude: projektlista kezelése…'
$PaletteOwned  = @('Claude: projekt…', 'Claude: projekt új panelen…', $PaletteTab, $PalettePane, $PaletteCont, $PaletteResume, $PaletteManage)   # a régi nevet is a sajátjának tekinti

$LaunchProfile = '{c1a0de00-0000-4c1a-8000-0000000b0a1d}'   # "Claude – projekt" profil (ikon, szín)
$TabColor = '#C15F3C'
$SessionDir = Join-Path $PSScriptRoot 'munkamenetek'
$HeartbeatSec = 20
$CloseGapSec = 90
if (-not (Test-Path $SessionDir)) { New-Item -ItemType Directory -Path $SessionDir -Force | Out-Null }

# A szkript önmagát hívja egy projekt közvetlen indításához (így minden indítás naplózódik)
function Get-LaunchCmd([string]$path, [string]$mode, [string]$session = '') {
    "pwsh.exe -NoExit -File `"$PSCommandPath`" -Inditas `"$path`" -Mod $mode$(if ($session) { " -Session $session" })"
}
$ListFile = Join-Path $PSScriptRoot 'claude-projektek.txt'
if (-not (Test-Path $ListFile) -and (Test-Path (Join-Path $PSScriptRoot 'claude-projektek.minta.txt'))) {
    Copy-Item (Join-Path $PSScriptRoot 'claude-projektek.minta.txt') $ListFile
}
$ProjRoot = Join-Path $env:USERPROFILE '.claude\projects'
$WtSettings = @(
    'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json',
    'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json',
    'Microsoft\Windows Terminal\settings.json'
) | ForEach-Object { Join-Path $env:LOCALAPPDATA $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1

# --- frissítés-ellenőrzés (a repó távoli ágához képest) -------------------------------

# Indításkor git fetch a háttérben; legfeljebb $UpdateWaitMs-ig vár rá. Ha addig nem végez
# (pl. a szerver nem érhető el), az előző fetch eredményével dolgozik, a fetch
# pedig tovább fut. Visszaadja a még be nem húzott commitok tárgysorát (üres = naprakész).
$UpdateWaitMs = 3000
$VersionFile = Join-Path $PSScriptRoot 'VERSION'
$Version = if (Test-Path $VersionFile) { (Get-Content $VersionFile -TotalCount 1).Trim() } else { '' }

# A távoli ág VERSION-je (üres, ha nincs vagy nem olvasható)
function Get-RemoteVersion {
    try { $v = git -C $PSScriptRoot show '@{u}:VERSION' 2>$null; if ($LASTEXITCODE) { '' } else { "$v".Trim() } } catch { '' }
}

function Get-RepoUpdate([int]$WaitMs = $UpdateWaitMs) {
    if (-not (Test-Path (Join-Path $PSScriptRoot '.git')) -or -not (Get-Command git -ErrorAction Ignore)) { return @() }
    try {
        # --no-write-fetch-head: a FETCH_HEAD-et a session-szinkron pull-ja használja; ha ez a
        # fetch közben felülírná, a pull "Cannot rebase onto multiple branches" hibát adna.
        $fetch = Start-Process git -ArgumentList '-C', "`"$PSScriptRoot`"", 'fetch', '-q', '--no-write-fetch-head' -WindowStyle Hidden -PassThru
        if ($WaitMs) { [void]$fetch.WaitForExit($WaitMs) }
        $enc = [Console]::OutputEncoding
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        try {
            $log = @(git -C $PSScriptRoot -c i18n.logOutputEncoding=UTF-8 log --format=%s 'HEAD..@{u}' 2>$null)
        } finally { [Console]::OutputEncoding = $enc }
        if ($LASTEXITCODE) { return @() }
        return $log
    } catch { return @() }
}

function Show-UpdateNotice($commits, [switch]$Short) {
    if (-not $commits) { return }
    Write-Host ''
    $remote = Get-RemoteVersion
    $ver = if ($remote -and $remote -ne $Version) { "v$Version → v$remote, " } else { '' }
    if ($Short) {
        Write-Host "  Frissítés érhető el a claude-terminal repóban ($ver$($commits.Count) commit). Telepítés: a projektválasztóban u." -ForegroundColor Magenta
        return
    }
    Write-Host "  Frissítés érhető el a claude-terminal repóban ($ver$($commits.Count) commit):" -ForegroundColor Magenta
    $commits | Select-Object -First 5 | ForEach-Object { Write-Host "    - $_" -ForegroundColor Magenta }
    if ($commits.Count -gt 5) { Write-Host "    … és még $($commits.Count - 5)" -ForegroundColor Magenta }
    Write-Host '  u = frissítés most (git pull + install.ps1, majd a választó újraindul)' -ForegroundColor Magenta
}

# git pull + install.ps1; $true, ha sikerült
function Invoke-RepoUpdate {
    Write-Host ''
    Write-Host '  Frissítés: git pull…' -ForegroundColor DarkGray
    git -C $PSScriptRoot pull --ff-only -q
    if ($LASTEXITCODE) {
        Write-Host ('  A git pull nem sikerült (helyi módosítás vagy eltérő commit?). Kézzel: git -C "' + $PSScriptRoot + '" status') -ForegroundColor Red
        return $false
    }
    Write-Host '  install.ps1…' -ForegroundColor DarkGray
    & (Join-Path $PSScriptRoot 'install.ps1') | Out-Host
    Write-Host '  Frissítve.' -ForegroundColor Green
    return $true
}

# --- lista ------------------------------------------------------------------------

# Van-e már Claude-session a mappában (a ~/.claude/projects kulcsa az útvonalból képződik)
function Test-HasSession([string]$path) {
    $dir = Join-Path $ProjRoot ($path -replace '[^A-Za-z0-9]', '-')
    (Test-Path -LiteralPath $dir) -and [bool](Get-ChildItem -LiteralPath $dir -Filter *.jsonl -File -ErrorAction SilentlyContinue | Select-Object -First 1)
}

# A mappa legutolsó, $before előtt (+30 mp: a session-végi hookok még írhatnak) írt sessionje:
# azonosító (Id) és név (Title): a /rename-mel vagy hookkal adott név (custom-title), ennek híján a
# Claude által generált cím (ai-title). A $before azért kell, mert ugyanabban a mappában egy
# másik, még futó fül sessionje frissebb lehet — ezért a folytatás sem --continue, hanem --resume <Id>.
function Get-ClosedSession([string]$path, [datetime]$before) {
    $dir = Join-Path $ProjRoot ($path -replace '[^A-Za-z0-9]', '-')
    if (-not (Test-Path -LiteralPath $dir)) { return $null }
    $f = Get-ChildItem -LiteralPath $dir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -le $before.AddSeconds(30) } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $f) { return $null }
    $title = $null
    $hits = @(Select-String -LiteralPath $f.FullName -Pattern '"type":"(custom-title|ai-title)"' -ErrorAction SilentlyContinue)
    foreach ($kind in 'custom-title', 'ai-title') {
        $h = $hits | Where-Object { $_.Line -like "*`"type`":`"$kind`"*" } | Select-Object -Last 1
        if ($h) {
            try { $o = $h.Line | ConvertFrom-Json } catch { continue }
            $t = if ($kind -eq 'custom-title') { $o.customTitle } else { $o.aiTitle }
            if ($t) { $title = $t.Trim(); break }
        }
    }
    [pscustomobject]@{ Id = $f.BaseName; Title = $title }
}

function Get-ProjectEntries {
    $entries = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $hidden = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $add = {
        param([string]$label, [string]$path, [string]$note, [int]$fix = 0)
        $norm = $path.TrimEnd('\')
        if ($norm -match '^[a-z]:') { $norm = $norm.Substring(0, 1).ToUpper() + $norm.Substring(1) }
        if ($note -and $hidden.Contains($norm)) { return }   # elrejtett "legutóbb használt"
        if (-not (Test-Path -LiteralPath $norm -PathType Container)) { return }
        if (-not $seen.Add($norm)) { return }
        $entries.Add([pscustomobject]@{ Label = $label; Path = $norm; Note = $note; Fix = $fix })
    }

    # 1) Rögzített projektek ("! útvonal" sor = elrejtett legutóbb használt mappa,
    #    "[3] Név | Útvonal" = fix sorszámú tétel)
    $lines = if (Test-Path $ListFile) { [IO.File]::ReadAllLines($ListFile, [Text.Encoding]::UTF8) } else { @() }
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t.StartsWith('!')) { [void]$hidden.Add($t.Substring(1).Trim().TrimEnd('\')) }
    }
    foreach ($line in $lines) {
        $p = ConvertFrom-PinLine $line
        if ($p) { & $add $p.Label $p.Path '' $p.Fix }
    }

    # 2) Legutóbb használt mappák a Claude-transcriptekből
    $recent = foreach ($dir in Get-ChildItem $ProjRoot -Directory -ErrorAction SilentlyContinue) {
        $f = Get-ChildItem $dir.FullName -Filter *.jsonl -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $f) { continue }
        $m = Get-Content -LiteralPath $f.FullName -TotalCount 50 -Encoding utf8 |
            Select-String '"cwd":"((?:[^"\\]|\\.)*)"' | Select-Object -First 1
        if (-not $m) { continue }
        $cwd = ('"' + $m.Matches[0].Groups[1].Value + '"') | ConvertFrom-Json
        [pscustomobject]@{ Path = $cwd; Time = $f.LastWriteTime }
    }
    foreach ($r in $recent | Sort-Object Time -Descending | Select-Object -First $MaxRecent) {
        & $add (Split-Path $r.Path -Leaf) $r.Path $r.Time.ToString('yyyy-MM-dd')
    }

    # Egyforma nevek (pl. két "app" nevű mappa más-más szülőben): a legutóbb használt tételek
    # neve mellé a szülőmappa kerül; a paletta-almenüben az egyforma név el is veszne.
    # A rögzített tételek nevét a felhasználó adta, azokhoz nem nyúl.
    foreach ($round in 1..3) {
        $dups = @($entries | Group-Object { $_.Label.ToLower() } | Where-Object Count -gt 1)
        if (-not $dups) { break }
        foreach ($g in $dups) {
            foreach ($e in $g.Group | Where-Object Note) {
                $parts = $e.Path.TrimEnd('\') -split '\\'
                $up = if ($parts.Count -gt $round) { $parts[$parts.Count - 1 - $round] } else { $null }
                $e.Label = if ($up -and $up -notmatch ':$') { "$(Split-Path $e.Path -Leaf) ($up)" } else { $e.Path }
            }
        }
    }
    $n = 1
    foreach ($g in @($entries | Group-Object { $_.Label.ToLower() } | Where-Object Count -gt 1)) {
        foreach ($e in $g.Group | Select-Object -Skip 1) { $n++; $e.Label = "$($e.Label) #$n" }
    }

    # Elrendezés: a fix tételek a saját sorszámukon, a többi (rögzített, majd legutóbb
    # használt) a maradék helyeket tölti ki. Ha egy fix sorszám nagyobb a lista hosszánál,
    # vagy kettő ütközik, a tétel a legközelebbi szabad helyre kerül a végén.
    $fixedQ = [System.Collections.Generic.Queue[object]]::new([object[]]@($entries | Where-Object Fix | Sort-Object Fix -Stable))
    $flowQ  = [System.Collections.Generic.Queue[object]]::new([object[]]@($entries | Where-Object { -not $_.Fix }))
    $result = [System.Collections.Generic.List[object]]::new()
    while ($fixedQ.Count -or $flowQ.Count) {
        $pos = $result.Count + 1
        if ($fixedQ.Count -and ($fixedQ.Peek().Fix -le $pos -or -not $flowQ.Count)) { $result.Add($fixedQ.Dequeue()) }
        else { $result.Add($flowQ.Dequeue()) }
    }
    return , $result
}

# --- a claude-projektek.txt írása -----------------------------------------------------

function Read-ListText { if (Test-Path $ListFile) { [IO.File]::ReadAllText($ListFile, [Text.Encoding]::UTF8) } else { '' } }
function Get-LineEnding([string]$text) { if ($text -match "`r`n") { "`r`n" } else { "`n" } }
function Add-ListLine([string]$line) {
    $existing = Read-ListText
    $nl = Get-LineEnding $existing
    $prefix = if ($existing -and -not $existing.EndsWith("`n")) { $nl } else { '' }
    [IO.File]::AppendAllText($ListFile, "$prefix$line$nl", [Text.UTF8Encoding]::new($false))
}
# Rögzített sor felbontása: "[3] Név | Útvonal", "Név | Útvonal" vagy csak "Útvonal".
# Megjegyzés, üres és "!" sornál $null.
function ConvertFrom-PinLine([string]$line) {
    $t = $line.Trim()
    if (-not $t -or $t.StartsWith('#') -or $t.StartsWith('!')) { return $null }
    $fix = 0
    if ($t -match '^\[(\d+)\]\s*(.*)$') { $fix = [int]$Matches[1]; $t = $Matches[2].Trim() }
    $parts = $t -split '\|', 2
    if ($parts.Count -eq 2) { $label = $parts[0].Trim(); $path = $parts[1].Trim() }
    else { $path = $t; $label = Split-Path $t.TrimEnd('\') -Leaf }
    [pscustomobject]@{ Fix = $fix; Label = $label; Path = $path.TrimEnd('\') }
}
function Format-PinLine([string]$label, [string]$path, [int]$fix) {
    $(if ($fix) { "[$fix] " } else { '' }) + "$label | $path"
}
# Egy rögzített sor útvonala; más sornál $null
function Get-LinePath([string]$line) { (ConvertFrom-PinLine $line).Path }

# Névelő a sorszám elé: "az 1.", "az 5.", "a 3."
function Get-Nevelo([int]$n) { if ("$n" -match '^(1|5|5\d|1\d\d\d)$') { 'az' } else { 'a' } }

# A mappához tartozó sor(ok) törlése (rögzített és/vagy "!" rejtő sor); a törölt sorok számát adja
function Remove-ProjectLines([string]$path, [switch]$OnlyHidden) {
    $text = Read-ListText
    if (-not $text) { return 0 }
    $want = $path.TrimEnd('\'); $removed = 0
    $keep = foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        $p = if ($t.StartsWith('!')) { $t.Substring(1).Trim().TrimEnd('\') } elseif (-not $OnlyHidden) { Get-LinePath $line }
        if ($p -and $p -ieq $want) { $removed++ } else { $line }
    }
    if ($removed) { [IO.File]::WriteAllText($ListFile, ($keep -join (Get-LineEnding $text)), [Text.UTF8Encoding]::new($false)) }
    return $removed
}

function Add-PinnedProject([string]$path, [string]$label, [int]$Fix = 0) {
    foreach ($line in (Read-ListText) -split "`r?`n") {
        if ((Get-LinePath $line) -ieq $path.TrimEnd('\')) { Write-Host '  Ez a mappa már rögzítve van.' -ForegroundColor DarkYellow; return }
    }
    [void](Remove-ProjectLines $path -OnlyHidden)   # ha el volt rejtve, a rejtés megszűnik
    $line = Format-PinLine $label $path $Fix
    Add-ListLine $line
    Write-Host "  Rögzítve: $line" -ForegroundColor Green
}

# A mappa rögzített sorának átírása; $change a felbontott sort kapja és módosítja
function Edit-PinLine([string]$path, [scriptblock]$change) {
    $text = Read-ListText
    $lines = foreach ($line in ($text -split "`r?`n")) {
        $p = ConvertFrom-PinLine $line
        if ($p -and $p.Path -ieq $path.TrimEnd('\')) { & $change $p; Format-PinLine $p.Label $p.Path $p.Fix } else { $line }
    }
    [IO.File]::WriteAllText($ListFile, ($lines -join (Get-LineEnding $text)), [Text.UTF8Encoding]::new($false))
}

function Rename-PinnedProject([string]$path, [string]$label) {
    Edit-PinLine $path ({ param($p) $p.Label = $label }.GetNewClosure())
    Write-Host "  Átnevezve: $label | $path" -ForegroundColor Green
}

function Set-PinFix([string]$path, [int]$fix) { Edit-PinLine $path ({ param($p) $p.Fix = $fix }.GetNewClosure()) }

# A mappa rögzített sorát a $beforePath sora elé teszi; $beforePath nélkül az utolsó
# rögzített sor után. A megjegyzés- és "!" sorok a helyükön maradnak.
function Move-PinLine([string]$path, [string]$beforePath) {
    $text = Read-ListText
    $lines = [System.Collections.Generic.List[string]]::new([string[]]($text -split "`r?`n"))
    $find = { param([string]$want) for ($j = 0; $j -lt $lines.Count; $j++) { $p = ConvertFrom-PinLine $lines[$j]; if ($p -and $p.Path -ieq $want.TrimEnd('\')) { return $j } }; -1 }
    $i = & $find $path
    if ($i -lt 0) { return }
    $moved = $lines[$i]; $lines.RemoveAt($i)
    $at = -1
    if ($beforePath) { $at = & $find $beforePath }
    else { for ($j = 0; $j -lt $lines.Count; $j++) { if (ConvertFrom-PinLine $lines[$j]) { $at = $j + 1 } } }
    if ($at -lt 0) { $at = $i }
    $lines.Insert($at, $moved)
    [IO.File]::WriteAllText($ListFile, ($lines -join (Get-LineEnding $text)), [Text.UTF8Encoding]::new($false))
}

# --- listakezelő műveletek (a menüből és a palettáról is) ------------------------------

function Read-Label([string]$prompt, [string]$default) {
    $l = (Read-Host "  $prompt (Enter = $default)").Trim()
    if (-not $l) { $l = $default }
    $l.Replace('|', '-')
}

function Invoke-NewPin([string]$rest) {
    if (-not $rest) { $rest = (Read-Host '  Mappa útvonala').Trim().Trim('"') }
    if (-not $rest) { return }
    if (-not (Test-Path -LiteralPath $rest -PathType Container)) { Write-Host '  Nincs ilyen mappa.' -ForegroundColor Red; return }
    $path = (Resolve-Path -LiteralPath $rest).Path.TrimEnd('\')
    if ((Get-ProjectEntries) | Where-Object { -not $_.Note -and $_.Path -ieq $path }) { Write-Host '  Ez a mappa már rögzítve van.' -ForegroundColor DarkYellow; return }
    Add-PinnedProject $path (Read-Label 'Név' (Split-Path $path -Leaf))
}

# Mappakeresés a helyi fix meghajtókon és a felhasználói mappában, korlátozott mélységig.
# $term megadva: a mappanévben keres (kis/nagybetű és ékezet nem számít, "gyogy" = "Gyógy").
# $term üres: projektmappákat keres (.git, CLAUDE.md vagy .claude van benne), amelyek még
# nincsenek a listán; a projektmappán belülre ilyenkor nem megy le.
$SearchMaxDepth = 4
$SearchSeconds  = 15
$SearchSkip = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
    'Windows', 'Windows.old', 'Program Files', 'Program Files (x86)', 'ProgramData', 'WindowsApps',
    '$Recycle.Bin', 'System Volume Information', 'Recovery', 'PerfLogs', 'MSOCache', 'Config.Msi',
    'AppData', 'OneDriveTemp', 'node_modules', 'bin', 'obj', 'build', 'dist', 'Debug', 'Release',
    'packages', 'target', '.git', '.vs', '.vscode', '.idea', '__pycache__', 'venv', '.venv', '.claude'
), [StringComparer]::OrdinalIgnoreCase)

function Find-ProjectFolders([string]$term, $known) {
    $cmp  = [Globalization.CultureInfo]::InvariantCulture.CompareInfo
    $copt = [Globalization.CompareOptions]'IgnoreCase, IgnoreNonSpace'
    $eo = [IO.EnumerationOptions]::new()
    $eo.IgnoreInaccessible = $true
    $eo.AttributesToSkip = [IO.FileAttributes]'Hidden, System, ReparsePoint'
    $knownSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($known | ForEach-Object Path), [StringComparer]::OrdinalIgnoreCase)
    $visited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[object]]::new()
    $roots = @($env:USERPROFILE) + @([IO.DriveInfo]::GetDrives() |
        Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.RootDirectory.FullName })
    foreach ($r in $roots) { if ($visited.Add($r.TrimEnd('\'))) { $queue.Enqueue(@($r, 0)) } }

    $hits = [System.Collections.Generic.List[object]]::new()
    $sw = [Diagnostics.Stopwatch]::StartNew(); $partial = $false
    while ($queue.Count) {
        if ($sw.Elapsed.TotalSeconds -gt $SearchSeconds -or $hits.Count -ge 200) { $partial = $true; break }
        $dir, $depth = $queue.Dequeue()
        try {
            foreach ($c in [IO.Directory]::EnumerateDirectories($dir, '*', $eo)) {
                $name = [IO.Path]::GetFileName($c)
                if ($SearchSkip.Contains($name) -or -not $visited.Add($c)) { continue }
                $git = [IO.Directory]::Exists("$c\.git") -or [IO.File]::Exists("$c\.git")
                $cl  = [IO.File]::Exists("$c\CLAUDE.md") -or [IO.Directory]::Exists("$c\.claude")
                $isProj = ($git -or $cl) -and $c -ine $env:USERPROFILE
                $match = if ($term) { $cmp.IndexOf($name, $term, $copt) -ge 0 } else { $isProj -and -not $knownSet.Contains($c) }
                if ($match) {
                    $tags = @(); if ($git) { $tags += 'git' }; if ($cl) { $tags += 'Claude' }
                    if ($knownSet.Contains($c)) { $tags += 'listán' }
                    $hits.Add([pscustomobject]@{ Name = $name; Path = $c; Proj = $isProj; Depth = $depth + 1; Tags = $tags -join ', ' })
                }
                if ($depth + 1 -lt $SearchMaxDepth -and -not (-not $term -and $isProj)) { $queue.Enqueue(@($c, ($depth + 1))) }
            }
        } catch { }
    }
    [pscustomobject]@{
        Hits = @($hits | Sort-Object @{ e = 'Proj'; Descending = $true }, Depth, Path)
        Partial = $partial
    }
}

# Keresés párbeszéddel; a választott, indítandó mappát adja vissza ($null = vissza a menübe)
function Invoke-Search($entries, $term) {   # $term = $null: rákérdez
    if ($null -eq $term) {
        $term = (Read-Host '  Keresett mappanév (Enter = új projektmappák, amelyek még nincsenek a listán)').Trim()
    }
    Write-Host ''
    Write-Host ($(if ($term) { '  Keresés: „' + $term + '”…' } else { '  Projektmappák keresése…' })) -ForegroundColor DarkGray
    $res = Find-ProjectFolders $term $entries
    $hits = @($res.Hits | Select-Object -First 30)
    if (-not $hits) {
        Write-Host '  Nincs találat.' -ForegroundColor DarkYellow
        if ($res.Partial) { Write-Host "  (A keresés $SearchSeconds mp után leállt; a mappa útvonala közvetlenül is beírható.)" -ForegroundColor DarkGray }
        return $null
    }
    Write-Host ''
    for ($i = 0; $i -lt $hits.Count; $i++) {
        $h = $hits[$i]
        Write-Host ('  {0,2}) ' -f ($i + 1)) -NoNewline -ForegroundColor Yellow
        Write-Host "$($h.Name)  " -NoNewline
        Write-Host $h.Path -NoNewline -ForegroundColor DarkGray
        if ($h.Tags) { Write-Host "  ($($h.Tags))" -ForegroundColor DarkCyan } else { Write-Host '' }
    }
    if ($res.Hits.Count -gt $hits.Count) { Write-Host "  … és még $($res.Hits.Count - $hits.Count) találat; pontosabb névvel szűkíthető." -ForegroundColor DarkGray }
    if ($res.Partial) { Write-Host "  (A keresés $SearchSeconds mp után leállt, a lista hiányos lehet.)" -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host '  Szám = Claude indítása ott, +<szám> = rögzítés a listára, Enter = vissza' -ForegroundColor DarkGray
    while ($true) {
        $a = (Read-Host '  Találat').Trim()
        if (-not $a) { return $null }
        $n = 0
        if ($a -match '^\+\s*(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -lt 1 -or $n -gt $hits.Count) { Write-Host '  Nincs ilyen sorszám.' -ForegroundColor Red; continue }
            Add-PinnedProject $hits[$n - 1].Path (Read-Label 'Név' $hits[$n - 1].Name)
            continue
        }
        if ([int]::TryParse($a, [ref]$n) -and $n -ge 1 -and $n -le $hits.Count) { return $hits[$n - 1].Path }
        Write-Host '  Érvénytelen választás.' -ForegroundColor Red
    }
}

function Invoke-Pin($e) {
    if (-not $e.Note) { Write-Host '  Ez a mappa már rögzítve van.' -ForegroundColor DarkYellow; return }
    Add-PinnedProject $e.Path (Read-Label 'Név' $e.Label)
}

# Fix sorszám be/ki. Bekapcsolva a tétel a mostani helyén ($pos) marad; legutóbb
# használt tétel ehhez rögzítve is lesz.
function Invoke-Fix($e, [int]$pos) {
    if ($e.Fix) {
        Set-PinFix $e.Path 0
        Write-Host "  Fix sorszám levéve: $($e.Label). Rögzített marad, a többi rögzítettel együtt mozog." -ForegroundColor Green
        return
    }
    $other = (Get-ProjectEntries) | Where-Object { $_.Fix -eq $pos -and $_.Path -ine $e.Path } | Select-Object -First 1
    if ($other) { Write-Host "  Ezen a helyen ($pos.) már $($other.Label) áll fixen." -ForegroundColor DarkYellow; return }
    if ($e.Note) { Add-PinnedProject $e.Path (Read-Label 'Név' $e.Label) -Fix $pos }
    else { Set-PinFix $e.Path $pos }
    Write-Host "  Fixálva: $($e.Label) mindig $(Get-Nevelo $pos) $pos. helyen marad." -ForegroundColor Green
}

# Áthelyezés a $to. helyre. Fix tételnél a fix sorszám változik (ha ott másik fix tétel
# áll, helyet cserélnek); nem fix tételnél a rögzítettek sorrendje. A legutóbb használtak
# közé nem lehet tenni: ott a használat ideje dönt, ilyenkor a rögzítettek végére kerül.
function Invoke-Move([int]$from, [int]$to) {
    $list = Get-ProjectEntries
    if ($from -lt 1 -or $from -gt $list.Count) { Write-Host '  Nincs ilyen sorszám.' -ForegroundColor Red; return }
    $to = [Math]::Max(1, [Math]::Min($to, $list.Count))
    $e = $list[$from - 1]
    if ($from -eq $to -and -not $e.Note) { Write-Host '  A tétel már ott van.' -ForegroundColor DarkGray; return }

    if ($e.Fix) {
        $other = $list | Where-Object { $_.Fix -eq $to -and $_.Path -ine $e.Path } | Select-Object -First 1
        if ($other) { Set-PinFix $other.Path $e.Fix }
        Set-PinFix $e.Path $to
        Write-Host "  Áthelyezve: $($e.Label) → $to. hely (fix)" -ForegroundColor Green
        if ($other) { Write-Host "  Csere: $($other.Label) $(Get-Nevelo $e.Fix) $($e.Fix). helyre került (fix)." -ForegroundColor Green }
        return
    }
    $occupant = $list[$to - 1]
    if ($occupant.Fix) {
        Write-Host "  A célhely ($to.) $($occupant.Label) fix helye. Előbb arról vedd le a fixálást (f$to), vagy helyezd át azt." -ForegroundColor DarkYellow
        return
    }
    if ($e.Note) { Add-PinnedProject $e.Path (Read-Label 'Név' $e.Label) }

    # Hányadik nem fix tétel lesz a cél helyen (a fix helyek kimaradnak a számolásból)
    $fixedBefore = @($list | Select-Object -First ($to - 1) | Where-Object Fix).Count
    $k = $to - 1 - $fixedBefore
    $pinnedOthers = @($list | Where-Object { -not $_.Fix -and -not $_.Note -and $_.Path -ine $e.Path })
    Move-PinLine $e.Path $(if ($k -lt $pinnedOthers.Count) { $pinnedOthers[$k].Path } else { $null })

    $new = Get-ProjectEntries
    $pos = 0; for ($j = 0; $j -lt $new.Count; $j++) { if ($new[$j].Path -ieq $e.Path) { $pos = $j + 1; break } }
    Write-Host "  Áthelyezve: $($e.Label) → $pos. hely" -ForegroundColor Green
    if ($pos -ne $to) { Write-Host '  (A legutóbb használtak közé nem tehető, ezért a rögzítettek végére került.)' -ForegroundColor DarkGray }
}

function Invoke-Rename($e) {
    $label = Read-Label "Új név ($($e.Path))" $e.Label
    if ($label -ceq $e.Label -and -not $e.Note) { Write-Host '  A név nem változott.' -ForegroundColor DarkGray; return }
    if ($e.Note) {
        # Legutóbb használt tétel nevét csak rögzítve lehet megtartani
        Add-PinnedProject $e.Path $label
        Write-Host '  (A legutóbb használt tétel az új névvel a rögzítettek közé került.)' -ForegroundColor DarkGray
    } else {
        Rename-PinnedProject $e.Path $label
    }
}

function Invoke-Delete($e) {
    $what = if ($e.Note) { 'Elrejtsem a legutóbb használtak közül' } else { 'Kivegyem a rögzítettek közül' }
    if ((Read-Host "  $what`: $($e.Label) ($($e.Path))? (i/n)").Trim() -notmatch '^[iIyY]') { return }
    if ($e.Note) {
        Add-ListLine "! $($e.Path)"
        Write-Host '  Elrejtve. (Visszahozás: +<útvonal>, vagy a "!" sor törlése a claude-projektek.txt-ből.)' -ForegroundColor Green
    } else {
        [void](Remove-ProjectLines $e.Path)
        Write-Host '  Kivéve a rögzítettek közül.' -ForegroundColor Green
        if ((Get-ProjectEntries) | Where-Object { $_.Path -ieq $e.Path }) {
            Write-Host '  A mappa a legutóbb használtak között továbbra is látszik; onnan is törölhető.' -ForegroundColor DarkYellow
        }
    }
}

# --- parancspaletta ------------------------------------------------------------------

function Update-WtPalette($entries) {
    if (-not $WtSettings) { return }
    $cfg = [IO.File]::ReadAllText($WtSettings, [Text.Encoding]::UTF8) | ConvertFrom-Json

    # Claude indítása a projekt mappájában
    $launch = {
        param($e, [string]$action, [string]$mode)
        $cmd = [ordered]@{ action = $action }
        if ($action -eq 'splitPane') { $cmd.split = 'auto' }
        $cmd.profile = $LaunchProfile
        $cmd.commandline = Get-LaunchCmd $e.Path $mode
        $cmd.startingDirectory = $e.Path
        $cmd.tabTitle = $e.Label
        $cmd.tabColor = $TabColor
        [ordered]@{ name = $e.Label; command = $cmd }
    }
    # Listakezelő művelet egy rövid életű fülön (a szkript lefut, majd a fül bezárul)
    $manage = {
        param([string]$name, [string]$op, [string]$path)
        $cl = "pwsh.exe -NoProfile -File `"$PSCommandPath`" -Muvelet $op"
        if ($path) { $cl += " -Utvonal `"$path`"" }
        [ordered]@{ name = $name; command = [ordered]@{
            action = 'newTab'; profile = $LaunchProfile; commandline = $cl
            tabTitle = 'Claude – projektlista'; tabColor = $TabColor } }
    }
    $withSession = @($entries | Where-Object { Test-HasSession $_.Path })
    $recentOnly = @($entries | Where-Object Note)

    $menus = @(
        [pscustomobject][ordered]@{ name = $PaletteTab; commands = @($entries | ForEach-Object { & $launch $_ 'newTab' 'uj' }) }
        [pscustomobject][ordered]@{ name = $PalettePane; commands = @($entries | ForEach-Object { & $launch $_ 'splitPane' 'uj' }) }
    )
    if ($withSession) {
        $menus += [pscustomobject][ordered]@{ name = $PaletteCont; commands = @($withSession | ForEach-Object { & $launch $_ 'newTab' 'folytat' }) }
        $menus += [pscustomobject][ordered]@{ name = $PaletteResume; commands = @($withSession | ForEach-Object { & $launch $_ 'newTab' 'korabbi' }) }
    }
    $sub = @((& $manage 'Projektmappa keresése…' 'keres' ''), (& $manage 'Új mappa rögzítése…' 'uj' ''))
    if ($recentOnly) { $sub += [ordered]@{ name = 'Rögzítés…'; commands = @($recentOnly | ForEach-Object { & $manage $_.Label 'rogzit' $_.Path }) } }
    if ($entries.Count) {
        $sub += [ordered]@{ name = 'Átnevezés…'; commands = @($entries | ForEach-Object { & $manage $_.Label 'atnevez' $_.Path }) }
        $sub += [ordered]@{ name = 'Áthelyezés…'; commands = @($entries | ForEach-Object { & $manage $_.Label 'athelyez' $_.Path }) }
        $sub += [ordered]@{ name = 'Fix sorszám be/ki…'; commands = @($entries | ForEach-Object {
            & $manage "$($_.Label)$(if ($_.Fix) { ' (fix)' })" 'fix' $_.Path }) }
        $sub += [ordered]@{ name = 'Törlés / elrejtés…'; commands = @($entries | ForEach-Object { & $manage $_.Label 'torol' $_.Path }) }
    }
    $menus += [pscustomobject][ordered]@{ name = $PaletteManage; commands = $sub }

    $others = @($cfg.actions | Where-Object { $_.name -notin $PaletteOwned })
    $old = @($cfg.actions | Where-Object { $_.name -in $PaletteOwned })
    if ((ConvertTo-Json @($old) -Depth 20 -Compress) -eq (ConvertTo-Json @($menus) -Depth 20 -Compress)) { return }

    $cfg.actions = @($others) + $menus
    $json = $cfg | ConvertTo-Json -Depth 50
    $null = $json | ConvertFrom-Json   # érvényesség-ellenőrzés írás előtt
    $bak = "$WtSettings.bak-paletta"
    if (-not (Test-Path $bak)) { Copy-Item $WtSettings $bak }
    [IO.File]::WriteAllText($WtSettings, $json, [Text.UTF8Encoding]::new($false))
}

function Update-PaletteQuiet($entries) {
    try { Update-WtPalette $entries }
    catch { Write-Host "  (A parancspaletta frissítése nem sikerült: $($_.Exception.Message))" -ForegroundColor DarkYellow }
}

# --- munkamenet-napló és Claude-indítás ------------------------------------------------

# Minden futó Claude-fülnek van egy jelzőfájlja ($SessionDir\<pid>-<ticks>, tartalma a mappa).
# Egy .NET-időzítő $HeartbeatSec másodpercenként frissíti a módosítási idejét, amíg a fül él;
# szabályos kilépéskor (a claude visszatér) a fájl törlődik. Ha a fület/ablakot bezárják vagy a
# gép leáll, a fájl megmarad, és a módosítási ideje ≈ a bezárás ideje.
function Start-SessionMarker([string]$path) {
    try {
        if (-not ('ClaudeTerminalHeartbeat2' -as [type])) {
            $dll = Join-Path $SessionDir 'heartbeat2.dll'
            if (-not (Test-Path $dll)) {
                # Egyszerre több fül is fordíthat (visszaállítás): egyedi fájlba, majd átnevezés
                $tmp = Join-Path $SessionDir "heartbeat2.$PID.dll"
                # Bezáráskor (CTRL_CLOSE / kijelentkezés / leállás) a Windows még pár másodpercig
                # életben hagyja a folyamatot; ha közben indul az új ablak, a pid még él. Ezért a
                # fül a bezárás pillanatában maga jelöli meg a jelzőjét (-z utótag).
                Add-Type -OutputAssembly $tmp -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
public static class ClaudeTerminalHeartbeat2 {
    delegate bool CtrlHandler(int ev);
    [DllImport("kernel32.dll")] static extern bool SetConsoleCtrlHandler(CtrlHandler h, bool add);
    static Timer timer;
    static CtrlHandler handler;
    static string marker;
    public static void Start(string file, int ms) {
        marker = file;
        timer = new Timer(_ => { try { if (File.Exists(marker)) File.SetLastWriteTimeUtc(marker, DateTime.UtcNow); } catch { } }, null, ms, ms);
        handler = OnCtrl;
        SetConsoleCtrlHandler(handler, true);
    }
    static bool OnCtrl(int ev) {
        if (ev == 2 || ev == 5 || ev == 6) {
            try {
                timer.Dispose();
                if (File.Exists(marker)) { File.SetLastWriteTimeUtc(marker, DateTime.UtcNow); File.Move(marker, marker + "-z"); }
            } catch { }
        }
        return false;
    }
}
'@
                try { Move-Item -LiteralPath $tmp -Destination $dll -ErrorAction Stop } catch { }
                if (-not (Test-Path $dll)) { $dll = $tmp } else { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
            }
            Add-Type -Path $dll
        }
        $file = Join-Path $SessionDir "$PID-$([datetime]::UtcNow.Ticks)"
        [IO.File]::WriteAllText($file, $path, [Text.UTF8Encoding]::new($false))
        [ClaudeTerminalHeartbeat2]::Start($file, $HeartbeatSec * 1000)
        return $file
    } catch { return $null }
}

# A bezárt (nem szabályosan kilépett) fülek jelzőfájljai. Él a fül, ha nem jelölte magát
# bezártnak (-z), a pid él, és a folyamat a jelzőfájl előtt indult (különben a pid-et azóta más
# kapta meg).
function Get-SessionMarkers {
    if (-not (Test-Path $SessionDir)) { return @() }
    @(Get-ChildItem -LiteralPath $SessionDir -File | Where-Object Name -match '^(\d+)-\d+(-z)?$' | ForEach-Object {
        $procId = [int]($_.Name -split '-')[0]
        $proc = if ($_.Name -notlike '*-z') { Get-Process -Id $procId -ErrorAction SilentlyContinue }
        $alive = $proc -and $proc.StartTime -le $_.CreationTime.AddSeconds(5)
        try { $p = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8).Trim() } catch { $p = '' }
        [pscustomobject]@{ File = $_.FullName; Path = $p; First = $_.CreationTime; Last = $_.LastWriteTime; Alive = [bool]$alive }
    })
}

# Az előző munkamenet: a legutóbb bezárt fülek, amelyek egyszerre (egymástól $CloseGapSec
# másodpercen belül) szűntek meg — tipikusan egy ablak bezárása vagy a gép leállása. A régebben,
# külön bezárt fülek jelzőit eldobja. A még futó fülek nem kerülnek bele.
function Get-PreviousSession {
    $dead = @(Get-SessionMarkers | Where-Object { -not $_.Alive } | Sort-Object Last -Descending)
    if (-not $dead) { return @() }
    $newest = $dead[0].Last
    $cluster = @($dead | Where-Object { ($newest - $_.Last).TotalSeconds -le $CloseGapSec })
    $dead | Where-Object { $cluster -notcontains $_ } | ForEach-Object { Remove-Item -LiteralPath $_.File -ErrorAction SilentlyContinue }
    @($cluster | Where-Object { $_.Path -and (Test-Path -LiteralPath $_.Path -PathType Container) } |
        Group-Object { $_.Path.ToLower() } | ForEach-Object {
            $g = @($_.Group | Sort-Object First)
            [pscustomobject]@{ Path = $g[0].Path; First = $g[0].First; Last = ($g | Sort-Object Last | Select-Object -Last 1).Last; Files = @($g.File) }
        } | Sort-Object First)
}

function Start-ClaudeIn([string]$path, [string]$mode, [string]$label, [string]$session = '') {
    $dir = Join-Path $ProjRoot ($path -replace '[^A-Za-z0-9]', '-')
    if ($session -and -not (Test-Path -LiteralPath (Join-Path $dir "$session.jsonl"))) { $session = '' }
    if ($mode -ne 'uj' -and -not (Test-HasSession $path)) {
        Write-Host '  Ebben a mappában még nem futott Claude-session, új indul.' -ForegroundColor DarkYellow
        $mode = 'uj'
    }
    $marker = Start-SessionMarker $path
    Set-Location -LiteralPath $path
    if ($label) { $Host.UI.RawUI.WindowTitle = $label }
    Write-Host ''
    try {
        switch ($mode) {
            'folytat' {
                if ($session) { Write-Host "  Claude folytatja a bezárt sessiont: $path" -ForegroundColor Green; claude --resume $session --permission-mode auto }
                else { Write-Host "  Claude folytatja az utolsó sessiont: $path" -ForegroundColor Green; claude --continue --permission-mode auto }
            }
            'korabbi' { Write-Host "  Claude: korábbi session választása: $path" -ForegroundColor Green; claude --resume --permission-mode auto }
            default   { Write-Host "  Claude indul: $path" -ForegroundColor Green; claude --permission-mode auto }
        }
    } finally {
        # Szabályos kilépés (vagy Ctrl+C a PowerShellben): nem bezárás, nem kell visszaállítani
        if ($marker) { Remove-Item -LiteralPath $marker -ErrorAction SilentlyContinue }
    }
}

# Közvetlen indítás (paletta, Céges/Magán profil, visszaállított fül): menü és listaolvasás nélkül
if ($Inditas) {
    if (-not (Test-Path -LiteralPath $Inditas -PathType Container)) { Write-Host "  Nincs ilyen mappa: $Inditas" -ForegroundColor Red; return }
    Show-UpdateNotice (Get-RepoUpdate 0) -Short   # nem vár: az előző fetch eredménye, a mostani a háttérben fut
    Start-ClaudeIn (Resolve-Path -LiteralPath $Inditas).Path.TrimEnd('\') $Mod '' $Session
    return
}

$entries = Get-ProjectEntries
Update-PaletteQuiet $entries
if ($CsakPaletta) { return }
$Updates = if ($Muvelet) { @() } else { @(Get-RepoUpdate) }

# --- előválasztó (asztali ikon) ------------------------------------------------------
if ($Indito) {
    $prev = @(Get-PreviousSession)
    if ($prev.Count) {
        $labelOf = { param($p) $m = $entries | Where-Object { $_.Path -ieq $p } | Select-Object -First 1; if ($m) { $m.Label } else { Split-Path $p -Leaf } }
        $Host.UI.RawUI.WindowTitle = 'Claude – indítás'
        Write-Host ''
        Write-Host '  Claude – indítás' -ForegroundColor Cyan -NoNewline
        Write-Host $(if ($Version) { "  v$Version" }) -ForegroundColor DarkGray
        Show-UpdateNotice $Updates
        Write-Host ''
        Write-Host '   1) ' -NoNewline -ForegroundColor Yellow; Write-Host 'Új munka: projektválasztó'
        $closed = ($prev | Sort-Object Last | Select-Object -Last 1).Last.ToString('yyyy-MM-dd HH:mm')
        Write-Host '   2) ' -NoNewline -ForegroundColor Yellow; Write-Host "Előző munkamenet folytatása (bezárva $closed, $($prev.Count) projekt):"
        for ($i = 0; $i -lt $prev.Count; $i++) {
            # A bezárt session: ezt folytatjuk (--resume <Id>), és a neve többet mond az előzményről,
            # mint az útvonal; név híján marad az útvonal
            $cs = Get-ClosedSession $prev[$i].Path $prev[$i].Last
            $prev[$i] | Add-Member -NotePropertyName Session -NotePropertyValue $(if ($cs) { $cs.Id } else { '' }) -Force
            Write-Host ('        {0}. {1}' -f ($i + 1), (& $labelOf $prev[$i].Path)) -NoNewline
            Write-Host "  $(if ($cs.Title) { $cs.Title } else { $prev[$i].Path })" -ForegroundColor DarkGray
        }
        Write-Host ''
        $a = (Read-Host '  Választás (Enter = 1)').Trim()
        if ($a -eq 'u' -and $Updates -and (Invoke-RepoUpdate)) { & $PSCommandPath @PSBoundParameters; return }
        if ($a -eq '2') {
            $sel = (Read-Host '  Melyiket folytassam? (Enter = mind, vagy sorszámok, pl. 1,3)').Trim()
            $pick = if (-not $sel) { $prev } else {
                @($sel -split '[,; ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } |
                  Where-Object { $_ -ge 1 -and $_ -le $prev.Count } | Select-Object -Unique | ForEach-Object { $prev[$_ - 1] })
            }
            if ($pick.Count) {
                # A visszaállított fülek új jelzőt kapnak; a régieket (a ki nem választottakét is) eldobjuk
                $prev | ForEach-Object { $_.Files } | ForEach-Object { Remove-Item -LiteralPath $_ -ErrorAction SilentlyContinue }
                # Az első projekt ebben a fülben, a többi új fülön ugyanebben az ablakban
                foreach ($p in $pick | Select-Object -Skip 1) {
                    $lbl = & $labelOf $p.Path
                    $wtArgs = "-w 0 nt -p $LaunchProfile --title `"$lbl`" -d `"$($p.Path)`" $(Get-LaunchCmd $p.Path 'folytat' $p.Session)"
                    Start-Process wt.exe -ArgumentList $wtArgs
                    Start-Sleep -Milliseconds 300
                }
                Start-ClaudeIn $pick[0].Path 'folytat' (& $labelOf $pick[0].Path) $pick[0].Session
                return
            }
        }
    }
}

# --- egyetlen művelet a palettáról ---------------------------------------------------
if ($Muvelet) {
    $Host.UI.RawUI.WindowTitle = 'Claude – projektlista'
    Write-Host ''
    if ($Muvelet -eq 'uj') { Invoke-NewPin '' }
    elseif ($Muvelet -eq 'keres') {
        $p = Invoke-Search $entries $null
        if ($p) { Update-PaletteQuiet (Get-ProjectEntries); Start-ClaudeIn $p 'uj' (Split-Path $p -Leaf); return }
    }
    else {
        $pos = 0
        for ($j = 0; $j -lt $entries.Count; $j++) { if ($entries[$j].Path -ieq $Utvonal.TrimEnd('\')) { $pos = $j + 1; break } }
        if (-not $pos) { Write-Host "  A tétel már nincs a listán: $Utvonal" -ForegroundColor DarkYellow }
        else {
            $e = $entries[$pos - 1]
            switch ($Muvelet) {
                'rogzit'  { Invoke-Pin $e }
                'atnevez' { Invoke-Rename $e }
                'torol'   { Invoke-Delete $e }
                'fix'     { Invoke-Fix $e $pos }
                'athelyez' {
                    for ($j = 0; $j -lt $entries.Count; $j++) {
                        $x = $entries[$j]
                        Write-Host ('  {0,2}) {1}{2}' -f ($j + 1), $x.Label, $(if ($x.Fix) { '  (fix)' } elseif ($x.Note) { "  ($($x.Note))" })) -ForegroundColor $(if ($j + 1 -eq $pos) { 'Yellow' } else { 'Gray' })
                    }
                    $t = (Read-Host "  Új sorszám ($($e.Label), most: $pos.)").Trim(); $n = 0
                    if ([int]::TryParse($t, [ref]$n)) { Invoke-Move $pos $n }
                }
            }
        }
    }
    Update-PaletteQuiet (Get-ProjectEntries)
    Write-Host '  A fül magától bezárul.' -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
    return
}

# --- menü ----------------------------------------------------------------------------

function Show-Menu($entries) {
    Write-Host ''
    Write-Host '  Claude – projekt választás' -ForegroundColor Cyan -NoNewline
    Write-Host $(if ($Version) { "  v$Version" }) -ForegroundColor DarkGray
    Show-UpdateNotice $Updates
    Write-Host ''
    # Oszlopszélességek az ablakhoz, hogy egy tétel egy sor maradjon
    $width = try { $Host.UI.RawUI.WindowSize.Width } catch { 120 }
    if (-not $width -or $width -lt 60) { $width = 120 }
    $labelW = [Math]::Min(40, [Math]::Max(12, ($entries | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum))
    $short = {
        param([string]$s, [int]$max)
        if ($max -lt 8 -or $s.Length -le $max) { return $s }
        $head = [Math]::Floor(($max - 1) / 3); $tail = $max - 1 - $head
        $s.Substring(0, $head) + '…' + $s.Substring($s.Length - $tail)
    }
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $e = $entries[$i]
        $note = if ($e.Note) { "  ($($e.Note))" } elseif ($e.Fix) { '  (fix)' } else { '' }
        Write-Host ('  {0,2}) ' -f ($i + 1)) -NoNewline -ForegroundColor Yellow
        Write-Host ((& $short $e.Label $labelW).PadRight($labelW) + ' ') -NoNewline
        Write-Host (& $short $e.Path ($width - 7 - $labelW - 1 - $note.Length - 1)) -NoNewline -ForegroundColor DarkGray
        Write-Host $note -ForegroundColor DarkGray
    }
    Write-Host ''
    Show-MenuHelp $entries.Count $width
}

# Parancs-súgó: csoportonként (billentyű, magyarázat) párok, egységes cellarácsban,
# hogy a billentyűk oszlopba essenek; keskeny ablakban kevesebb pár jut egy sorba.
function Show-MenuHelp([int]$count, [int]$width) {
    # A sorszámot <sorszám> jelöli, nem egy konkrét szám, hogy ne higgye senki, hogy a „c4” maga a parancs
    $groups = @(
        @{ Name = 'Indítás'; Items = @(
            @('<sorszám>', "projekt indítása (1–$([Math]::Max(1, $count)))"), @('Enter', 'az 1. projekt indítása'),
            @('<útvonal>', 'a megadott mappa indítása'), @('q', 'csak shell, Claude nélkül')) }
        @{ Name = 'Session'; Items = @(
            @('c<sorszám>', 'utolsó session folytatása'), @('r<sorszám>', 'korábbi session választása')) }
        @{ Name = 'Lista'; Items = @(
            @('+', 'új mappa felvétele'), @('+<sorszám>', 'rögzítés a listán'),
            @('a<sorszám>', 'átnevezés'), @('-<sorszám>', 'törlés a listáról'),
            @('m<sorszám> <hely>', 'áthelyezés másik helyre'), @('f<sorszám>', 'fix sorszám be/ki')) }
        @{ Name = 'Keresés'; Items = @(
            @('k <név>', 'mappa keresése név szerint'), @('k', 'új projektmappák felderítése')) }
    )
    Write-HelpGroups $groups $width
    # A Terminal billentyűi (a választón kívül, futó Claude mellett is). Ablakrész = a fül egy
    # kettéosztott része (a Terminalban „pane”).
    Write-Host '  Billentyűk' -ForegroundColor Cyan -NoNewline
    Write-Host '  (a Terminalban bárhol; ablakrész = a fül egy kettéosztott része)' -ForegroundColor DarkGray
    $keys = @(
        @{ Name = 'Kép'; Items = @(
            ,@('Alt+S', 'képernyőkép beillesztése a Claude-ba')) }
        @{ Name = 'Ablakrész'; Items = @(
            @('Alt+Shift+V/H/D', 'új ablakrész jobbra / lent / auto'),
            @('Alt+Shift+nyilak', 'ablakrész átméretezése'), @('Alt+Shift+Z', 'nagyítás / vissza'),
            @('Alt+Shift+T/N', 'áthelyezés új fülre / ablakba'), @('Alt+Shift+1…9', 'áthelyezés az 1–9. fülre'),
            @('Ctrl+Shift+W', 'ablakrész (fül) bezárása')) }
        @{ Name = 'Egyéb'; Items = @(
            ,@('Ctrl+Shift+P', 'parancspaletta („claude”, „ablakrész”)')) }
    )
    Write-HelpGroups $keys $width
}

# Csoportok kiírása egységes cellarácsban: a billentyűk oszlopba esnek, keskeny ablakban
# kevesebb pár jut egy sorba, a csoport alján elválasztó vonal.
function Write-HelpGroups($groups, [int]$width) {
    # Egy parancs = billentyű + magyarázat; a parancsokat │ választja el, hogy a
    # magyarázat egyértelműen a tőle balra álló billentyűhöz tartozzon.
    $all = $groups | ForEach-Object { $_.Items }
    $keyW = ($all | ForEach-Object { $_[0].Length } | Measure-Object -Maximum).Maximum
    $textW = ($all | ForEach-Object { $_[1].Length } | Measure-Object -Maximum).Maximum
    $nameW = 11
    $sep = '  │  '
    $cellW = $keyW + 1 + $textW
    $perRow = [Math]::Max(1, [Math]::Floor(($width - 3 - $nameW + $sep.Length) / ($cellW + $sep.Length)))
    foreach ($g in $groups) {
        for ($i = 0; $i -lt $g.Items.Count; $i += $perRow) {
            $name = if ($i -eq 0) { $g.Name } else { '' }
            Write-Host ('  ' + $name.PadRight($nameW)) -NoNewline -ForegroundColor DarkCyan
            $row = $g.Items[$i..([Math]::Min($i + $perRow, $g.Items.Count) - 1)]
            for ($j = 0; $j -lt $row.Count; $j++) {
                if ($j -gt 0) { Write-Host $sep -NoNewline -ForegroundColor DarkGray }
                Write-Host ($row[$j][0].PadRight($keyW) + ' ') -NoNewline -ForegroundColor Yellow
                $text = if ($j -lt $row.Count - 1) { $row[$j][1].PadRight($textW) } else { $row[$j][1] }
                Write-Host $text -NoNewline -ForegroundColor Gray
            }
            Write-Host ''
        }
    }
    $lineW = [Math]::Min($width - 4, $nameW + $perRow * ($cellW + $sep.Length) - $sep.Length)
    Write-Host ('  ' + ('─' * $lineW)) -ForegroundColor DarkGray
}

$Host.UI.RawUI.WindowTitle = 'Claude – projekt választás'
Show-Menu $entries

$target = $null; $mode = 'uj'
while (-not $target) {
    $answer = (Read-Host '  Választás').Trim().Trim('"')
    if ($answer -eq 'q') { return }
    if ($answer -eq 'u' -and $Updates) {
        if (Invoke-RepoUpdate) { & $PSCommandPath @PSBoundParameters; return }   # az új változat indul
        continue
    }
    if ($answer -eq '' -and $entries.Count) { $target = $entries[0].Path; break }

    # Keresés: k / k <név>
    if ($answer -match '^[kK](?:\s+(.*))?$') {
        $found = Invoke-Search $entries $(if ($Matches[1]) { $Matches[1].Trim() } else { $null })
        if ($found) { $target = $found; break }
        $entries = Get-ProjectEntries
        Update-PaletteQuiet $entries
        Show-Menu $entries
        continue
    }

    # Listakezelés: + / +<szám> / a<szám> / -<szám> / m<szám> <hely> / f<szám>
    $op = $null; $n = 0; $moveTo = ''
    if ($answer -match '^\+\s*(\d+)$') { $op = 'pin'; $n = [int]$Matches[1] }
    elseif ($answer -match '^[mM]\s*(\d+)(?:\D+(\d+))?$') { $op = 'move'; $n = [int]$Matches[1]; $moveTo = $Matches[2] }
    elseif ($answer -match '^[fF]\s*(\d+)$') { $op = 'fix'; $n = [int]$Matches[1] }
    elseif ($answer.StartsWith('+')) { $op = 'new' }
    elseif ($answer -match '^[aA]\s*(\d+)$') { $op = 'rename'; $n = [int]$Matches[1] }
    elseif ($answer -match '^-\s*(\d+)$') { $op = 'delete'; $n = [int]$Matches[1] }
    if ($op) {
        if ($op -ne 'new' -and ($n -lt 1 -or $n -gt $entries.Count)) { Write-Host '  Nincs ilyen sorszám.' -ForegroundColor Red; continue }
        switch ($op) {
            'new'    { Invoke-NewPin $answer.Substring(1).Trim().Trim('"') }
            'pin'    { Invoke-Pin $entries[$n - 1] }
            'rename' { Invoke-Rename $entries[$n - 1] }
            'delete' { Invoke-Delete $entries[$n - 1] }
            'fix'    { Invoke-Fix $entries[$n - 1] $n }
            'move'   {
                if (-not $moveTo) { $moveTo = (Read-Host "  Új sorszám ($($entries[$n - 1].Label))").Trim() }
                $to = 0
                if ([int]::TryParse($moveTo, [ref]$to)) { Invoke-Move $n $to }
            }
        }
        $entries = Get-ProjectEntries
        Update-PaletteQuiet $entries
        Show-Menu $entries
        continue
    }

    # Folytatás: c<szám> / r<szám>
    if ($answer -match '^([cCrR])\s*(\d+)$') {
        $n = [int]$Matches[2]
        if ($n -lt 1 -or $n -gt $entries.Count) { Write-Host '  Nincs ilyen sorszám.' -ForegroundColor Red; continue }
        if (-not (Test-HasSession $entries[$n - 1].Path)) {
            Write-Host '  Ebben a mappában még nem futott Claude-session, nincs mit folytatni.' -ForegroundColor DarkYellow; continue
        }
        $mode = if ($Matches[1] -ieq 'c') { 'folytat' } else { 'korabbi' }
        $target = $entries[$n - 1].Path
        break
    }

    if ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $entries.Count) {
        $target = $entries[$n - 1].Path
    } elseif ($answer -and (Test-Path -LiteralPath $answer -PathType Container)) {
        $target = (Resolve-Path -LiteralPath $answer).Path
    } else {
        Write-Host '  Érvénytelen választás.' -ForegroundColor Red
    }
}

$lbl = ($entries | Where-Object { $_.Path -ieq $target.TrimEnd('\') } | Select-Object -First 1).Label
if (-not $lbl) { $lbl = Split-Path $target.TrimEnd('\') -Leaf }
Start-ClaudeIn $target.TrimEnd('\') $mode $lbl
