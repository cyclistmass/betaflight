param([string]$Port = "COM3", [int]$Samples = 3000, [string]$OutCsv)
# Poll MSP_DEBUG (254, MSP v1) and save debug[0..n] per sample as CSV. Board must be out of CLI mode.
$sp = New-Object System.IO.Ports.SerialPort $Port, 115200, None, 8, One
$sp.ReadTimeout = 300; $sp.DtrEnable = $true
$sp.Open()
$req = [byte[]](0x24, 0x4D, 0x3C, 0x00, 0xFE, 0xFE)   # "$M<" size 0, cmd 254, checksum 254
$rows = New-Object System.Collections.Generic.List[string]
$bad = 0
try {
    Start-Sleep -Milliseconds 300
    $null = $sp.ReadExisting()
    for ($i = 0; $i -lt $Samples; $i++) {
        $sp.Write($req, 0, $req.Length)
        try {
            # sync on "$M>"
            $s = 0
            while ($s -lt 3) {
                $b = $sp.ReadByte()
                if (($s -eq 0 -and $b -eq 0x24) -or ($s -eq 1 -and $b -eq 0x4D) -or ($s -eq 2 -and $b -eq 0x3E)) { $s++ } else { $s = [int]($b -eq 0x24) }
            }
            $size = $sp.ReadByte(); $cmd = $sp.ReadByte()
            $buf = New-Object byte[] ($size + 1)
            $got = 0; while ($got -lt $size + 1) { $got += $sp.Read($buf, $got, $size + 1 - $got) }
            $cs = $size -bxor $cmd; for ($k = 0; $k -lt $size; $k++) { $cs = $cs -bxor $buf[$k] }
            if ($cmd -ne 254 -or $cs -ne $buf[$size]) { $bad++; continue }
            $vals = for ($k = 0; $k -lt $size; $k += 2) { [BitConverter]::ToInt16($buf, $k) }
            $rows.Add(($vals -join ","))
        } catch { $bad++; $null = $sp.ReadExisting() }
    }
} finally { $sp.Close() }
$rows | Set-Content -Encoding ascii $OutCsv
"samples=$($rows.Count) bad=$bad -> $OutCsv"
