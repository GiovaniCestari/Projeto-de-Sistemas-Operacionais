# Projeto 2 — Custo de organizar músicas em um MP3

**Disciplina:** Sistemas Operacionais · Universidade Presbiteriana Mackenzie · Turma 4P · Grupo BYG

**Pergunta:** quanto custa para o sistema operacional organizar músicas baixadas em um MP3?

O experimento observa a organização de arquivos em diretórios NTFS, comparando 10 e 50 arquivos de teste de 4 MiB em ambiente limpo e sob carga concorrente. A perspectiva é de persistência e entrada/saída: criação de arquivos, cópia para um diretório de destino e metadados do diretório.

## Integrantes e frentes

| Integrante | Frente | Cor |
|---|---|---|
| Laura Yumi Rodrigues Shiguemori | Velocidade de download (Mbps) | Roxo `#7c3aed` |
| Giovani de Oliveira Cestari · RA 10738542 | Blocos alocados do diretório | Verde `#16a34a` |
| Beatriz Bianco · RA 10735936 | Descarga de bateria (%/min) | Rosa `#e11d48` |
| Felipe Mendes | Temperatura (°C) e variância amostral da velocidade (Mbps²) | Azul `#2563eb` |

## Estado da coleta

Há nove rodadas completas no conjunto publicado: três limpas com 10 arquivos, três limpas com 50 e três com distorção com 10. A execução foi interrompida por temperatura elevada antes de completar as três rodadas com distorção para 50 arquivos. O arquivo bruto de `fsutil` também contém a consulta da tentativa interrompida; ela não entra na tabela abaixo.

| Cenário | Arquivos | Rodadas | Média da cópia (Mbps) | Desvio padrão amostral | Variância amostral (Mbps²) |
|---|---:|---:|---:|---:|---:|
| Limpo | 10 | 3 | 177,240 | 233,239 | 54.400,624 |
| Limpo | 50 | 3 | 213,603 | 263,289 | 69.321,054 |
| Distorção | 10 | 3 | 419,156 | 287,541 | 82.679,805 |
| Distorção | 50 | 0 | — | — | — |

A dispersão é alta; as médias da cópia local não sustentam uma conclusão sobre o efeito da quantidade de arquivos ou da distorção. Nesta coleta direta com fsutil, o NTFS indicou 1 unidade de 4 KiB para N=10 e 4 para N=50. A ficha anterior da Bia registra 1 e 5 blocos, mapeados pela quantidade de entradas; como o método difere, mantemos os dois resultados identificados por fonte.

A primeira medição registrada por Beatriz contém download, bateria, temperatura e uso/tempo de CPU para seis rodadas. Download médio: 28,83 Mbps (N=10) e 30,10 Mbps (N=50); descarga média: 0,536%/min e 0,550%/min; tempo de CPU médio: 0,95 s e 4,47 s. Os dados transcritos estão em [`dados/primeira_medicao_bia.csv`](dados/primeira_medicao_bia.csv).

Os arquivos da coleta parcial estão em [`dados/coleta_20261126_115344/`](dados/coleta_20261126_115344/): [CSV parcial](dados/coleta_20261126_115344/medicao_parcial.csv), [resumo](dados/coleta_20261126_115344/resumo_parcial.csv), [saída bruta do PowerShell](dados/coleta_20261126_115344/saida_bruta_powershell_parcial.txt) e [saída bruta do fsutil](dados/coleta_20261126_115344/blocos_fsutil.txt). Payloads binários e cópias de teste não foram publicados.

## Estrutura

- [`scripts/medir.ps1`](scripts/medir.ps1) — coleta Windows; cria uma pasta exclusiva por execução e não apaga dados existentes.
- [`medir.ps1`](medir.ps1) e [`medir.sh`](medir.sh) — versões que já estavam no repositório; mantidas durante a padronização.
- [`dados/`](dados/) — logs e CSVs. Veja [instruções para preservar as saídas](dados/README.md).
- [`graficos/`](graficos/) — visualizações dos seis registros da primeira medição da Bia; dados de origem e escopo descritos em [`graficos/README.md`](graficos/README.md). Não incluem a coleta complementar de cópia local.
- [Relatório PDF parcial](relatorio_projeto2_BYG.pdf) — reúne os dados da primeira medição e as nove rodadas complementares, separa métodos e registra limitações. As hipóteses operacionais são provisórias porque a Ficha 3 original não estava disponível.

## Como coletar no Windows

1. Abra o PowerShell como Administrador na pasta clonada do projeto.
2. Execute:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\medir.ps1 -ComDistorcao
```

O script mede uma amostra de download binária de 4 MiB por rodada, depois mede a cópia local para um diretório NTFS. Para cada condição, executa três rodadas de 10 e 50 arquivos no cenário limpo e, com `-ComDistorcao`, tenta repetir sob carga concorrente de CPU e disco. Informe a temperatura vista no HWMonitor quando solicitado; pressione Enter se não houver leitura disponível.

As saídas ficam em `dados/coleta_<data>_<hora>/`. Preserve os arquivos textuais brutos. O `.gitignore` evita enviar ao GitHub payloads e cópias grandes de teste.

Use `-SemInternet` para gerar os arquivos de teste localmente; nesse modo, a métrica de download fica vazia.

## Limites

- O conteúdo usado é um payload de teste, não uma música codificada em MP3.
- A velocidade de download e a velocidade de cópia local são operações diferentes.
- O destino é local e NTFS; não representa latência de um MP3 físico em USB ou FAT32.
- Temperatura depende da leitura manual do HWMonitor. Bateria depende dos sensores WMI.
- O CSV da coleta complementar local não contém download e bateria; esses valores estão no CSV da primeira medição, em dataset separado.
- Os gráficos atuais representam a primeira medição registrada pela Bia; não representam a coleta complementar local nem a condição interrompida.

## Referências

- [OSTEP, capítulos 39 e 40](https://pages.cs.wisc.edu/~remzi/OSTEP/)
- [Microsoft: fsutil](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil)
- [Microsoft: fsutil file](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-file)
- [Microsoft: Win32_Battery](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-battery)
- [CPUID HWMonitor](https://www.cpuid.com/softwares/hwmonitor.html)

## Uso de IA

A IA organizou o repositório, transcreveu os seis registros da ficha de Beatriz, preparou e executou parcialmente uma coleta complementar e consolidou as estatísticas. A execução complementar foi interrompida antes de terminar N=50 sob distorção. O grupo deve revisar a transcrição e as conclusões antes da entrega.
