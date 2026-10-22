# Invoke-TiaGuiClick.ps1 - click with a safety lock.
#
# Purpose: one synthetic mouse click on the TIA GUI, ONLY when the hit-test at
# the target point returns the expected window, so the agent cannot click into
# another app (Explorer, Excel, browser) by mistake. Extracts the manual
# workflow that produced the 2026-10-22 simulation diagnosis into a reusable,
# evidence-producing tool.
#
# Rules implemented here (see 10-kb/00-fundamentos/playbook-gui-tia.md):
#   - SendInput only (TIA is WPF; mouse_event is not reliable for it).
#   - Before clicking: WindowFromPoint() must return a window owned by the
#     expected process (by PID). If not: abort, no click, exit code 3.
#   - Optional topmost raise on the owning window before the click (topmost
#     does not persist across other apps  going foreground).
#   - After the click: optional screenshot crop around the point + a JSON
#     evidence record with everything that was checked.
#
# Usage:
#   # Diagnose what is at a point without clicking (always start here):
#   .\Invoke-TiaGuiClick.ps1 -X 2022 -Y 249 -ExpectedPid 27860 -InspectOnly
#
#   # Click (left button) with abort-on-mismatch:
#   .\Invoke-TiaGuiClick.ps1 -X 2022 -Y 249 -ExpectedPid 27860
#
#   # Right click, raise the window to topmost first, keep a screenshot and
#   # write evidence:
#   .\Invoke-TiaGuiClick.ps1 -X 2022 -Y 249 -ExpectedPid 27860 -Button Right `
#       -RaiseTopmost -AfterShot "70-runs\ui\menu.png" `
#       -EvidencePath "70-runs\ui\click-evidence.json"
#
# Exit codes:
#   0  click done (or -InspectOnly diagnostic produced)
#   2  bad parameters / window for expected process not found covering point
#   3  mismatch: the topmost window at the point belongs to another process
#      (default reaction: abort; use -ForceAtPoint only with a reason)
#   4  click sent but a popup menu was expected (not verifiable automatically)
#
param(
    [Parameter(Mandatory = $true)][int]$X,
    [Parameter(Mandatory = $true)][int]$Y,
    [ValidateSet('Left', 'Right')][string]$Button = 'Left',
    # Process id (number) expected to own the window under the point.
    [Parameter(Mandatory = $true)][int]$ExpectedPid,
    # Re-apply topmost to the owner window before clicking (recommended:
    # topmost is lost whenever another app goes foreground).
    [switch]$RaiseTopmost,
    # Remove topmost from the owner window after the click.
    [switch]$RemoveTopmostAfter,
    # Only report what sits at the point; never click.
    [switch]$InspectOnly,
    # Screenshot (PNG) of a 300x300 px area centered on the point, saved after
    # the action. Default lives under %TEMP%\tia-ui.
    [string]$AfterShot,
    # Route for the JSON evidence record.
    [string]$EvidencePath,
    # Click anyway although another process owns the point. Requires an
    # explicit -Reason; never use on a first attempt.
    [string]$ForceAtPoint,
    # Dwell between move and button-down (ms). TIA needs the move to land.
    [int]$DwellMs = 280
)

$ErrorActionPreference = 'Stop'

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class TiaGuiClick {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);

    public struct RECT { public int Left, Top, Right, Bottom; }
    public struct POINT { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mi; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION U; }

    public static string Title(IntPtr h) { var sb = new StringBuilder(256); GetWindowText(h, sb, 256); return sb.ToString(); }
    public static string Cls(IntPtr h) { var sb = new StringBuilder(128); GetClassName(h, sb, 128); return sb.ToString(); }
    public static int Pid(IntPtr h) { int p; GetWindowThreadProcessId(h, out p); return p; }
    public static bool Contains(IntPtr h, int x, int y) {
        RECT r;
        if (!GetWindowRect(h, out r)) return false;
        return x >= r.Left && x < r.Right && y >= r.Top && y < r.Bottom;
    }
    public static void Click(int x, int y, bool right, int dwell) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(dwell);
        uint down = right ? 0x0008u : 0x0002u;   // RIGHTDOWN / LEFTDOWN
        uint up   = right ? 0x0010u : 0x0004u;   // RIGHTUP   / LEFTUP
        var i = new INPUT[2];
        i[0].type = 0; i[0].U.mi.dwFlags = down;
        i[1].type = 0; i[1].U.mi.dwFlags = up;
        if (SendInput(2, i, Marshal.SizeOf(typeof(INPUT))) != 2) {
            throw new InvalidOperationException("SendInput did not inject both events");
        }
        System.Threading.Thread.Sleep(150);
    }
}
'@

# ---------------------------------------------------------------- diagnostics
# All top-level windows whose rect covers the point, in z-order (top first).
$atPoint = New-Object System.Collections.ArrayList
$cb = [TiaGuiClick+EnumProc]{
    param($h, $l)
    if ([TiaGuiClick]::IsWindowVisible($h) -and [TiaGuiClick]::Contains($h, $X, $Y)) {
        [void]$atPoint.Add([pscustomobject]@{
            Hwnd    = $h
            Pid     = [TiaGuiClick]::Pid($h)
            Class   = [TiaGuiClick]::Cls($h)
            Title   = [TiaGuiClick]::Title($h)
        })
    }
    return $true
}
[void][TiaGuiClick]::EnumWindows($cb, [IntPtr]::Zero)

# The immediate hit-test result (what would receive the click right now).
$point = New-Object TiaGuiClick+POINT; $point.X = $X; $point.Y = $Y
$hit  = [TiaGuiClick]::WindowFromPoint($point)
$hitPid = if ($hit -ne [IntPtr]::Zero) { [TiaGuiClick]::Pid($hit) } else { 0 }

$hitInfo = [ordered]@{
    x = $X; y = $Y; button = $Button
    expectedPid = $ExpectedPid
    hitPid = $hitPid
    hitHwnd = $hit
    hitClass = if ($hit -ne [IntPtr]::Zero) { [TiaGuiClick]::Cls($hit) } else { '' }
    hitTitle = if ($hit -ne [IntPtr]::Zero) { [TiaGuiClick]::Title($hit) } else { '' }
    windowsAtPoint = @($atPoint | ForEach-Object {
        [ordered]@{ hwnd = $_.Hwnd; pid = $_.Pid; class = $_.Class; title = $_.Title }
    })
}

function Save-Evidence([int]$exit, [string]$reason, [string]$shot) {
    if ($EvidencePath) {
        $dir = Split-Path $EvidencePath -Parent
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $rec = $hitInfo.PSObject.Copy()
        $rec.action = if ($InspectOnly) { 'inspect' }
                      elseif (-not $exit) { 'click' }
                      else { 'aborted' }
        $rec.result = $reason
        $rec.exitCode = $exit
        if ($shot) { $rec.screenshot = $shot }
        $rec.timestamp = (Get-Date).ToString('o')
        $rec | ConvertTo-Json -Depth 5 | Set-Content -Path $EvidencePath -Encoding UTF8
    }
}

# Section: inspect-only mode
if ($InspectOnly) {
    $hitInfo | ConvertTo-Json -Depth 5
    $frag = if ($hitPid -eq $ExpectedPid) { 'OK: the topmost window at the point belongs to the expected process.' }
            else { "MISMATCH: point is owned by pid $hitPid, expected $ExpectedPid. No click was sent." }
    Write-Host $frag
    Save-Evidence -exit 0 -reason $frag
    exit 0
}

# Section: mismatch gate
if ($hitPid -ne $ExpectedPid) {
    if (-not $ForceAtPoint) {
        $msg = "Aborted: point ($X,$Y) is owned by pid $hitPid ($($hitInfo.hitClass) - '$($hitInfo.hitTitle)'), expected $ExpectedPid. Try -RaiseTopmost, verify the window layout, or run -InspectOnly for the full window list."
        Write-Error $msg
        Save-Evidence -exit 3 -reason $msg
        exit 3
    }
    Write-Warning "Proceeding by explicit request: $ForceAtPoint"
}

# Section: find the owner window to raise
$owner = $atPoint | Where-Object { $_.Pid -eq $ExpectedPid } | Select-Object -First 1
if (-not $owner) {
    $msg = "No window of process $ExpectedPid covers point ($X,$Y). Is the app on the active virtual desktop and in the expected position?"
    Write-Error $msg
    Save-Evidence -exit 2 -reason $msg
    exit 2
}

if ($RaiseTopmost) {
    $SWP_NOMOVE = 0x0002; $SWP_NOSIZE = 0x0001; $SWP_SHOWWINDOW = 0x0040; $HWND_TOPMOST = -1
    [void][TiaGuiClick]::SetWindowPos($owner.Hwnd, [IntPtr]($HWND_TOPMOST), 0, 0, 0, 0,
        ($SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW))
    Start-Sleep -Milliseconds 300
}

[TiaGuiClick]::Click($X, $Y, ($Button -eq 'Right'), $DwellMs)

if ($RemoveTopmostAfter) {
    $SWP_NOMOVE = 0x0002; $SWP_NOSIZE = 0x0001; $SWP_SHOWWINDOW = 0x0040; $HWND_NOTOPMOST = -2
    [void][TiaGuiClick]::SetWindowPos($owner.Hwnd, [IntPtr]($HWND_NOTOPMOST), 0, 0, 0, 0,
        ($SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW))
}

# Section: post-shot evidence
$shot = $null
if ($AfterShot) {
    $dir = Split-Path $AfterShot -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Type -AssemblyName System.Drawing
    $half = 150
    $bmp = New-Object System.Drawing.Bitmap (2 * $half), (2 * $half)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($X - $half, $Y - $half, 0, 0, $bmp.Size)
    $g.Dispose()
    $bmp.Save($AfterShot, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $shot = $AfterShot
}

Save-Evidence -exit 0 -reason 'click sent' -shot $shot
$hitInfo | ConvertTo-Json -Depth 5
exit 0
