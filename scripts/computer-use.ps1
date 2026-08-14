# dsh-computer-use-windows helper scripts (PowerShell, no external deps).
# Each script is invoked by the plugin via:
#   powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File <this> <args>

param(
  [string]$Action = "help",
  [string]$OutFile = "",
  [string]$X1 = "0", [string]$Y1 = "0", [string]$X2 = "0", [string]$Y2 = "0",
  [string]$Text = "",
  [string]$Key = "",
  [int]$ScrollDelta = 0,
  [string]$FromX = "0", [string]$FromY = "0", [string]$ToX = "0", [string]$ToY = "0",
  [int]$DurationMs = 200,
  [int]$DelayMs = 0
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# user32 input functions, compiled once per invocation.
$User32 = Add-Type -Namespace Win32 -Name Input -PassThru -MemberDefinition @"
  [DllImport("user32.dll")]
  public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")]
  public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
"@

$MOUSEEVENTF_LEFTDOWN  = 0x0002
$MOUSEEVENTF_LEFTUP    = 0x0004
$MOUSEEVENTF_RIGHTDOWN = 0x0008
$MOUSEEVENTF_RIGHTUP   = 0x0010
$MOUSEEVENTF_WHEEL     = 0x0800

function Get-ClampedRegion {
  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $x = [int]$X1; $y = [int]$Y1; $w = [int]$X2; $h = [int]$Y2
  if ($w -le 0 -or $h -le 0) {
    return ,@($bounds.X, $bounds.Y, $bounds.Width, $bounds.Height)
  }
  # Clamp the requested region inside the primary screen.
  $x = [Math]::Max($bounds.X, [Math]::Min($x, $bounds.X + $bounds.Width - 1))
  $y = [Math]::Max($bounds.Y, [Math]::Min($y, $bounds.Y + $bounds.Height - 1))
  $maxW = $bounds.X + $bounds.Width - $x
  $maxH = $bounds.Y + $bounds.Height - $y
  $w = [Math]::Max(1, [Math]::Min($w, $maxW))
  $h = [Math]::Max(1, [Math]::Min($h, $maxH))
  return ,@($x, $y, $w, $h)
}

switch ($Action) {
  "screenshot" {
    $r = Get-ClampedRegion
    $rect = New-Object System.Drawing.Rectangle($r[0], $r[1], $r[2], $r[3])
    $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
    $g.Dispose()
    $dir = Split-Path -Parent $OutFile
    if ($dir -ne "" -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output ("saved:{0}:{1}:{2}" -f $OutFile, $rect.Width, $rect.Height)
  }
  "cursor" {
    $p = [System.Windows.Forms.Cursor]::Position
    Write-Output ("cursor:{0}:{1}" -f $p.X, $p.Y)
  }
  "move" {
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point([int]$X1, [int]$Y1)
    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    Write-Output ("moved:{0}:{1}" -f $X1, $Y1)
  }
  "click" {
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point([int]$X1, [int]$Y1)
    Start-Sleep -Milliseconds 30
    $User32::mouse_event($MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    $User32::mouse_event($MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    Write-Output ("clicked:{0}:{1}" -f $X1, $Y1)
  }
  "rightclick" {
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point([int]$X1, [int]$Y1)
    Start-Sleep -Milliseconds 30
    $User32::mouse_event($MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    $User32::mouse_event($MOUSEEVENTF_RIGHTUP, 0, 0, 0, [UIntPtr]::Zero)
    Write-Output ("rightclicked:{0}:{1}" -f $X1, $Y1)
  }
  "drag" {
    $User32::SetCursorPos([int]$FromX, [int]$FromY) | Out-Null
    Start-Sleep -Milliseconds 50
    $User32::mouse_event($MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    $steps = [Math]::Max(1, [int]($DurationMs / 16))
    for ($i = 1; $i -le $steps; $i++) {
      $nx = [int]$FromX + ([int]$ToX - [int]$FromX) * $i / $steps
      $ny = [int]$FromY + ([int]$ToY - [int]$FromY) * $i / $steps
      $User32::SetCursorPos($nx, $ny) | Out-Null
      Start-Sleep -Milliseconds 16
    }
    $User32::mouse_event($MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    Write-Output ("dragged:{0}:{1}->{2}:{3}" -f $FromX, $FromY, $ToX, $ToY)
  }
  "scroll" {
    $amount = [Math]::Max(-120, [Math]::Min(120, [int]$ScrollDelta))
    $User32::mouse_event($MOUSEEVENTF_WHEEL, 0, 0, [uint32]$amount, [UIntPtr]::Zero)
    Write-Output ("scrolled:{0}" -f $amount)
  }
  "type" {
    [System.Windows.Forms.SendKeys]::SendWait($Text)
    Write-Output ("typed:{0}" -f $Text.Length)
  }
  "paste" {
    # Large/special text goes through the clipboard instead of SendKeys.
    Set-Clipboard -Value $Text
    Start-Sleep -Milliseconds 120
    [System.Windows.Forms.SendKeys]::SendWait("^v")
    Write-Output ("pasted:{0}" -f $Text.Length)
  }
  "key" {
    [System.Windows.Forms.SendKeys]::SendWait($Key)
    Write-Output ("key:{0}" -f $Key)
  }
  "screen" {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    Write-Output ("screen:{0}:{1}:{2}:{3}" -f $bounds.X, $bounds.Y, $bounds.Width, $bounds.Height)
  }
  default {
    Write-Output "actions: screenshot cursor move click rightclick drag scroll type paste key screen"
  }
}
