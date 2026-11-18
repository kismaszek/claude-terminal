# Képernyőkép a Claude-nak: monitor/terület választása, majd a kép beillesztése a Claude-ablakrészbe.
#
# Két üzemmód:
#   - paraméter nélkül (Alt+S, kis ablakrészben): megmutatja a választót, és egy rejtett segédfolyamatot
#     indít a választással, majd kilép, így az ablakrész bezárul és a fókusz visszakerül a Claude-ablakrészre;
#   - -Valasztas (a segédfolyamat): elkészíti a képet, a vágólapra teszi, és Alt+V-t küld a Terminalnak,
#     amitől a Claude Code beilleszti ([Image #N]).
# A kép a Terminal nélkül készül: ha a választott monitoron van, arra az időre lekicsinyül.
param(
    [string]$Valasztas,
    [long]$Ablak,
    [int]$Szulo
)

$ErrorActionPreference = 'Stop'
$LogFile = Join-Path $PSScriptRoot 'kepernyokep.log'
function Write-KepLog([string]$m) {
    try { Add-Content -LiteralPath $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" -Encoding utf8 } catch { }
}

# --- natív segédek (lefordítva, gyorsítótárazva) ----------------------------------------------
$src = @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
public static class ClaudeKepernyokep {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);

    public static void DpiAware() { try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch { } }

    // A látható keret (a GetWindowRect a láthatatlan átméretező szegélyt is beleszámolja)
    public static int[] Bounds(IntPtr h) {
        RECT r;
        if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))) != 0) GetWindowRect(h, out r);
        return new int[] { r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top };
    }

    public static void Minimize(IntPtr h) { ShowWindow(h, 6); }

    // Előtérbe hozás háttérfolyamatból: a Windows ezt alapból tiltja, ezért az előtérbeli szál
    // bemenetéhez csatlakozunk, és ha így sem sikerül, egy Alt-leütés feloldja a zárat.
    public static bool Focus(IntPtr h) {
        if (IsIconic(h)) ShowWindow(h, 9);
        for (int i = 0; i < 3 && GetForegroundWindow() != h; i++) {
            IntPtr fg = GetForegroundWindow();
            uint me = GetCurrentThreadId();
            uint other = fg == IntPtr.Zero ? 0 : GetWindowThreadProcessId(fg, IntPtr.Zero);
            bool att = other != 0 && other != me && AttachThreadInput(me, other, true);
            BringWindowToTop(h);
            SetForegroundWindow(h);
            if (att) AttachThreadInput(me, other, false);
            if (GetForegroundWindow() != h) {
                keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);
                SetForegroundWindow(h);
            }
            Thread.Sleep(80);
        }
        return GetForegroundWindow() == h;
    }

    // Alt+V: a Claude Code Windowson ezzel illeszti be a vágólapon lévő képet
    public static void SendAltV() {
        keybd_event(0x12, 0, 0, UIntPtr.Zero);
        keybd_event(0x56, 0, 0, UIntPtr.Zero);
        keybd_event(0x56, 0, 2, UIntPtr.Zero);
        keybd_event(0x12, 0, 2, UIntPtr.Zero);
    }
}
'@
if (-not ('ClaudeKepernyokep' -as [type])) {
    $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($src))).Replace('-', '').Substring(0, 12)
    $dir = Join-Path $env:LOCALAPPDATA 'claude-terminal'
    $dll = Join-Path $dir "kepernyokep-$hash.dll"
    if (-not (Test-Path $dll)) {
        New-Item -ItemType Directory -Force $dir | Out-Null
        $tmp = Join-Path $dir "kepernyokep-$hash.$PID.dll"
        Add-Type -OutputAssembly $tmp -TypeDefinition $src
        try { Move-Item -LiteralPath $tmp -Destination $dll -ErrorAction Stop } catch { }
        if (-not (Test-Path $dll)) { $dll = $tmp } else { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
    }
    Add-Type -Path $dll
}
[ClaudeKepernyokep]::DpiAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

function Get-Monitorok {
    $all = @([System.Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.X }, { $_.Bounds.Y })
    for ($i = 0; $i -lt $all.Count; $i++) {
        $hely = if ($all.Count -eq 1) { 'egyetlen' } elseif ($i -eq 0) { 'bal' } elseif ($i -eq $all.Count - 1) { 'jobb' } else { 'középső' }
        if ($all[$i].Primary) { $hely += ' (fő)' }
        [pscustomobject]@{ Kulcs = "$($i + 1)"; Nev = $hely; Screen = $all[$i] }
    }
}

function Get-KepernyokepMappa {
    # A Win+Shift+S / PrtScn mentési helye (Képek\Képernyőképek, akár áthelyezve)
    try {
        $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction Stop).'{B7BEDE81-DF94-4682-A7D8-57A52620B86F}'
        if ($v) { $p = [Environment]::ExpandEnvironmentVariables($v); if (Test-Path $p) { return $p } }
    } catch { }
    Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Screenshots'
}
$SajatMappa = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Claude'

function Get-UtolsoKep {
    @((Get-KepernyokepMappa), $SajatMappa) | Where-Object { Test-Path $_ } |
        ForEach-Object { Get-ChildItem -Path (Join-Path $_ '*') -File -Include *.png, *.jpg, *.jpeg -ErrorAction SilentlyContinue } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# ============================================================================================
# 1) Választó (a kis ablakrészben)
# ============================================================================================
if (-not $Valasztas) {
    $wt = [ClaudeKepernyokep]::GetForegroundWindow()
    $wtScreen = [System.Windows.Forms.Screen]::FromHandle($wt)
    $mon = @(Get-Monitorok)
    $utolso = Get-UtolsoKep

    $esc = [char]27
    $k = "$esc[96m"; $h = "$esc[90m"; $r = "$esc[0m"
    Write-Host ''
    Write-Host "  Képernyőkép a Claude-nak $h– a kép utána magától bekerül a Claude-ba$r"
    Write-Host ''
    foreach ($m in $mon) {
        $b = $m.Screen.Bounds
        $jel = if ($m.Screen.DeviceName -eq $wtScreen.DeviceName) { "  $h← itt a Terminal (a kép idejére lekicsinyül)$r" } else { '' }
        Write-Host ("  $k{0}$r  {1,-14} {2}×{3}{4}" -f $m.Kulcs, $m.Nev, $b.Width, $b.Height, $jel)
    }
    if ($mon.Count -gt 1) { Write-Host "  ${k}a$r  az összes monitor egyben" }
    Write-Host "  ${k}t$r  terület kijelölése"
    if ($utolso) {
        $mikor = if ($utolso.LastWriteTime.Date -eq (Get-Date).Date) { $utolso.LastWriteTime.ToString('HH:mm') } else { $utolso.LastWriteTime.ToString('MM.dd. HH:mm') }
        Write-Host "  ${k}u$r  utolsó képernyőkép $h($mikor, $($utolso.Name))$r"
    }
    Write-Host "  ${h}Esc  mégse$r"

    $ervenyes = @($mon.Kulcs) + @('t') + @(if ($mon.Count -gt 1) { 'a' }) + @(if ($utolso) { 'u' })
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Escape' -or $key.KeyChar -eq 'q') { exit 0 }
        $c = "$($key.KeyChar)".ToLower()
        if ($c -in $ervenyes) { break }
    }

    $psi = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($a in '-NoProfile', '-NoLogo', '-File', $PSCommandPath, '-Valasztas', $c, '-Ablak', [string]$wt.ToInt64(), '-Szulo', [string]$PID) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true   # rejtett, és nem nyit új Terminal-fület
    [Diagnostics.Process]::Start($psi) | Out-Null
    exit 0
}

# ============================================================================================
# 2) Segédfolyamat: kép, vágólap, Alt+V
# ============================================================================================
try {
    $wt = [IntPtr]$Ablak
    # Megvárjuk, hogy a választó ablakrésze bezáruljon, és a fókusz visszakerüljön a Claude-ablakrészre
    if ($Szulo) { try { Wait-Process -Id $Szulo -Timeout 3 -ErrorAction Stop } catch { } }
    Start-Sleep -Milliseconds 200

    $kep = $null
    switch -Regex ($Valasztas) {
        '^[1-9]$|^a$' {
            if ($Valasztas -eq 'a') {
                $cel = [System.Windows.Forms.SystemInformation]::VirtualScreen
            } else {
                $m = @(Get-Monitorok) | Where-Object Kulcs -eq $Valasztas
                if (-not $m) { throw "nincs $Valasztas. monitor" }
                $cel = $m.Screen.Bounds
            }
            $kicsinyit = $false
            if ([ClaudeKepernyokep]::IsWindow($wt) -and -not [ClaudeKepernyokep]::IsIconic($wt)) {
                $wb = [ClaudeKepernyokep]::Bounds($wt)
                $kicsinyit = ([System.Drawing.Rectangle]::new($wb[0], $wb[1], $wb[2], $wb[3])).IntersectsWith($cel)
            }
            if ($kicsinyit) { [ClaudeKepernyokep]::Minimize($wt); Start-Sleep -Milliseconds 450 }
            try {
                $kep = [System.Drawing.Bitmap]::new($cel.Width, $cel.Height)
                $g = [System.Drawing.Graphics]::FromImage($kep)
                $g.CopyFromScreen($cel.X, $cel.Y, 0, 0, $kep.Size)
                $g.Dispose()
            } finally {
                if ($kicsinyit) { [ClaudeKepernyokep]::Focus($wt) | Out-Null }
            }
            New-Item -ItemType Directory -Force $SajatMappa | Out-Null
            $kep.Save((Join-Path $SajatMappa ("{0:yyyyMMdd-HHmmss}.png" -f (Get-Date))), [System.Drawing.Imaging.ImageFormat]::Png)
        }
        '^t$' {
            $seq = [ClaudeKepernyokep]::GetClipboardSequenceNumber()
            Start-Process 'ms-screenclip:'
            $hatar = (Get-Date).AddSeconds(90)
            while ((Get-Date) -lt $hatar) {
                Start-Sleep -Milliseconds 250
                if ([ClaudeKepernyokep]::GetClipboardSequenceNumber() -ne $seq -and [System.Windows.Forms.Clipboard]::ContainsImage()) {
                    $kep = [System.Windows.Forms.Clipboard]::GetImage(); break
                }
            }
            if (-not $kep) { Write-KepLog 'terület: nem készült kép (mégse vagy időtúllépés)'; exit 0 }
        }
        '^u$' {
            $f = Get-UtolsoKep
            if (-not $f) { throw 'nincs korábbi képernyőkép' }
            $bytes = [IO.File]::ReadAllBytes($f.FullName)
            $kep = [System.Drawing.Bitmap]::new([IO.MemoryStream]::new($bytes))
        }
    }

    [System.Windows.Forms.Clipboard]::SetImage($kep)
    if (-not [ClaudeKepernyokep]::Focus($wt)) { Write-KepLog 'a Terminal nem jött előtérbe; a kép a vágólapon van (Alt+V)'; exit 0 }
    Start-Sleep -Milliseconds 100
    [ClaudeKepernyokep]::SendAltV()
} catch {
    Write-KepLog "hiba ($Valasztas): $($_.Exception.Message)"
    exit 1
}
