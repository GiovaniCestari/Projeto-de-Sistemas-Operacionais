# Dados e reprodutibilidade

Mantenha cada execução numa subpasta própria `coleta_<data>_<hora>`. Preserve o transcript do PowerShell, a saída completa do `fsutil`, os dois CSVs e a identificação do ambiente. Não substitua nem mescle logs de execuções diferentes.

Arquivos de teste são intermediários e podem ser grandes. Para publicar no GitHub, inclua os CSVs e logs necessários à auditoria; não envie cópias de músicas ou payloads binários repetidos. Não crie resultados estimados para preencher medições ausentes.

## Coleta adicional N=50 sob distorção

Os três registros de 26/11/2026 estão em [`coleta_n50_distorcao_20261126/`](coleta_n50_distorcao_20261126/). Eles usam arquivos-fonte já existentes e registram cópia local, taxa de cópia, temperatura CPU Package após cada rodada e o resultado de `fsutil` (`$INDEX_ALLOCATION` com 16.384 bytes, 4 blocos de 4 KiB em cada rodada). O número de extensões foi 1, 2 e 1. As leituras de temperatura não representam o pico contínuo da execução. Payloads temporários de carga não foram publicados.
