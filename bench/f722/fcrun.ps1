param([string[]]$Variants, [string]$Tag = "", [string]$OutDir = "$PSScriptRoot\results")
# Flash each SpeedyBee F7 V3 variant (mass erase), request DShot600 + bidir + denom 1, then measure.
$S   = $PSScriptRoot
$dfu = $(if ($env:DFU_UTIL) { $env:DFU_UTIL } else { "dfu-util" })
$cli = "$S\fccli.ps1"
$outDir = $OutDir
New-Item -ItemType Directory -Force $outDir | Out-Null

function WaitPort { for ($i = 0; $i -lt 30; $i++) { if ([System.IO.Ports.SerialPort]::GetPortNames() -contains "COM3") { Start-Sleep 3; return $true }; Start-Sleep 1 }; return $false }
function WaitDfu  { for ($i = 0; $i -lt 30; $i++) { if (Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match "VID_0483&PID_DF11" }) { return $true }; Start-Sleep 1 }; return $false }

foreach ($v in $Variants) {
    $bin = "$S\bins\SPEEDYBEEF7V3-$v.bin"
    "=== $v"
    if (-not (WaitPort)) { "no COM3"; break }
    & $cli -Commands @("", "bl") -WaitMs 800 | Out-Null
    if (-not (WaitDfu)) { "no DFU"; break }
    & $dfu -d 0483:df11 -a 0 -s 0x08000000:mass-erase:force 2>&1 | Out-Null
    $r = & $dfu -d 0483:df11 -a 0 -s 0x08000000:leave -D $bin 2>&1 | Out-String
    if ($r -notmatch "File downloaded successfully") { "flash failed: $r"; break }
    if (-not (WaitPort)) { "no COM3 after flash"; break }
    & $cli -Commands @("", "set motor_pwm_protocol = DSHOT600", "set dshot_bidir = ON", "set pid_process_denom = 1", "save") -WaitMs 1200 | Out-Null
    Start-Sleep 4
    if (-not (WaitPort)) { "no COM3 after save"; break }
    Start-Sleep 20   # let the scheduler settle
    $o = & $cli -Commands @("", "version", "get motor_pwm_protocol", "get dshot_bidir", "get pid_process_denom",
                           "status", "tasks", "status", "status", "status", "status", "tasks") -WaitMs 2500
    $o | Out-File -Encoding utf8 "$outDir\$v$Tag.txt"
    ($o | Select-String "^motor_pwm_protocol =|^dshot_bidir =|^pid_process_denom =|CPU:") -join "`n"
}
