# Coleta complementar N=50 sob carga (26/11/2026)

As três linhas de `medicao.csv` registram cópias locais de 50 arquivos de teste de 4 MiB sob carga concorrente de CPU e gravação de 1 MiB. Foram reutilizados os arquivos-fonte da coleta local anterior; este conjunto mede cópia, não download.

Em cada destino, `fsutil` confirmou `$I30:$INDEX_ALLOCATION` com 16.384 bytes alocados (4 blocos de 4 KiB). O número de extensões foi 1, 2 e 1. A temperatura CPU Package foi informada manualmente após cada cópia (50, 53 e 51 °C); o pico durante a execução não foi registrado.

Os tempos de cópia variaram bastante. Preserve as três observações individuais; não use apenas a média para concluir causalidade. Os arquivos binários temporários da carga concorrente não fazem parte deste conjunto publicado.
