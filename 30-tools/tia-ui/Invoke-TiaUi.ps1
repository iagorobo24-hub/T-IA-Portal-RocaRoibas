[CmdletBinding()]
param(
    [ValidateSet('Ocr', 'ListWindows', 'Dump', 'Shot', 'Find', 'ClickText', 'ContextKey', 'RightClickText', 'RightClickRead', 'RightClickMenu', 'OpenDownloadMenu', 'ClickId', 'SetText')]
    [string]$Action = 'Ocr',
    [string]$WindowTitleLike = '*',
    [int]$ProcessId = 0,
    [string]$OutputDirectory = (Join-Path $env:TEMP 'tia-ui'),
    [switch]$IncludeHidden,
    [switch]$DoubleClick,
    [switch]$UseScreen,
    [string]$Text = '',
    [string]$Value = '',
    [string]$AutomationId = '',
    [string]$Name = '',
    [string]$Type = '',
    [string]$MenuPattern = 'MenuItemDownload'
)

$ErrorActionPreference = 'Stop'
# The host locale uses a comma as decimal separator, which makes [int] casts of UIA/OCR
# coordinates fail ("8,5"). Everything numeric is handled in the invariant culture.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::InvariantCulture
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type -AssemblyName System.Runtime.WindowsRuntime
# PrintWindow renders the window's own content even when another window covers it, which is
# what makes targeted OCR possible without stealing focus from the user.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Ui {
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int cmd);
        [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetActiveWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr update, IntPtr region, uint flags);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002, SWP_NOSIZE = 0x0001, SWP_NOACTIVATE = 0x0010, SWP_SHOWWINDOW = 0x0040;
    public const uint RDW_INVALIDATE = 0x0001, RDW_ERASE = 0x0004, RDW_ALLCHILDREN = 0x0080, RDW_UPDATENOW = 0x0100, RDW_FRAME = 0x0400;
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mi; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION U; }
    [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
    public const uint INPUT_MOUSE = 0;
    public const uint MOUSEEVENTF_MOVE = 0x0001, MOUSEEVENTF_ABSOLUTE = 0x8000;
    // SendInput is what modern input stacks (WPF included) actually observe; mouse_event is a
    // legacy path that some controls ignore.
    public static void SendClick(int x, int y, bool right) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(80);
        uint down = right ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_LEFTDOWN;
        uint up = right ? MOUSEEVENTF_RIGHTUP : MOUSEEVENTF_LEFTUP;
        var inputs = new INPUT[2];
        inputs[0].type = INPUT_MOUSE; inputs[0].U.mi.dwFlags = down;
        inputs[1].type = INPUT_MOUSE; inputs[1].U.mi.dwFlags = up;
        SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
    }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public const uint PW_RENDERFULLCONTENT = 0x00000002;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008, MOUSEEVENTF_RIGHTUP = 0x0010;
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(120);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, IntPtr.Zero);
    }
    public static void RightClick(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(120);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, IntPtr.Zero);
    }
}
"@
# Windows PowerShell needs the WinRT projections loaded explicitly before the types resolve.
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime]

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

# --- WinRT async helpers (Windows OCR lives behind IAsyncOperation) ---
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]

function Await-Operation($operation, $resultType) {
    $task = $asTaskGeneric.MakeGenericMethod($resultType).Invoke($null, @($operation))
    $task.Wait(-1) | Out-Null
    $task.Result
}
function Await-Action($action) {
    $task = $asTaskAction.Invoke($null, @($action))
    $task.Wait(-1) | Out-Null
}

function Convert-Coord([double]$Value) {
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value)) { return 0 }
    if ($Value -gt 2000000000) { return 0 }
    if ($Value -lt -2000000000) { return 0 }
    return [int]$Value
}

function Get-TopWindows {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $all = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
    $result = @()
    foreach ($w in $all) {
        try {
            $c = $w.Current
            $rect = $c.BoundingRectangle
            $result += [pscustomobject]@{
                ProcessId = $c.ProcessId
                Name = $c.Name
                ClassName = $c.ClassName
                AutomationId = $c.AutomationId
                Handle = $c.NativeWindowHandle
                X = Convert-Coord $rect.X
                Y = Convert-Coord $rect.Y
                Width = Convert-Coord $rect.Width
                Height = Convert-Coord $rect.Height
                Offscreen = $c.IsOffscreen
            }
        } catch { }
    }
    return $result
}

function Select-Window {
    param([string]$WindowTitleLike = '*', [int]$TargetPid = 0)
    $wins = Get-TopWindows
    if ($TargetPid -gt 0) { $wins = @($wins | Where-Object { $_.ProcessId -eq $TargetPid }) }
    $wins = @($wins | Where-Object { $_.Name -like $WindowTitleLike -and -not $_.Offscreen })
    if ($wins.Count -eq 0) { return $null }
    # the largest match is the interesting one
    return ($wins | Sort-Object -Property @{ Expression = { $_.Width * $_.Height } } -Descending | Select-Object -First 1)
}

function Save-ScreenCapture {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Path, [IntPtr]$WindowHandle = [IntPtr]::Zero, [switch]$ForceRepaint)
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $hdc = $g.GetHdc()
        try {
            $printed = $false
            if ($WindowHandle -ne [IntPtr]::Zero) {
                if ($ForceRepaint) {
                    # PrintWindow renders the cached frame of a WPF surface and RDW does not
                    # invalidate it. Minimizing and restoring the window forces a real repaint,
                    # which is what makes the captured coordinates match the screen.
                    [void][Win32Ui]::ShowWindow($WindowHandle, 6)   # SW_MINIMIZE
                    Start-Sleep -Milliseconds 400
                    [void][Win32Ui]::ShowWindow($WindowHandle, 9)   # SW_RESTORE
                    Start-Sleep -Milliseconds 700
                }
                [void][Win32Ui]::RedrawWindow($WindowHandle, [IntPtr]::Zero, [IntPtr]::Zero,
                    ([Win32Ui]::RDW_INVALIDATE -bor [Win32Ui]::RDW_ERASE -bor [Win32Ui]::RDW_ALLCHILDREN -bor [Win32Ui]::RDW_UPDATENOW -bor [Win32Ui]::RDW_FRAME))
                Start-Sleep -Milliseconds 300
                $printed = [Win32Ui]::PrintWindow($WindowHandle, $hdc, [Win32Ui]::PW_RENDERFULLCONTENT)
            }
            if (-not $printed) { $g.CopyFromScreen($X, $Y, 0, 0, $bmp.Size) }
        }
        finally { $g.ReleaseHdc($hdc) }
    } finally { $g.Dispose() }
    try { $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png) } finally { $bmp.Dispose() }
    return $Path
}

function Invoke-Ocr {
    param([string]$Path)
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if (-not $engine) { throw 'No OCR engine for the user profile languages.' }
    $file = Await-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
    $stream = Await-Operation ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await-Operation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await-Operation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await-Operation ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    $lines = @()
    foreach ($line in $result.Lines) {
        foreach ($word in $line.Words) {
            $r = $word.BoundingRect
            $lines += [pscustomobject]@{
                Text = $word.Text
                X = Convert-Coord $r.X
                Y = Convert-Coord $r.Y
                Width = Convert-Coord $r.Width
                Height = Convert-Coord $r.Height
                Confidence = [double]$word.Confidence
            }
        }
    }
    return $lines
}

function Invoke-Click {
    # Windows refuses to activate a window that is not the foreground process, and other
    # applications can sit on top of the target (a click would then land on them). Making the
    # window temporarily topmost guarantees the click reaches the intended control.
    # -KeepTopmost leaves the flag set: clearing it deactivates the window, which closes a
    # WPF context menu the moment it opens.
    param([IntPtr]$WindowHandle, [scriptblock]$Action, [switch]$KeepTopmost)
    [void][Win32Ui]::SetWindowPos($WindowHandle, [Win32Ui]::HWND_TOPMOST, 0, 0, 0, 0,
        ([Win32Ui]::SWP_NOMOVE -bor [Win32Ui]::SWP_NOSIZE -bor [Win32Ui]::SWP_SHOWWINDOW))
    $null = Bring-ToFront -WindowHandle $WindowHandle
    try { & $Action }
    finally {
        if (-not $KeepTopmost) {
            [void][Win32Ui]::SetWindowPos($WindowHandle, [Win32Ui]::HWND_NOTOPMOST, 0, 0, 0, 0,
                ([Win32Ui]::SWP_NOMOVE -bor [Win32Ui]::SWP_NOSIZE -bor [Win32Ui]::SWP_SHOWWINDOW))
        }
    }
}

function Bring-ToFront {
    param([IntPtr]$WindowHandle)
    # SetForegroundWindow alone is refused when the caller is not the foreground process.
    # Attaching to the foreground thread first is what makes the activation stick.
    $foreground = [Win32Ui]::GetForegroundWindow()
    if ($foreground -eq $WindowHandle) { return $true }
    $foregroundPid = 0
    $foregroundThread = [Win32Ui]::GetWindowThreadProcessId($foreground, [ref]$foregroundPid)
    $myThread = [Win32Ui]::GetCurrentThreadId()
    [void][Win32Ui]::AttachThreadInput($myThread, $foregroundThread, $true)
    try {
        # SW_RESTORE on a maximized window un-maximizes it, so only restore when minimized.
        if ([Win32Ui]::IsIconic($WindowHandle)) { [void][Win32Ui]::ShowWindow($WindowHandle, 9) }
        [void][Win32Ui]::BringWindowToTop($WindowHandle)
        [void][Win32Ui]::SetForegroundWindow($WindowHandle)
        [void][Win32Ui]::SetActiveWindow($WindowHandle)
    } finally {
        [void][Win32Ui]::AttachThreadInput($myThread, $foregroundThread, $false)
    }
    Start-Sleep -Milliseconds 600
    return ([Win32Ui]::GetForegroundWindow() -eq $WindowHandle)
}

function Convert-Normalized([string]$Text) {
    # OCR confuses characters that look alike. Mapping them keeps the match stable across
    # passes ("PLC_1" read once as "PLC_I", "0" as "O", ...).
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        switch ($ch) {
            'I' { [void]$sb.Append('1'); continue }
            'l' { [void]$sb.Append('1'); continue }
            '|' { [void]$sb.Append('1'); continue }
            'O' { [void]$sb.Append('0'); continue }
            'Q' { [void]$sb.Append('0'); continue }
            'S' { [void]$sb.Append('5'); continue }
            'B' { [void]$sb.Append('8'); continue }
            'Z' { [void]$sb.Append('2'); continue }
            'G' { [void]$sb.Append('6'); continue }
            'T' { [void]$sb.Append('7'); continue }
            'g' { [void]$sb.Append('9'); continue }
            'q' { [void]$sb.Append('9'); continue }
            'D' { [void]$sb.Append('0'); continue }
        }
        if ($ch -match '[0-9A-Za-z]') { [void]$sb.Append(([string]$ch).ToUpperInvariant()) }
    }
    return $sb.ToString()
}

function Find-Word {
    param([string[]]$Words, [string]$Text, [int]$WindowX = 0, [int]$WindowY = 0)
    # OCR splits the same label differently between passes, so an exact word-by-word match is
    # unreliable. The screen text is normalised (alphanumerics only) and the target is looked up
    # as a substring of it.
    $ocr = Invoke-Ocr -Path $script:LastCapture
    if ($ocr.Count -eq 0) { return $null }
    $flat = ''
    $map = @()
    foreach ($w in $ocr) {
        $norm = Convert-Normalized $w.Text
        for ($c = 0; $c -lt $norm.Length; $c++) { $map += $w }
        $flat += $norm
    }
    $needle = Convert-Normalized $Text
    if ($needle.Length -eq 0) { return $null }
    $at = $flat.IndexOf($needle, [StringComparison]::Ordinal)
    if ($at -lt 0) { return $null }
    $end = $at + $needle.Length - 1
    $first = $map[$at]
    $last = $map[$end]
    $x = $first.X
    $y = $first.Y
    $x2 = $last.X + $last.Width
    $y2 = $last.Y + $last.Height
    return [pscustomobject]@{
        Text = $Text
        ScreenX = $WindowX + $x
        ScreenY = $WindowY + $y
        CenterX = $WindowX + [int](($x + $x2) / 2)
        CenterY = $WindowY + [int](($y + $y2) / 2)
        Width = $x2 - $x
        Height = $y2 - $y
    }
}

function Get-UiaElement {
    param([string]$AutomationId = '', [string]$Name = '', [string]$Type = '',
    [string]$MenuPattern = 'MenuItemDownload', [IntPtr]$WindowHandle = [IntPtr]::Zero)
    $el = if ($WindowHandle -ne [IntPtr]::Zero) { [System.Windows.Automation.AutomationElement]::FromHandle($WindowHandle) }
          else { [System.Windows.Automation.AutomationElement]::RootElement }
    $cond = [System.Windows.Automation.Condition]::TrueCondition
    $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
    foreach ($e in $all) {
        $c = $e.Current
        if ($AutomationId -and $c.AutomationId -ne $AutomationId) { continue }
        if ($Name -and $c.Name -ne $Name) { continue }
        if ($Type -and ($c.ControlType.ProgrammaticName -replace 'ControlType\.', '') -ne $Type) { continue }
        return $e
    }
    return $null
}

switch ($Action) {
    'ListWindows' {
        Get-TopWindows | Sort-Object ProcessId | Format-Table -AutoSize | Out-String -Width 220
    }
    'Find' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'find.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if ($hit) { $hit | Format-List | Out-String } else { "NO ENCONTRADO: '$Text'" }
    }
    'ClickText' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'click.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        $null = Bring-ToFront -WindowHandle ([IntPtr]$win.Handle)
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) {
            [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $false)
            if ($DoubleClick) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $false) }
        }
        "clicked '$Text' at $($hit.CenterX),$($hit.CenterY)"
    }
    'RightClickText' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'rclick.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $true) }
        "right-clicked '$Text' at $($hit.CenterX),$($hit.CenterY)"
    }
    'RightClickRead' {
        # A context menu closes as soon as another process takes the focus, so the click and the
        # read have to happen inside the same process.
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'rclick-src.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $true) }
        "right-clicked '$Text' at $($hit.CenterX),$($hit.CenterY)"
        Start-Sleep -Milliseconds 1500
        $desktop = Get-TopWindows | Where-Object { $_.Name -eq 'Program Manager' } | Select-Object -First 1
        if (-not $desktop) { 'no desktop window found'; break }
        $shot = Join-Path $OutputDirectory 'menu.png'
        # A context menu is a real on-screen popup, so live pixels are required here; the
        # PrintWindow of the desktop only returns a cached image.
        Save-ScreenCapture -X $desktop.X -Y $desktop.Y -W $desktop.Width -H $desktop.Height -Path $shot | Out-Null
        "captura del escritorio: $shot"
        $words = Invoke-Ocr -Path $shot
        "PALABRAS: $($words.Count)"
        # the menu pops up next to the click; report that neighbourhood first
        $near = $words | Where-Object { [math]::Abs($_.X - $hit.ScreenX) -lt 420 -and [math]::Abs($_.Y - $hit.ScreenY) -lt 420 }
        $near | Sort-Object Y, X | ForEach-Object { "  '$($_.Text)' @ $($_.X),$($_.Y)" }
    }
    'RightClickMenu' {
        # A context menu is a separate popup window, so it cannot be read from the parent
        # window's pixels. It is, however, a real top-level window: enumerate what appeared
        # and read its items through UIA, where MenuItem exposes InvokePattern.
        $before = @(Get-TopWindows | ForEach-Object { $_.Handle })
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'rclick-src.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $true) }
        "right-clicked '$Text' at $($hit.CenterX),$($hit.CenterY)"
        Start-Sleep -Milliseconds 1200
        $new = @(Get-TopWindows | Where-Object { $before -notcontains $_.Handle })
        "ventanas nuevas: $($new.Count)"
        foreach ($w in $new) {
            "  VENTANA '$($w.Name)' clase=$($w.ClassName) pid=$($w.ProcessId) rect=$($w.X),$($w.Y),$($w.Width),$($w.Height)"
            $el = [System.Windows.Automation.AutomationElement]::FromHandle($w.Handle)
            $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
            foreach ($e in $all) {
                $c = $e.Current
                $type = $c.ControlType.ProgrammaticName -replace 'ControlType\.', ''
                if ($type -in @('MenuItem', 'ListItem', 'Button', 'Text', 'Menu', 'SplitButton')) {
                    $r = $c.BoundingRectangle
                    "     id='$($c.AutomationId)' name='$($c.Name)' type=$type enabled=$($c.IsEnabled) rect=$(Convert-Coord $r.X),$(Convert-Coord $r.Y),$(Convert-Coord $r.Width),$(Convert-Coord $r.Height)"
                }
            }
        }
    }
    'OpenDownloadMenu' {
        # The context menu closes as soon as another process takes the focus, so the whole
        # chain (right click -> menu entry -> dialog) has to run inside one process.
        $before = @(Get-TopWindows | ForEach-Object { $_.Handle })
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'dl-src.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) -ForceRepaint | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        # Only the right click. A preceding left click changes what TIA has selected in the tree
        # and the context menu does not open afterwards. The window stays topmost for the whole
        # chain: deactivating it closes the menu as soon as it opens.
        $null = Bring-ToFront -WindowHandle ([IntPtr]$win.Handle)
$probe = [IntPtr]::Zero
$probePid = 0
$probe = [Win32Ui]::WindowFromPoint((New-Object Win32Ui+POINT -Property @{ X = [int]$hit.CenterX; Y = [int]$hit.CenterY }))
[void][Win32Ui]::GetWindowThreadProcessId($probe, [ref]$probePid)
"    HIT-TEST: punto ($($hit.CenterX),$($hit.CenterY)) -> pid=$probePid (TIA=11856) ventana=$win.X,$win.Y,$win.Width,$win.Height"
Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $true) }
        Start-Sleep -Milliseconds 1400
        $menu = @(Get-TopWindows | Where-Object { $before -notcontains $_.Handle } | Where-Object { $_.Name -like '*ContextMenu*' -or $_.Name -like '*Menu*' })
        if ($menu.Count -eq 0) { throw 'No context menu window appeared.' }
        $menuWin = $menu[0]
        "menu: '$($menuWin.Name)' rect=$($menuWin.X),$($menuWin.Y),$($menuWin.Width),$($menuWin.Height)"
        $el = [System.Windows.Automation.AutomationElement]::FromHandle($menuWin.Handle)
        $items = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $target = $null
        foreach ($e in $items) {
            if ($e.Current.Name -like "*$MenuPattern*") { $target = $e; break }
        }
        if (-not $target) {
            'entradas del menu:'
            foreach ($e in $items) { "   '$($e.Current.Name)'" }
            throw "Menu entry matching '*$MenuPattern*' not found."
        }
        $r = $target.Current.BoundingRectangle
        $x = Convert-Coord ($r.X + $r.Width / 2)
        $y = Convert-Coord ($r.Y + $r.Height / 2)
        "entrada: '$($target.Current.Name)' en $x,$y"
        Invoke-Click -WindowHandle $menuWin.Handle { [Win32Ui]::SendClick($x, $y, $false) }
        Start-Sleep -Milliseconds 2000
        $after = @(Get-TopWindows | Where-Object { $before -notcontains $_.Handle -and $_.Handle -ne $menuWin.Handle })
        "ventanas nuevas tras la entrada: $($after.Count)"
        foreach ($w in $after) {
            "  VENTANA '$($w.Name)' clase=$($w.ClassName) rect=$($w.X),$($w.Y),$($w.Width),$($w.Height)"
            $we = [System.Windows.Automation.AutomationElement]::FromHandle($w.Handle)
            $wa = $we.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
            foreach ($e in $wa) {
                $c = $e.Current
                $type = $c.ControlType.ProgrammaticName -replace 'ControlType\.', ''
                if ($type -in @('Button', 'ComboBox', 'ListItem', 'Text', 'Edit', 'CheckBox', 'DataItem', 'Table', 'Tree')) {
                    $rr = $c.BoundingRectangle
                    "     id='$($c.AutomationId)' name='$($c.Name)' type=$type enabled=$($c.IsEnabled) rect=$(Convert-Coord $rr.X),$(Convert-Coord $rr.Y),$(Convert-Coord $rr.Width),$(Convert-Coord $rr.Height)"
                }
            }
        }
    }
    'ContextKey' {
        # Shift+F10 is the keyboard idiom for the context menu. It opens a popup even when the
        # right click does not, but in this host the popup is small and its items are not exposed
        # to UIA, so this is a probe rather than a full menu driver.
        Add-Type -AssemblyName System.Windows.Forms
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $null = Bring-ToFront -WindowHandle ([IntPtr]$win.Handle)
        Start-Sleep -Milliseconds 400
        [System.Windows.Forms.SendKeys]::SendWait('+{F10}')
        Start-Sleep -Milliseconds 1200
        $popups = @(Get-TopWindows | Where-Object { [CmdletBinding()]
param(
    [ValidateSet('Ocr', 'ListWindows', 'Dump', 'Shot', 'Find', 'ClickText', 'ContextKey', 'RightClickText', 'RightClickRead', 'RightClickMenu', 'OpenDownloadMenu', 'ClickId', 'SetText')]
    [string]$Action = 'Ocr',
    [string]$WindowTitleLike = '*',
    [int]$ProcessId = 0,
    [string]$OutputDirectory = (Join-Path $env:TEMP 'tia-ui'),
    [switch]$IncludeHidden,
    [switch]$DoubleClick,
    [switch]$UseScreen,
    [string]$Text = '',
    [string]$Value = '',
    [string]$AutomationId = '',
    [string]$Name = '',
    [string]$Type = '',
    [string]$MenuPattern = 'MenuItemDownload'
)

$ErrorActionPreference = 'Stop'
# The host locale uses a comma as decimal separator, which makes [int] casts of UIA/OCR
# coordinates fail ("8,5"). Everything numeric is handled in the invariant culture.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::InvariantCulture
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type -AssemblyName System.Runtime.WindowsRuntime
# PrintWindow renders the window's own content even when another window covers it, which is
# what makes targeted OCR possible without stealing focus from the user.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Ui {
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int cmd);
        [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetActiveWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr update, IntPtr region, uint flags);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002, SWP_NOSIZE = 0x0001, SWP_NOACTIVATE = 0x0010, SWP_SHOWWINDOW = 0x0040;
    public const uint RDW_INVALIDATE = 0x0001, RDW_ERASE = 0x0004, RDW_ALLCHILDREN = 0x0080, RDW_UPDATENOW = 0x0100, RDW_FRAME = 0x0400;
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mi; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION U; }
    [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
    public const uint INPUT_MOUSE = 0;
    public const uint MOUSEEVENTF_MOVE = 0x0001, MOUSEEVENTF_ABSOLUTE = 0x8000;
    // SendInput is what modern input stacks (WPF included) actually observe; mouse_event is a
    // legacy path that some controls ignore.
    public static void SendClick(int x, int y, bool right) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(80);
        uint down = right ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_LEFTDOWN;
        uint up = right ? MOUSEEVENTF_RIGHTUP : MOUSEEVENTF_LEFTUP;
        var inputs = new INPUT[2];
        inputs[0].type = INPUT_MOUSE; inputs[0].U.mi.dwFlags = down;
        inputs[1].type = INPUT_MOUSE; inputs[1].U.mi.dwFlags = up;
        SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
    }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public const uint PW_RENDERFULLCONTENT = 0x00000002;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008, MOUSEEVENTF_RIGHTUP = 0x0010;
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(120);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, IntPtr.Zero);
    }
    public static void RightClick(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(120);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, IntPtr.Zero);
    }
}
"@
# Windows PowerShell needs the WinRT projections loaded explicitly before the types resolve.
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime]

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

# --- WinRT async helpers (Windows OCR lives behind IAsyncOperation) ---
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]

function Await-Operation($operation, $resultType) {
    $task = $asTaskGeneric.MakeGenericMethod($resultType).Invoke($null, @($operation))
    $task.Wait(-1) | Out-Null
    $task.Result
}
function Await-Action($action) {
    $task = $asTaskAction.Invoke($null, @($action))
    $task.Wait(-1) | Out-Null
}

function Convert-Coord([double]$Value) {
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value)) { return 0 }
    if ($Value -gt 2000000000) { return 0 }
    if ($Value -lt -2000000000) { return 0 }
    return [int]$Value
}

function Get-TopWindows {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $all = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
    $result = @()
    foreach ($w in $all) {
        try {
            $c = $w.Current
            $rect = $c.BoundingRectangle
            $result += [pscustomobject]@{
                ProcessId = $c.ProcessId
                Name = $c.Name
                ClassName = $c.ClassName
                AutomationId = $c.AutomationId
                Handle = $c.NativeWindowHandle
                X = Convert-Coord $rect.X
                Y = Convert-Coord $rect.Y
                Width = Convert-Coord $rect.Width
                Height = Convert-Coord $rect.Height
                Offscreen = $c.IsOffscreen
            }
        } catch { }
    }
    return $result
}

function Select-Window {
    param([string]$WindowTitleLike = '*', [int]$TargetPid = 0)
    $wins = Get-TopWindows
    if ($TargetPid -gt 0) { $wins = @($wins | Where-Object { $_.ProcessId -eq $TargetPid }) }
    $wins = @($wins | Where-Object { $_.Name -like $WindowTitleLike -and -not $_.Offscreen })
    if ($wins.Count -eq 0) { return $null }
    # the largest match is the interesting one
    return ($wins | Sort-Object -Property @{ Expression = { $_.Width * $_.Height } } -Descending | Select-Object -First 1)
}

function Save-ScreenCapture {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Path, [IntPtr]$WindowHandle = [IntPtr]::Zero, [switch]$ForceRepaint)
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $hdc = $g.GetHdc()
        try {
            $printed = $false
            if ($WindowHandle -ne [IntPtr]::Zero) {
                if ($ForceRepaint) {
                    # PrintWindow renders the cached frame of a WPF surface and RDW does not
                    # invalidate it. Minimizing and restoring the window forces a real repaint,
                    # which is what makes the captured coordinates match the screen.
                    [void][Win32Ui]::ShowWindow($WindowHandle, 6)   # SW_MINIMIZE
                    Start-Sleep -Milliseconds 400
                    [void][Win32Ui]::ShowWindow($WindowHandle, 9)   # SW_RESTORE
                    Start-Sleep -Milliseconds 700
                }
                [void][Win32Ui]::RedrawWindow($WindowHandle, [IntPtr]::Zero, [IntPtr]::Zero,
                    ([Win32Ui]::RDW_INVALIDATE -bor [Win32Ui]::RDW_ERASE -bor [Win32Ui]::RDW_ALLCHILDREN -bor [Win32Ui]::RDW_UPDATENOW -bor [Win32Ui]::RDW_FRAME))
                Start-Sleep -Milliseconds 300
                $printed = [Win32Ui]::PrintWindow($WindowHandle, $hdc, [Win32Ui]::PW_RENDERFULLCONTENT)
            }
            if (-not $printed) { $g.CopyFromScreen($X, $Y, 0, 0, $bmp.Size) }
        }
        finally { $g.ReleaseHdc($hdc) }
    } finally { $g.Dispose() }
    try { $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png) } finally { $bmp.Dispose() }
    return $Path
}

function Invoke-Ocr {
    param([string]$Path)
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if (-not $engine) { throw 'No OCR engine for the user profile languages.' }
    $file = Await-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
    $stream = Await-Operation ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await-Operation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await-Operation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await-Operation ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    $lines = @()
    foreach ($line in $result.Lines) {
        foreach ($word in $line.Words) {
            $r = $word.BoundingRect
            $lines += [pscustomobject]@{
                Text = $word.Text
                X = Convert-Coord $r.X
                Y = Convert-Coord $r.Y
                Width = Convert-Coord $r.Width
                Height = Convert-Coord $r.Height
                Confidence = [double]$word.Confidence
            }
        }
    }
    return $lines
}

function Invoke-Click {
    # Windows refuses to activate a window that is not the foreground process, and other
    # applications can sit on top of the target (a click would then land on them). Making the
    # window temporarily topmost guarantees the click reaches the intended control.
    # -KeepTopmost leaves the flag set: clearing it deactivates the window, which closes a
    # WPF context menu the moment it opens.
    param([IntPtr]$WindowHandle, [scriptblock]$Action, [switch]$KeepTopmost)
    [void][Win32Ui]::SetWindowPos($WindowHandle, [Win32Ui]::HWND_TOPMOST, 0, 0, 0, 0,
        ([Win32Ui]::SWP_NOMOVE -bor [Win32Ui]::SWP_NOSIZE -bor [Win32Ui]::SWP_SHOWWINDOW))
    $null = Bring-ToFront -WindowHandle $WindowHandle
    try { & $Action }
    finally {
        if (-not $KeepTopmost) {
            [void][Win32Ui]::SetWindowPos($WindowHandle, [Win32Ui]::HWND_NOTOPMOST, 0, 0, 0, 0,
                ([Win32Ui]::SWP_NOMOVE -bor [Win32Ui]::SWP_NOSIZE -bor [Win32Ui]::SWP_SHOWWINDOW))
        }
    }
}

function Bring-ToFront {
    param([IntPtr]$WindowHandle)
    # SetForegroundWindow alone is refused when the caller is not the foreground process.
    # Attaching to the foreground thread first is what makes the activation stick.
    $foreground = [Win32Ui]::GetForegroundWindow()
    if ($foreground -eq $WindowHandle) { return $true }
    $foregroundPid = 0
    $foregroundThread = [Win32Ui]::GetWindowThreadProcessId($foreground, [ref]$foregroundPid)
    $myThread = [Win32Ui]::GetCurrentThreadId()
    [void][Win32Ui]::AttachThreadInput($myThread, $foregroundThread, $true)
    try {
        # SW_RESTORE on a maximized window un-maximizes it, so only restore when minimized.
        if ([Win32Ui]::IsIconic($WindowHandle)) { [void][Win32Ui]::ShowWindow($WindowHandle, 9) }
        [void][Win32Ui]::BringWindowToTop($WindowHandle)
        [void][Win32Ui]::SetForegroundWindow($WindowHandle)
        [void][Win32Ui]::SetActiveWindow($WindowHandle)
    } finally {
        [void][Win32Ui]::AttachThreadInput($myThread, $foregroundThread, $false)
    }
    Start-Sleep -Milliseconds 600
    return ([Win32Ui]::GetForegroundWindow() -eq $WindowHandle)
}

function Convert-Normalized([string]$Text) {
    # OCR confuses characters that look alike. Mapping them keeps the match stable across
    # passes ("PLC_1" read once as "PLC_I", "0" as "O", ...).
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        switch ($ch) {
            'I' { [void]$sb.Append('1'); continue }
            'l' { [void]$sb.Append('1'); continue }
            '|' { [void]$sb.Append('1'); continue }
            'O' { [void]$sb.Append('0'); continue }
            'Q' { [void]$sb.Append('0'); continue }
            'S' { [void]$sb.Append('5'); continue }
            'B' { [void]$sb.Append('8'); continue }
            'Z' { [void]$sb.Append('2'); continue }
            'G' { [void]$sb.Append('6'); continue }
            'T' { [void]$sb.Append('7'); continue }
            'g' { [void]$sb.Append('9'); continue }
            'q' { [void]$sb.Append('9'); continue }
            'D' { [void]$sb.Append('0'); continue }
        }
        if ($ch -match '[0-9A-Za-z]') { [void]$sb.Append(([string]$ch).ToUpperInvariant()) }
    }
    return $sb.ToString()
}

function Find-Word {
    param([string[]]$Words, [string]$Text, [int]$WindowX = 0, [int]$WindowY = 0)
    # OCR splits the same label differently between passes, so an exact word-by-word match is
    # unreliable. The screen text is normalised (alphanumerics only) and the target is looked up
    # as a substring of it.
    $ocr = Invoke-Ocr -Path $script:LastCapture
    if ($ocr.Count -eq 0) { return $null }
    $flat = ''
    $map = @()
    foreach ($w in $ocr) {
        $norm = Convert-Normalized $w.Text
        for ($c = 0; $c -lt $norm.Length; $c++) { $map += $w }
        $flat += $norm
    }
    $needle = Convert-Normalized $Text
    if ($needle.Length -eq 0) { return $null }
    $at = $flat.IndexOf($needle, [StringComparison]::Ordinal)
    if ($at -lt 0) { return $null }
    $end = $at + $needle.Length - 1
    $first = $map[$at]
    $last = $map[$end]
    $x = $first.X
    $y = $first.Y
    $x2 = $last.X + $last.Width
    $y2 = $last.Y + $last.Height
    return [pscustomobject]@{
        Text = $Text
        ScreenX = $WindowX + $x
        ScreenY = $WindowY + $y
        CenterX = $WindowX + [int](($x + $x2) / 2)
        CenterY = $WindowY + [int](($y + $y2) / 2)
        Width = $x2 - $x
        Height = $y2 - $y
    }
}

function Get-UiaElement {
    param([string]$AutomationId = '', [string]$Name = '', [string]$Type = '',
    [string]$MenuPattern = 'MenuItemDownload', [IntPtr]$WindowHandle = [IntPtr]::Zero)
    $el = if ($WindowHandle -ne [IntPtr]::Zero) { [System.Windows.Automation.AutomationElement]::FromHandle($WindowHandle) }
          else { [System.Windows.Automation.AutomationElement]::RootElement }
    $cond = [System.Windows.Automation.Condition]::TrueCondition
    $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
    foreach ($e in $all) {
        $c = $e.Current
        if ($AutomationId -and $c.AutomationId -ne $AutomationId) { continue }
        if ($Name -and $c.Name -ne $Name) { continue }
        if ($Type -and ($c.ControlType.ProgrammaticName -replace 'ControlType\.', '') -ne $Type) { continue }
        return $e
    }
    return $null
}

switch ($Action) {
    'ListWindows' {
        Get-TopWindows | Sort-Object ProcessId | Format-Table -AutoSize | Out-String -Width 220
    }
    'Find' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'find.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if ($hit) { $hit | Format-List | Out-String } else { "NO ENCONTRADO: '$Text'" }
    }
    'ClickText' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'click.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        $null = Bring-ToFront -WindowHandle ([IntPtr]$win.Handle)
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) {
            [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $false)
            if ($DoubleClick) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $false) }
        }
        "clicked '$Text' at $($hit.CenterX),$($hit.CenterY)"
    }
    'RightClickText' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'rclick.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $true) }
        "right-clicked '$Text' at $($hit.CenterX),$($hit.CenterY)"
    }
    'RightClickRead' {
        # A context menu closes as soon as another process takes the focus, so the click and the
        # read have to happen inside the same process.
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'rclick-src.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $true) }
        "right-clicked '$Text' at $($hit.CenterX),$($hit.CenterY)"
        Start-Sleep -Milliseconds 1500
        $desktop = Get-TopWindows | Where-Object { $_.Name -eq 'Program Manager' } | Select-Object -First 1
        if (-not $desktop) { 'no desktop window found'; break }
        $shot = Join-Path $OutputDirectory 'menu.png'
        # A context menu is a real on-screen popup, so live pixels are required here; the
        # PrintWindow of the desktop only returns a cached image.
        Save-ScreenCapture -X $desktop.X -Y $desktop.Y -W $desktop.Width -H $desktop.Height -Path $shot | Out-Null
        "captura del escritorio: $shot"
        $words = Invoke-Ocr -Path $shot
        "PALABRAS: $($words.Count)"
        # the menu pops up next to the click; report that neighbourhood first
        $near = $words | Where-Object { [math]::Abs($_.X - $hit.ScreenX) -lt 420 -and [math]::Abs($_.Y - $hit.ScreenY) -lt 420 }
        $near | Sort-Object Y, X | ForEach-Object { "  '$($_.Text)' @ $($_.X),$($_.Y)" }
    }
    'RightClickMenu' {
        # A context menu is a separate popup window, so it cannot be read from the parent
        # window's pixels. It is, however, a real top-level window: enumerate what appeared
        # and read its items through UIA, where MenuItem exposes InvokePattern.
        $before = @(Get-TopWindows | ForEach-Object { $_.Handle })
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'rclick-src.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $true) }
        "right-clicked '$Text' at $($hit.CenterX),$($hit.CenterY)"
        Start-Sleep -Milliseconds 1200
        $new = @(Get-TopWindows | Where-Object { $before -notcontains $_.Handle })
        "ventanas nuevas: $($new.Count)"
        foreach ($w in $new) {
            "  VENTANA '$($w.Name)' clase=$($w.ClassName) pid=$($w.ProcessId) rect=$($w.X),$($w.Y),$($w.Width),$($w.Height)"
            $el = [System.Windows.Automation.AutomationElement]::FromHandle($w.Handle)
            $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
            foreach ($e in $all) {
                $c = $e.Current
                $type = $c.ControlType.ProgrammaticName -replace 'ControlType\.', ''
                if ($type -in @('MenuItem', 'ListItem', 'Button', 'Text', 'Menu', 'SplitButton')) {
                    $r = $c.BoundingRectangle
                    "     id='$($c.AutomationId)' name='$($c.Name)' type=$type enabled=$($c.IsEnabled) rect=$(Convert-Coord $r.X),$(Convert-Coord $r.Y),$(Convert-Coord $r.Width),$(Convert-Coord $r.Height)"
                }
            }
        }
    }
    'OpenDownloadMenu' {
        # The context menu closes as soon as another process takes the focus, so the whole
        # chain (right click -> menu entry -> dialog) has to run inside one process.
        $before = @(Get-TopWindows | ForEach-Object { $_.Handle })
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $script:LastCapture = Join-Path $OutputDirectory 'dl-src.png'
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $script:LastCapture -WindowHandle ([IntPtr]$win.Handle) -ForceRepaint | Out-Null
        $hit = Find-Word -Text $Text -WindowX $win.X -WindowY $win.Y
        if (-not $hit) { throw "Text not found on screen: '$Text'" }
        # Only the right click. A preceding left click changes what TIA has selected in the tree
        # and the context menu does not open afterwards. The window stays topmost for the whole
        # chain: deactivating it closes the menu as soon as it opens.
        $null = Bring-ToFront -WindowHandle ([IntPtr]$win.Handle)
$probe = [IntPtr]::Zero
$probePid = 0
$probe = [Win32Ui]::WindowFromPoint((New-Object Win32Ui+POINT -Property @{ X = [int]$hit.CenterX; Y = [int]$hit.CenterY }))
[void][Win32Ui]::GetWindowThreadProcessId($probe, [ref]$probePid)
"    HIT-TEST: punto ($($hit.CenterX),$($hit.CenterY)) -> pid=$probePid (TIA=11856) ventana=$win.X,$win.Y,$win.Width,$win.Height"
Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($hit.CenterX, $hit.CenterY, $true) }
        Start-Sleep -Milliseconds 1400
        $menu = @(Get-TopWindows | Where-Object { $before -notcontains $_.Handle } | Where-Object { $_.Name -like '*ContextMenu*' -or $_.Name -like '*Menu*' })
        if ($menu.Count -eq 0) { throw 'No context menu window appeared.' }
        $menuWin = $menu[0]
        "menu: '$($menuWin.Name)' rect=$($menuWin.X),$($menuWin.Y),$($menuWin.Width),$($menuWin.Height)"
        $el = [System.Windows.Automation.AutomationElement]::FromHandle($menuWin.Handle)
        $items = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $target = $null
        foreach ($e in $items) {
            if ($e.Current.Name -like "*$MenuPattern*") { $target = $e; break }
        }
        if (-not $target) {
            'entradas del menu:'
            foreach ($e in $items) { "   '$($e.Current.Name)'" }
            throw "Menu entry matching '*$MenuPattern*' not found."
        }
        $r = $target.Current.BoundingRectangle
        $x = Convert-Coord ($r.X + $r.Width / 2)
        $y = Convert-Coord ($r.Y + $r.Height / 2)
        "entrada: '$($target.Current.Name)' en $x,$y"
        Invoke-Click -WindowHandle $menuWin.Handle { [Win32Ui]::SendClick($x, $y, $false) }
        Start-Sleep -Milliseconds 2000
        $after = @(Get-TopWindows | Where-Object { $before -notcontains $_.Handle -and $_.Handle -ne $menuWin.Handle })
        "ventanas nuevas tras la entrada: $($after.Count)"
        foreach ($w in $after) {
            "  VENTANA '$($w.Name)' clase=$($w.ClassName) rect=$($w.X),$($w.Y),$($w.Width),$($w.Height)"
            $we = [System.Windows.Automation.AutomationElement]::FromHandle($w.Handle)
            $wa = $we.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
            foreach ($e in $wa) {
                $c = $e.Current
                $type = $c.ControlType.ProgrammaticName -replace 'ControlType\.', ''
                if ($type -in @('Button', 'ComboBox', 'ListItem', 'Text', 'Edit', 'CheckBox', 'DataItem', 'Table', 'Tree')) {
                    $rr = $c.BoundingRectangle
                    "     id='$($c.AutomationId)' name='$($c.Name)' type=$type enabled=$($c.IsEnabled) rect=$(Convert-Coord $rr.X),$(Convert-Coord $rr.Y),$(Convert-Coord $rr.Width),$(Convert-Coord $rr.Height)"
                }
            }
        }
    }
    'ClickId' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $e = Get-UiaElement -AutomationId $AutomationId -Name $Name -Type $Type -WindowHandle ([IntPtr]$win.Handle)
        if (-not $e) { throw "UIA element not found: id='$AutomationId' name='$Name' type='$Type'" }
        $r = $e.Current.BoundingRectangle
        $x = Convert-Coord ($r.X + $r.Width / 2)
        $y = Convert-Coord ($r.Y + $r.Height / 2)
        # TIA hosts WPF inside WinForms panes: InvokePattern is accepted but does nothing, so the
        # physical click is what actually works. The window is raised first, otherwise the click
        # lands on whatever covers it.
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($x, $y, $false) }
        $invoked = $false
        try { $null = $e.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); $invoked = $true } catch { }
        "clicked id='$AutomationId' name='$Name' at $x,$y (invoke=$invoked)"
    }
    'SetText' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $e = Get-UiaElement -AutomationId $AutomationId -Name $Name -Type $Type -WindowHandle ([IntPtr]$win.Handle)
        if (-not $e) { throw "UIA element not found: id='$AutomationId' name='$Name'" }
        $ok = $false
        try { $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($Value); $ok = $true } catch { }
        "set text on id='$AutomationId' name='$Name' -> '$Value' (valuePattern=$ok)"
    }
    'Dump' {
        $win = Select-Window -TitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        "WINDOW '$($win.Name)' pid=$($win.ProcessId) handle=$($win.Handle)"
        $el = [System.Windows.Automation.AutomationElement]::FromHandle($win.Handle)
        $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        "descendants: $($all.Count)"
        foreach ($e in $all) {
            $c = $e.Current
            $r = $c.BoundingRectangle
            $pats = @()
            foreach ($pt in @([System.Windows.Automation.InvokePattern]::Pattern, [System.Windows.Automation.ValuePattern]::Pattern,
                              [System.Windows.Automation.SelectionItemPattern]::Pattern, [System.Windows.Automation.ExpandCollapsePattern]::Pattern,
                              [System.Windows.Automation.TogglePattern]::Pattern, [System.Windows.Automation.ScrollPattern]::Pattern)) {
                try {
                    $supported = $c.GetSupportedPatterns()
                    if ($supported | Where-Object { $_.ProgrammaticName -eq $pt.ProgrammaticName }) { $pats += $pt.ProgrammaticName -replace 'Pattern','' }
                } catch { }
            }
            "  id='$($c.AutomationId)' name='$($c.Name)' type=$($c.ControlType.ProgrammaticName -replace 'ControlType\.','') enabled=$($c.IsEnabled) off=$($c.IsOffscreen) rect=$(Convert-Coord $r.X),$(Convert-Coord $r.Y),$(Convert-Coord $r.Width),$(Convert-Coord $r.Height) pats=$($pats -join ',')"
        }
    }
    'Shot' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $path = Join-Path $OutputDirectory ("tia-{0:yyyyMMdd-HHmmss}.png" -f (Get-Date))
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $path -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        "captura: $path  ($($win.Width)x$($win.Height) en $($win.X),$($win.Y))"
    }
    'Ocr' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $path = Join-Path $OutputDirectory ("ocr-{0:yyyyMMdd-HHmmss}.png" -f (Get-Date))
        if ($UseScreen) {
            # Live pixels: correct when the target window is the foreground one, but it also
            # captures whatever covers it.
            Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $path | Out-Null
        }
        else {
            Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $path -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        }
        "VENTANA '$($win.Name)' pid=$($win.ProcessId) rect=$($win.X),$($win.Y),$($win.Width),$($win.Height) modo=$(if($UseScreen){'pantalla'}else{'printwindow'})"
        "CAPTURA $path"
        $words = Invoke-Ocr -Path $path
        "PALABRAS OCR: $($words.Count)"
        $words | ForEach-Object { "  '$($_.Text)' @ $($_.X),$($_.Y) $($_.Width)x$($_.Height) conf=$([math]::Round($_.Confidence,2))" }
    }
}




















.ClassName -like 'WindowsForms10.Window.808*' })
        foreach ($p in $popups) { "popup: nombre='$($p.Name)' clase=$($p.ClassName) rect=$($p.X),$($p.Y),$($p.Width),$($p.Height)" }
    }
    'ClickId' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $e = Get-UiaElement -AutomationId $AutomationId -Name $Name -Type $Type -WindowHandle ([IntPtr]$win.Handle)
        if (-not $e) { throw "UIA element not found: id='$AutomationId' name='$Name' type='$Type'" }
        $r = $e.Current.BoundingRectangle
        $x = Convert-Coord ($r.X + $r.Width / 2)
        $y = Convert-Coord ($r.Y + $r.Height / 2)
        # TIA hosts WPF inside WinForms panes: InvokePattern is accepted but does nothing, so the
        # physical click is what actually works. The window is raised first, otherwise the click
        # lands on whatever covers it.
        Invoke-Click -WindowHandle ([IntPtr]$win.Handle) { [Win32Ui]::SendClick($x, $y, $false) }
        $invoked = $false
        try { $null = $e.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); $invoked = $true } catch { }
        "clicked id='$AutomationId' name='$Name' at $x,$y (invoke=$invoked)"
    }
    'SetText' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $e = Get-UiaElement -AutomationId $AutomationId -Name $Name -Type $Type -WindowHandle ([IntPtr]$win.Handle)
        if (-not $e) { throw "UIA element not found: id='$AutomationId' name='$Name'" }
        $ok = $false
        try { $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($Value); $ok = $true } catch { }
        "set text on id='$AutomationId' name='$Name' -> '$Value' (valuePattern=$ok)"
    }
    'Dump' {
        $win = Select-Window -TitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        "WINDOW '$($win.Name)' pid=$($win.ProcessId) handle=$($win.Handle)"
        $el = [System.Windows.Automation.AutomationElement]::FromHandle($win.Handle)
        $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        "descendants: $($all.Count)"
        foreach ($e in $all) {
            $c = $e.Current
            $r = $c.BoundingRectangle
            $pats = @()
            foreach ($pt in @([System.Windows.Automation.InvokePattern]::Pattern, [System.Windows.Automation.ValuePattern]::Pattern,
                              [System.Windows.Automation.SelectionItemPattern]::Pattern, [System.Windows.Automation.ExpandCollapsePattern]::Pattern,
                              [System.Windows.Automation.TogglePattern]::Pattern, [System.Windows.Automation.ScrollPattern]::Pattern)) {
                try {
                    $supported = $c.GetSupportedPatterns()
                    if ($supported | Where-Object { $_.ProgrammaticName -eq $pt.ProgrammaticName }) { $pats += $pt.ProgrammaticName -replace 'Pattern','' }
                } catch { }
            }
            "  id='$($c.AutomationId)' name='$($c.Name)' type=$($c.ControlType.ProgrammaticName -replace 'ControlType\.','') enabled=$($c.IsEnabled) off=$($c.IsOffscreen) rect=$(Convert-Coord $r.X),$(Convert-Coord $r.Y),$(Convert-Coord $r.Width),$(Convert-Coord $r.Height) pats=$($pats -join ',')"
        }
    }
    'Shot' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $path = Join-Path $OutputDirectory ("tia-{0:yyyyMMdd-HHmmss}.png" -f (Get-Date))
        Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $path -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        "captura: $path  ($($win.Width)x$($win.Height) en $($win.X),$($win.Y))"
    }
    'Ocr' {
        $win = Select-Window -WindowTitleLike $WindowTitleLike -TargetPid $ProcessId
        if (-not $win) { throw "No window matching '$WindowTitleLike'." }
        $path = Join-Path $OutputDirectory ("ocr-{0:yyyyMMdd-HHmmss}.png" -f (Get-Date))
        if ($UseScreen) {
            # Live pixels: correct when the target window is the foreground one, but it also
            # captures whatever covers it.
            Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $path | Out-Null
        }
        else {
            Save-ScreenCapture -X $win.X -Y $win.Y -W $win.Width -H $win.Height -Path $path -WindowHandle ([IntPtr]$win.Handle) | Out-Null
        }
        "VENTANA '$($win.Name)' pid=$($win.ProcessId) rect=$($win.X),$($win.Y),$($win.Width),$($win.Height) modo=$(if($UseScreen){'pantalla'}else{'printwindow'})"
        "CAPTURA $path"
        $words = Invoke-Ocr -Path $path
        "PALABRAS OCR: $($words.Count)"
        $words | ForEach-Object { "  '$($_.Text)' @ $($_.X),$($_.Y) $($_.Width)x$($_.Height) conf=$([math]::Round($_.Confidence,2))" }
    }
}





















