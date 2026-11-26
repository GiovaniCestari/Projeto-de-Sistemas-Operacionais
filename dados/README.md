# Dados e reprodutibilidade

Mantenha cada execução numa subpasta própria `coleta_<data>_<hora>`. Preserve o transcript do PowerShell, a saída completa do `fsutil`, os dois CSVs e a identificação do ambiente. Não substitua nem mescle logs de execuções diferentes.

Arquivos de teste são intermediários e podem ser grandes. Para publicar no GitHub, inclua os CSVs e logs necessários à auditoria; não envie cópias de músicas ou payloads binários repetidos. Não crie resultados estimados para preencher medições ausentes.