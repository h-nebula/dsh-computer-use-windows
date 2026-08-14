# dsh-computer-use-windows helper scripts (PowerShell, no external deps).
# Each script is invoked by the plugin via: powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File <this> <args>

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

switch ($Action) {
  "screenshot" {
    # Full screen unless X1/Y1/X2/Y2 define a region.
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $x = [int]$X1; $y = [int]$Y1; $w = [int]$X2; $h = [int]$Y2
    if ($w -le 0 -or $h -le 0) {
      $rect = New-Object System.Drawing.Rectangle($bounds.X, $bounds.Y, $bounds.Width, $bounds.Height)
    } else {
      $rect = New-Object System.Drawing.Rectangle($x, $y, $w, $h)
    }
    $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
    $g.Dispose()
    $dir = Split-Path -Parent $OutFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
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
    $mouse = [System.Windows.Forms.Cursor]::Position
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    # Use user32 mouse_event for real button press/release at current position.
    Add-Type -Namespace Win32 -Name Input -MemberDefinition @"
      [DllImport("user32.dll")]
      public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
"@
    [Win32.Input]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)  # LEFTDOWN
    Start-Sleep -Milliseconds 50
    [Win32.Input]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)  # LEFTUP
    Write-Output ("clicked:{0}:{1}" -f $X1, $Y1)
  }
  "rightclick" {
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point([int]$X1, [int]$Y1)
    Start-Sleep -Milliseconds 30
    Add-Type -Namespace Win32 -Name Input -MemberDefinition @"
      [DllImport("user32.dll")]
      public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
"@
    [Win32.Input]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)  # RIGHTDOWN
    Start-Sleep -Milliseconds 50
    [Win32.Input]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)  # RIGHTUP
    Write-Output ("rightclicked:{0}:{1}" -f $X1, $Y1)
  }
  "drag" {
    Add-Type -Namespace Win32 -Name Input -MemberDefinition @"
      [DllImport("user32.dll")]
      public static extern bool SetCursorPos(int X, int Y);
      [DllImport("user32.dll")]
      public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
"@
    [Win32.Input]::SetCursorPos([int]$FromX, [int]$FromY) | Out-Null
    Start-Sleep -Milliseconds 50
    [Win32.Input]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)  # LEFTDOWN
    $steps = [Math]::Max(1, $DurationMs / 16)
    for ($i = 1; $i -le $steps; $i++) {
      $nx = [int]$FromX + ([int]$ToX - [int]$FromX) * $i / $steps
      $ny = [int]$FromY + ([int]$ToY - [int]$FromY) * $i / $steps
      [Win32.Input]::SetCursorPos($nx, $ny) | Out-Null
      Start-Sleep -Milliseconds 16
    }
    [Win32.Input]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)  # LEFTUP
    Write-Output ("dragged:{0}:{1}->{2}:{3}" -f $FromX, $FromY, $ToX, $ToY)
  }
  "scroll" {
    Add-Type -Namespace Win32 -Name Input -MemberDefinition @"
      [DllImport("user32.dll")]
      public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
"@
    # WHEEL: positive scrolls up, negative scrolls down. dwData is in multiples of 120.
    $amount = [Math]::Max(-120, [Math]::Min(120, [int]$ScrollDelta))
    [Win32.Input]::mouse_event(0x0800, 0, 0, [uint32]$amount, [UIntPtr]::Zero)
    Write-Output ("scrolled:{0}" -f $amount)
  }
  "type" {
    [System.Windows.Forms.SendKeys]::SendWait($Text)
    Write-Output ("typed:{0}" -f $Text.Length)
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
    Write-Output "actions: screenshot cursor move click rightclick drag scroll type key screen"
  }
}
