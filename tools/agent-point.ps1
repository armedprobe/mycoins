# Печатает "X,Y" — центр окна WezTerm, в котором запущен текущий процесс.
# Использование: .\mycoins.exe --monitor-at=$(.\tools\agent-point.ps1)
$ErrorActionPreference = 'Stop'

Add-Type -Namespace AgentPoint -Name Win32 -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)]
public struct RECT { public int Left, Top, Right, Bottom; }
[DllImport("user32.dll")]
public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
[DllImport("user32.dll")]
public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
'@

# Физические пиксели, как у per-monitor DPI-aware приложения.
$PerMonitorAwareV2 = [IntPtr](-4)
if ([AgentPoint.Win32]::SetThreadDpiAwarenessContext($PerMonitorAwareV2) -eq [IntPtr]::Zero) {
    throw 'SetThreadDpiAwarenessContext не удался'
}

$procId = $PID
while ($true) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $procId"
    if ($null -eq $proc) {
        throw 'wezterm-gui.exe не найден среди родительских процессов'
    }
    if ($proc.Name -eq 'wezterm-gui.exe') { break }
    $procId = $proc.ParentProcessId
}

$hwnd = (Get-Process -Id $procId).MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) {
    throw "у wezterm-gui.exe (pid $procId) нет главного окна"
}

$rect = New-Object AgentPoint.Win32+RECT
if (-not [AgentPoint.Win32]::GetWindowRect($hwnd, [ref]$rect)) {
    throw 'GetWindowRect не удался'
}
'{0},{1}' -f [int](($rect.Left + $rect.Right) / 2), [int](($rect.Top + $rect.Bottom) / 2)
