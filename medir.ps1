# Medicao do grupo: custo do SO para organizar musicas baixadas em um MP3
# Variavel: quantidade de musicas (10 e 50). 3 repeticoes por condicao.
# Fixos: tamanho de cada musica (4 MiB), formato (.mp3), tamanho do nome (musica_NNN.mp3)
#
# COMO RODAR (notebook FORA DA TOMADA, outros programas fechados):
#   1. Abrir o PowerShell como Administrador
#   2. cd para a pasta onde esta este arquivo
#   3. powershell -ExecutionPolicy Bypass -File .\medir.ps1
#   Para gravar num pendrive/MP3 de verdade:  ... -File .\medir.ps1 -Destino E:\MP3
#   Sem internet (gera as musicas localmente): ... -File .\medir.ps1 -SemInternet

param(
  [int[]]$Condicoes = @(10, 50),
  [int]$Reps = 3,
  [int]$TamMB = 4,
  [string]$Destino = "",
  [switch]$SemInternet
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # deixa o download muito mais rapido no PowerShell 5
$Raiz = Join-Path $PSScriptRoot "teste_mp3"
$Downloads = Join-Path $Raiz "downloads"
if ($Destino -eq "") { $Destino = Join-Path $Raiz "MP3" }
else { $Destino = Join-Path $Destino "teste_mp3_grupo" }   # nunca apaga nada fora desta subpasta
$DirDados = Join-Path $PSScriptRoot "dados"
New-Item -ItemType Directory -Force -Path $DirDados | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
Start-Transcript -Path (Join-Path $DirDados "saida_bruta_$Stamp.txt") | Out-Null
$Bytes = $TamMB * 1024 * 1024
$Url = "https://speed.cloudflare.com/__down?bytes=$Bytes"

# ---------- leituras do sistema ----------
function Ler-Bateria {
  # devolve capacidade restante (mWh), taxa de descarga (mW), % e se esta na tomada
  $r = [ordered]@{ mWh = $null; mW = $null; Pct = $null; NaTomada = $null }
  try {
    $s = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction Stop | Select-Object -First 1
    $r.mWh = [double]$s.RemainingCapacity; $r.mW = [double]$s.DischargeRate; $r.NaTomada = [bool]$s.PowerOnline
  } catch {}
  try { $r.Pct = [double](Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1).EstimatedChargeRemaining } catch {}
  return $r
}
function Capacidade-Total {
  try { return [double](Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity } catch { return $null }
}
function Ler-Temperatura {
  try {
    $t = Get-CimInstance -Namespace root\wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
    return [math]::Round((($t | Measure-Object CurrentTemperature -Maximum).Maximum / 10) - 273.15, 1)
  } catch { return $null }
}
function Ler-UsoCPU {
  try { return [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorTime } catch { return $null }
}
function Blocos-Diretorio($dir) {
  # NTFS: diretorio pequeno fica dentro do registro MFT (0 blocos);
  # quando cresce, ganha um $INDEX_ALLOCATION em clusters de 4 KiB.
  try { $out = (& fsutil file layout $dir 2>&1) | Out-String } catch { return "n/d" }
  $txtFile = Join-Path $DirDados ("fsutil_" + (Split-Path $dir -Leaf) + "_$Stamp.txt")
  Add-Content -Path $txtFile -Value $out
  if ($out -notmatch "INDEX_ALLOCATION") {
    if ($out -match "INDEX_ROOT") { return 0 } else { return "n/d" }
  }
  $trecho = $out.Substring($out.IndexOf("INDEX_ALLOCATION"))
  $m = [regex]::Match($trecho, "(?i)(Allocated Size|Tamanho alocado)\s*:\s*([\d\.,]+)")
  if (-not $m.Success) { $m = [regex]::Match($trecho, "(?i)(Size|Tamanho)\s*:\s*([\d\.,]+)") }
  if ($m.Success) {
    $b = [double]($m.Groups[2].Value -replace "[\.,]", "")
    return [math]::Ceiling($b / 4096)
  }
  return "ver fsutil"
}
function Copiar-ComFlush($origem, $destino) {
  # copia e forca a gravacao no disco (equivalente ao sync do Linux)
  $in = [System.IO.File]::OpenRead($origem)
  $outS = New-Object System.IO.FileStream($destino, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 1MB, [System.IO.FileOptions]::WriteThrough)
  try { $in.CopyTo($outS); $outS.Flush($true) } finally { $in.Dispose(); $outS.Dispose() }
}

# ---------- ambiente ----------
Write-Output "== Ambiente =="
Write-Output (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
try {
  $os = Get-CimInstance Win32_OperatingSystem
  $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
  Write-Output ("Sistema: " + $os.Caption + " " + $os.Version)
  Write-Output ("CPU: " + $cpu.Name + " (" + $cpu.NumberOfLogicalProcessors + " threads)")
} catch { Write-Output "Sistema/CPU: nao foi possivel ler" }
foreach ($p in @($PSScriptRoot, $Destino)) {
  try {
    $letra = (Split-Path -Qualifier $p)
    $vol = Get-Volume -DriveLetter $letra.TrimEnd(":")
    Write-Output ("Sistema de arquivos de " + $p + ": " + $vol.FileSystem)
  } catch {}
}
$CapTotal = Capacidade-Total
$b0 = Ler-Bateria
Write-Output ("Bateria: " + $b0.Pct + "% | " + $b0.mWh + " mWh de " + $CapTotal + " mWh | na tomada: " + $b0.NaTomada)
if ($b0.NaTomada) { Write-Warning "O notebook esta NA TOMADA: a bateria nao descarrega e a medida de bateria fica sem sentido. Tire da tomada e rode de novo." }
$t0 = Ler-Temperatura
if ($t0 -eq $null) { Write-Output "Temperatura: sensor nao disponivel pelo Windows (MSAcpi_ThermalZoneTemperature)" } else { Write-Output "Temperatura (zona termica ACPI): $t0 C" }
Write-Output ("Origem do 'download': " + $(if ($SemInternet) { "gerado localmente" } else { $Url }))
Write-Output ("Destino (MP3): " + $Destino)
Write-Output ""

$resultados = @()
foreach ($N in $Condicoes) {
  foreach ($r in 1..$Reps) {
    Remove-Item -Recurse -Force $Downloads, $Destino -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $Downloads, $Destino | Out-Null
    Start-Sleep -Seconds 5   # deixa o sistema assentar entre repeticoes

    $amostrasW = @(); $amostrasCPU = @(); $temps = @()
    $bIni = Ler-Bateria; $tIni = Get-Date
    $proc = Get-Process -Id $PID; $cpuIni = $proc.TotalProcessorTime

    # 1) BAIXAR as N musicas
    $swDown = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($i in 1..$N) {
      $arq = Join-Path $Downloads ("musica_{0:D3}.mp3" -f $i)
      if ($SemInternet) {
        $buf = New-Object byte[] $Bytes; (New-Object System.Random).NextBytes($buf); [System.IO.File]::WriteAllBytes($arq, $buf)
      } else {
        Invoke-WebRequest -Uri $Url -OutFile $arq -UseBasicParsing
      }
      $b = Ler-Bateria; if ($b.mW -ne $null) { $amostrasW += $b.mW }
      $c = Ler-UsoCPU; if ($c -ne $null) { $amostrasCPU += $c }
    }
    $swDown.Stop()

    # 2) ORGANIZAR no MP3 (copiar com gravacao forcada no disco)
    $swCopia = [System.Diagnostics.Stopwatch]::StartNew()
    Get-ChildItem $Downloads -Filter *.mp3 | Sort-Object Name | ForEach-Object {
      Copiar-ComFlush $_.FullName (Join-Path $Destino $_.Name)
    }
    $swCopia.Stop()
    $c = Ler-UsoCPU; if ($c -ne $null) { $amostrasCPU += $c }
    $tFim = Ler-Temperatura

    $proc.Refresh(); $cpuSeg = ($proc.TotalProcessorTime - $cpuIni).TotalSeconds
    $bFim = Ler-Bateria; $min = ((Get-Date) - $tIni).TotalMinutes

    $mbits = $N * $Bytes * 8 / 1e6
    $velDown = [math]::Round($mbits / $swDown.Elapsed.TotalSeconds, 1)
    $velCopia = [math]::Round($mbits / $swCopia.Elapsed.TotalSeconds, 1)

    # bateria em % por minuto: pela taxa de descarga media (mais precisa) e pela diferenca de capacidade
    $pctMinTaxa = $null; $pctMinCap = $null
    if ($CapTotal -and $amostrasW.Count -gt 0) {
      $mWmedio = ($amostrasW | Measure-Object -Average).Average
      $pctMinTaxa = [math]::Round(100 * ($mWmedio / 60) / $CapTotal, 3)
    }
    if ($CapTotal -and $bIni.mWh -ne $null -and $bFim.mWh -ne $null -and $min -gt 0) {
      $pctMinCap = [math]::Round(100 * (($bIni.mWh - $bFim.mWh) / $CapTotal) / $min, 3)
    }
    $cpuMedio = $null; if ($amostrasCPU.Count -gt 0) { $cpuMedio = [math]::Round(($amostrasCPU | Measure-Object -Average).Average, 0) }
    $blocos = Blocos-Diretorio $Destino

    $linha = [pscustomobject]@{
      Musicas = $N; Rep = $r
      Download_s = [math]::Round($swDown.Elapsed.TotalSeconds, 2); Download_Mbps = $velDown
      CopiaMP3_s = [math]::Round($swCopia.Elapsed.TotalSeconds, 2); CopiaMP3_Mbps = $velCopia
      BlocosDiretorio = $blocos
      Bateria_pct_min_taxa = $pctMinTaxa; Bateria_pct_min_capacidade = $pctMinCap
      Bateria_pct_ini = $bIni.Pct; Bateria_pct_fim = $bFim.Pct
      Temp_C_fim = $tFim; UsoCPU_pct = $cpuMedio; TempoCPU_s = [math]::Round($cpuSeg, 2)
      Duracao_min = [math]::Round($min, 2)
    }
    $resultados += $linha
    Write-Output ("N={0,-3} rep={1} | download {2}s = {3} Mbps | copia p/ MP3 {4}s = {5} Mbps | blocos dir = {6} | bateria = {7} %/min (taxa) / {8} %/min (capacidade) | temp = {9} C | CPU {10}% / {11}s" -f `
      $N, $r, $linha.Download_s, $velDown, $linha.CopiaMP3_s, $velCopia, $blocos, $pctMinTaxa, $pctMinCap, $tFim, $cpuMedio, $linha.TempoCPU_s)
  }
  Write-Output ""
}

$csv = Join-Path $DirDados "medicao_$Stamp.csv"
$resultados | Export-Csv -Path $csv -NoTypeInformation -Delimiter ";" -Encoding UTF8
Write-Output "== Tabela =="
$resultados | Format-Table Musicas, Rep, Download_Mbps, CopiaMP3_Mbps, BlocosDiretorio, Bateria_pct_min_taxa, Bateria_pct_min_capacidade, Temp_C_fim, UsoCPU_pct, TempoCPU_s -AutoSize | Out-String -Width 200 | Write-Output
Write-Output "Arquivos salvos em: $DirDados"
Remove-Item -Recurse -Force $Raiz -ErrorAction SilentlyContinue
Stop-Transcript | Out-Null
