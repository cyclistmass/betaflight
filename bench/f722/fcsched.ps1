param([string[]]$Variants = @("sched-base", "sched-A2"), [int]$Rounds = 3, [int]$Samples = 3000,
      [string]$OutDir = "$PSScriptRoot\results\sched")
# Scheduler-overhead bench run: flash each variant, DShot600 + bidir + denom 1 + debug_mode SCHEDULER,
# capture tasks, leave CLI, then sample debug[2] (scheduler overhead, 0.1 us) over MSP. Rounds interleaved.
$S   = $PSScriptRoot
$dfu = $(if ($env:DFU_UTIL) { $env:DFU_UTIL } else { "dfu-util" })
$cli = "$S\fccli.ps1"
New-Item -ItemType Directory -Force $OutDir | Out-Null
function WaitPort { for ($i = 0; $i -lt 30; $i++) { if ([System.IO.Ports.SerialPort]::GetPortNames() -contains "COM3") { Start-Sleep 3; return $true }; Start-Sleep 1 }; return $false }
function WaitDfu  { for ($i = 0; $i -lt 30; $i++) { if (Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match "VID_0483&PID_DF11" }) { return $true }; Start-Sleep 1 }; return $false }

for ($r = 1; $r -le $Rounds; $r++) {
  foreach ($v in $Variants) {
    $tag = "$v-r$r"; "=== $tag"
    if (-not (WaitPort)) { "no COM3"; exit 1 }
    & $cli -Commands @("", "bl") -WaitMs 800 2>$null | Out-Null
    if (-not (WaitDfu)) { "no DFU"; exit 1 }
    & $dfu -d 0483:df11 -a 0 -s 0x08000000:mass-erase:force 2>&1 | Out-Null
    $o = & $dfu -d 0483:df11 -a 0 -s 0x08000000:leave -D "$S\bins\SPEEDYBEEF7V3-$v.bin" 2>&1 | Out-String
    if ($o -notmatch "File downloaded successfully") { "flash failed: $o"; exit 1 }
    if (-not (WaitPort)) { "no COM3 after flash"; exit 1 }
    & $cli -Commands @("", "set motor_pwm_protocol = DSHOT600", "set dshot_bidir = ON", "set pid_process_denom = 1",
                      "set debug_mode = SCHEDULER", "save") -WaitMs 1200 2>$null | Out-Null
    Start-Sleep 4
    if (-not (WaitPort)) { "no COM3 after save"; exit 1 }
    Start-Sleep 20
    $o = & $cli -Commands @("", "version", "get motor_pwm_protocol", "get dshot_bidir", "get pid_process_denom",
                           "get debug_mode", "status", "tasks", "tasks", "exit") -WaitMs 2500 2>$null
    $o | Out-File -Encoding utf8 "$OutDir\$tag.txt"
    Start-Sleep 4
    if (-not (WaitPort)) { "no COM3 after exit"; exit 1 }
    Start-Sleep 20
    & "$S\mspdebug.ps1" -Samples $Samples -OutCsv "$OutDir\$tag.csv"
  }
}
"done"
