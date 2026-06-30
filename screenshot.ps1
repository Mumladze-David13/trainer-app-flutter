param([string]$name = "screen")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Find Flutter/trainer window
$win = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } |
       Where-Object { $_.MainWindowTitle -match "trainer|workout|flutter" -or $_.Name -match "trainer" } |
       Select-Object -First 1

if (-not $win) {
    Write-Host "Window not found. All windows:"
    Get-Process | Where-Object { $_.MainWindowTitle -ne "" } |
        Select-Object Name, MainWindowTitle | Format-Table
    exit 1
}

Write-Host "Found: $($win.MainWindowTitle)"

# Bring window to front
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$hwnd = $win.MainWindowHandle
[Win32]::ShowWindow($hwnd, 9) | Out-Null
[Win32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

# Get window rect
$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top

if ($w -le 0 -or $h -le 0) { Write-Host "Invalid rect"; exit 1 }

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($w, $h))
$g.Dispose()

$path = "C:\proj\trainer-flutter\$name.png"
$bmp.Save($path)
$bmp.Dispose()
Write-Host "Saved: $path"
