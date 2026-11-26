#!/usr/bin/env bash
# Medição do grupo: custo do SO para organizar músicas num "MP3"
# Variável: quantidade de músicas (10 e 50). 3 repetições por condição.
# Fixos: tamanho de cada música (4 MiB), formato (.mp3), tamanho do nome (musica_NNN.mp3)
# Uso: bash medir.sh            (rodar dentro de /workspaces/<repo> no Codespaces)

set -e
TAM_MB=4
CONDICOES="10 50"
REPS=3
BASE="$PWD/teste_mp3"

echo "== Ambiente =="
date
uname -a
echo "CPUs: $(nproc)"
df -T "$PWD" | tail -1
echo "Tamanho do bloco do sistema de arquivos: $(stat -f -c %S "$PWD") bytes"
echo -n "Bateria (/sys/class/power_supply): "; ls /sys/class/power_supply 2>/dev/null | tr '\n' ' '; echo "[vazio = sem bateria]"
echo -n "Sensores de temperatura (/sys/class/thermal): "; ls /sys/class/thermal 2>/dev/null | tr '\n' ' '; echo "[vazio = sem sensor]"
echo

rm -rf "$BASE"; mkdir -p "$BASE/downloads"
# "música" modelo: 4 MiB de dados aleatórios (sempre o mesmo conteúdo)
head -c $((TAM_MB*1024*1024)) /dev/urandom > "$BASE/modelo.mp3"

for N in $CONDICOES; do
  # prepara N músicas na pasta de downloads (origem)
  rm -rf "$BASE/downloads"; mkdir -p "$BASE/downloads"
  for i in $(seq -f "%03g" 1 "$N"); do cp "$BASE/modelo.mp3" "$BASE/downloads/musica_$i.mp3"; done
  sync

  for r in $(seq 1 $REPS); do
    rm -rf "$BASE/mp3"; mkdir "$BASE/mp3"; sync
    # transfere as músicas para o "aparelho MP3" e força a escrita no disco (sync)
    T0=$(date +%s.%N)
    TIMEFORMAT="%U %S"
    TEMPOS=$( { time { cp "$BASE"/downloads/*.mp3 "$BASE/mp3/" && sync; } ; } 2>&1 )
    T1=$(date +%s.%N)

    REAL=$(echo "$T1 - $T0" | bc -l)
    USER=$(echo $TEMPOS | awk '{print $1}'); SYS=$(echo $TEMPOS | awk '{print $2}')
    CPU=$(echo "$USER + $SYS" | bc -l)
    MBITS=$(echo "$N * $TAM_MB * 8 * 1.048576" | bc -l)          # megabits transferidos
    MBPS=$(echo "$MBITS / $REAL" | bc -l)
    CPU_PCT=$(echo "100 * $CPU / $REAL" | bc -l)
    DIR_BYTES=$(stat -c %s "$BASE/mp3")
    DIR_BLOCOS=$(( DIR_BYTES / $(stat -f -c %S "$BASE/mp3") ))

    printf "N=%-3s rep=%s | tempo=%.2fs | vel=%.0f Mbps | blocos_dir=%s (%s bytes) | cpu=%.2fs (user %s + sys %s) | uso_cpu=%.0f%%\n" \
      "$N" "$r" "$REAL" "$MBPS" "$DIR_BLOCOS" "$DIR_BYTES" "$CPU" "$USER" "$SYS" "$CPU_PCT"
  done
  echo "ls -ld da pasta mp3 com $N músicas:"; ls -ld "$BASE/mp3"
  echo
done

rm -rf "$BASE"
