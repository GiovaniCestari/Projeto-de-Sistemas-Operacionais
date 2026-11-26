# Coleta complementar N=50 sob carga (26/11/2026)

As três linhas de `medicao.csv` registram cópias locais de 50 arquivos de teste de 4 MiB sob carga concorrente de CPU e gravação de 1 MiB. Foram reutilizados os arquivos-fonte da coleta local anterior; este conjunto mede cópia, não download.

A temperatura CPU Package foi lida manualmente após cada cópia (50, 53 e 51 °C); não houve leitura contínua do pico. `fsutil file layout` retornou acesso negado nas três consultas, então a alocação de diretório não foi medida nesta sessão.

Os tempos de cópia variaram bastante. Preserve as três observações individuais; não use apenas a média para concluir causalidade. Os arquivos binários de carga concorrente foram temporários e não fazem parte deste conjunto publicado.
