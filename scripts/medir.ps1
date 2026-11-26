PowerShell parse OK
param(
  [int[]]$Condicoes = @(10, 50),
  [int]$Repeticoes = 3,
  [int]$TamanhoMiB = 4,
  [switch]$ComDistorcao,
  [switch]$SemInternet
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# This script creates a unique, isolated folder and never deletes user data.
# Run from an elevated PowerShell for fsutil metadata collection.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Abra o PowerShell como Administrador e rode novamente. Nenhum dado foi alterado.'
}

$dataDir = Join-Path $PSScriptRoot 'dados'
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runRoot = Join-Path $dataDir "coleta_$stamp"
$sources = Join-Path $runRoot 'fontes'
$rawDir = Join-Path $runRoot 'bruto'
New-Item -ItemType Directory -Path $sources,$rawDir -Force | Out-Null

$transcript = Join-Path $runRoot 'saida_bruta_powershell.txt'
Start-Transcript -Path $transcript | Out-Null
$blockLog = Join-Path $runRoot 'blocos_fsutil.txt'
$csvPath = Join-Path $runRoot 'medicao.csv'
$csvBrPath = Join-Path $runRoot 'medicao_br.csv'
$results = [System.Collections.Generic.List[object]]::new()
$bytesPerSong = $TamanhoMiB * 1MB
$buffer = New-Object byte[] (1MB)
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

try {
  Write-Output "Coleta: $stamp"
  Write-Output "Windows: $((Get-CimInstance Win32_OperatingSystem).Caption)"
  Write-Output "Dados preservados em: $runRoot"
  Write-Output ("Origem: " + $(if ($SemInternet) { 'arquivos aleatórios locais (sem métrica de download)' } else { 'um arquivo binário de 4 MiB por rodada via Cloudflare speed test' }))
  $volume = Get-Volume -DriveLetter ((Split-Path -Qualifier $runRoot).TrimEnd(':'))
  Write-Output "Sistema de arquivos: $($volume.FileSystem)"
  if ($volume.FileSystem -ne 'NTFS') { throw 'A coleta de blocos exige que a pasta de execução esteja em NTFS.' }

  # Prepare source files outside the timed trials; keep them as reproducibility evidence.
  if ($SemInternet) {
    foreach ($i in 1..([Math]::Max(10, ($Condicoes | Measure-Object -Maximum).Maximum))) {
      $path = Join-Path $sources ("musica_{0:D3}.mp3" -f $i)
      $stream = [IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try {
        $left = $bytesPerSong
        while ($left -gt 0) {
          $rng.GetBytes($buffer)
          $count = [Math]::Min($buffer.Length,$left)
          $stream.Write($buffer,0,$count)
          $left -= $count
        }
        $stream.Flush($true)
      } finally { $stream.Dispose() }
    }
  }
  $fullCapacity = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullChargedCapacity

  $scenarios = @('limpo')
  if ($ComDistorcao) { $scenarios += 'distorcao' }
  foreach ($scenario in $scenarios) {
    foreach ($n in $Condicoes) {
      foreach ($rep in 1..$Repeticoes) {
        $dest = Join-Path $runRoot ("destino_{0}_{1}_r{2}" -f $scenario,$n,$rep)
        New-Item -ItemType Directory -Path $dest | Out-Null
        $distortionJob = $null
        if ($scenario -eq 'distorcao') {
          $stressDir = Join-Path $runRoot ("stress_{0}_r{1}" -f $n,$rep)
          New-Item -ItemType Directory -Path $stressDir | Out-Null
          $distortionJob = Start-Job -ArgumentList $stressDir -ScriptBlock {
            param($path)
            $payload = New-Object byte[] (1MB)
            $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            $i = 0
            while ($true) {
              $null = [Math]::Sqrt(987654.321)
              $random.GetBytes($payload)
              [IO.File]::WriteAllBytes((Join-Path $path ("stress_{0:D4}.bin" -f $i)), $payload)
              $i = ($i + 1) % 64
            }
          }
          Start-Sleep -Seconds 3
        }

        $downloadSeconds = $null
        $downloadMbps = $null
        if (-not $SemInternet) {
          $downloadFile = Join-Path $rawDir ("download_{0}_{1}_r{2}.bin" -f $scenario,$n,$rep)
          $downloadWatch = [Diagnostics.Stopwatch]::StartNew()
          Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=$bytesPerSong" -OutFile $downloadFile -UseBasicParsing
          $downloadWatch.Stop()
          $downloadSeconds = [Math]::Round($downloadWatch.Elapsed.TotalSeconds,3)
          if ($downloadWatch.Elapsed.TotalSeconds -gt 0) { $downloadMbps = [Math]::Round(($bytesPerSong * 8 / 1000000) / $downloadWatch.Elapsed.TotalSeconds,3) }
          foreach ($file in 1..$n) { Copy-Item -LiteralPath $downloadFile -Destination (Join-Path $sources ("musica_{0:D3}.mp3" -f $file)) -Force }
        }
        $batteryStart = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        $batteryRateStart = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Select-Object -First 1
        $cpuStart = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
        $process = Get-Process -Id $PID
        $cpuProcessStart = $process.TotalProcessorTime.TotalSeconds
        $watch = [Diagnostics.Stopwatch]::StartNew()
        try {
          foreach ($file in 1..$n) {
            $source = Join-Path $sources ("musica_{0:D3}.mp3" -f $file)
            $target = Join-Path $dest (Split-Path $source -Leaf)
            $input = [IO.File]::OpenRead($source)
            $output = New-Object IO.FileStream($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,1MB,[IO.FileOptions]::WriteThrough)
            try { $input.CopyTo($output); $output.Flush($true) } finally { $input.Dispose(); $output.Dispose() }
          }
        } finally {
          $watch.Stop()
          if ($distortionJob) { Stop-Job $distortionJob -ErrorAction SilentlyContinue; Remove-Job $distortionJob -Force -ErrorAction SilentlyContinue }
        }
        $batteryEnd = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        $batteryRateEnd = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Select-Object -First 1
        $cpuEnd = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
        $process.Refresh()
        $cpuProcessSeconds = [Math]::Round(($process.TotalProcessorTime.TotalSeconds - $cpuProcessStart),3)
        $cpuMean = $null
        if ($cpuStart -and $cpuEnd) { $cpuMean = [Math]::Round(([double]$cpuStart.PercentProcessorTime + [double]$cpuEnd.PercentProcessorTime) / 2,1) }
        $batteryRateMean = $null
        $batteryPctPerMin = $null
        $rateValues = @($batteryRateStart.DischargeRate,$batteryRateEnd.DischargeRate) | Where-Object { $_ -gt 0 }
        if ($rateValues.Count) {
          $batteryRateMean = [Math]::Round(($rateValues | Measure-Object -Average).Average,1)
          if ($fullCapacity -gt 0) { $batteryPctPerMin = [Math]::Round(100 * ($batteryRateMean / 60) / $fullCapacity,4) }
        }
        $layout = (& fsutil file layout $dest 2>&1 | Out-String)
        Add-Content -LiteralPath $blockLog -Value "`r`n=== cenário=$scenario N=$n repetição=$rep diretório=$dest ===`r`n$layout" -Encoding UTF8
        $allocatedBytes = $null
        $blocks4KiB = $null
        if ($layout -match '(?is)INDEX_ALLOCATION.*?(?:Allocated Size|Tamanho alocado)\s*:\s*([\d\.,]+)') {
          $numberText = $Matches[1]
          if ($numberText -match ',\d{1,2}$') { $numberText = $numberText -replace '\.','' -replace ',','.' }
          else { $numberText = $numberText -replace '[^\d]','' }
          $allocatedBytes = [double]::Parse($numberText,[Globalization.CultureInfo]::InvariantCulture)
          $blocks4KiB = [Math]::Ceiling($allocatedBytes / 4096)
        } elseif ($layout -match '(?i)INDEX_ROOT') { $allocatedBytes = 0; $blocks4KiB = 0 }

        $temperature = Read-Host "HWMonitor: informe a temperatura (°C) após cenário $scenario, N=$n, repetição $rep; Enter se indisponível"
        $tempNumber = $null
        if ($temperature -match '^\s*\d+(?:[\.,]\d+)?\s*$') { $tempNumber = [double]::Parse(($temperature -replace ',','.'),[Globalization.CultureInfo]::InvariantCulture) }
        $mbps = [Math]::Round((($n * $bytesPerSong * 8) / 1000000) / $watch.Elapsed.TotalSeconds,3)
        $results.Add([pscustomobject]@{
          Cenario=$scenario; Musicas=$n; Repeticao=$rep; Tamanho_MiB=$TamanhoMiB
          Download_s=$downloadSeconds; Download_Mbps=$downloadMbps
          Tempo_copia_s=[Math]::Round($watch.Elapsed.TotalSeconds,3); Velocidade_copia_Mbps=$mbps
          CPU_inicio_pct=if($cpuStart){[int]$cpuStart.PercentProcessorTime}else{$null}
          CPU_fim_pct=if($cpuEnd){[int]$cpuEnd.PercentProcessorTime}else{$null}
          CPU_media_pct=$cpuMean; CPU_processo_s=$cpuProcessSeconds
          Bateria_inicio_pct=if($batteryStart){$batteryStart.EstimatedChargeRemaining}else{$null}
          Bateria_fim_pct=if($batteryEnd){$batteryEnd.EstimatedChargeRemaining}else{$null}
          Taxa_descarga_mW_media=$batteryRateMean; Bateria_pct_min=$batteryPctPerMin
          BlocosDiretorio_4KiB=$blocks4KiB; INDEX_ALLOCATION_Bytes=$allocatedBytes
          Temperatura_C=$tempNumber; Diretorio=$dest
        })
        Write-Output ("Cenário={0}; N={1}; rodada={2}; tempo={3}s; cópia={4} Mbps; temp={5}" -f $scenario,$n,$rep,$watch.Elapsed.TotalSeconds,$mbps,$tempNumber)
      }
    }
  }

  $results | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Delimiter ';' -Encoding UTF8
  $results | ConvertTo-Csv -NoTypeInformation -Delimiter ';' | ForEach-Object { $_ -replace '(?<=\d)\.(?=\d)',',' } | Set-Content -LiteralPath $csvBrPath -Encoding UTF8
  Write-Output "CSV: $csvPath"
  Write-Output "CSV pt-BR: $csvBrPath"
  Write-Output "fsutil bruto: $blockLog"
} catch {
  $failurePath = Join-Path $runRoot 'erro_execucao.txt'
  ($_ | Out-String) | Set-Content -LiteralPath $failurePath -Encoding UTF8
  Write-Error ("Falha na coleta. Log preservado em: $failurePath. Detalhe: " + $_.Exception.Message)
} finally {
  $rng.Dispose()
  Stop-Transcript | Out-Null
}

