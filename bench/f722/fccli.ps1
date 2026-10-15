param([string]$Port = "COM3", [string[]]$Commands = @("version", "status"), [int]$WaitMs = 1500)
# Minimal Betaflight CLI client over USB VCP. Read-only unless the commands passed change settings.
$sp = New-Object System.IO.Ports.SerialPort $Port, 115200, None, 8, One
$sp.ReadTimeout = 500; $sp.NewLine = "`n"; $sp.DtrEnable = $true
$sp.Open()
try {
    Start-Sleep -Milliseconds 300
    $null = $sp.ReadExisting()
    $sp.Write("#")
    Start-Sleep -Milliseconds 800
    $out = $sp.ReadExisting()
    foreach ($c in $Commands) {
        $sp.Write("$c`n")
        $deadline = (Get-Date).AddMilliseconds($WaitMs)
        while ((Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100; $out += $sp.ReadExisting() }
    }
    $out
} finally { $sp.Close() }
