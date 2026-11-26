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

A dispersão é alta; estas médias parciais não sustentam uma conclusão sobre o efeito da quantidade de arquivos ou da distorção. A consulta real do NTFS indicou 1 unidade de 4 KiB em cada diretório de 10 arquivos e 4 unidades no de 50 arquivos. Isso substitui a estimativa antiga de 5 unidades para 50 arquivos, mas precisa ser confirmado com as demais condições antes de atualizar os gráficos finais.

Os arquivos da coleta parcial estão em [`dados/coleta_20261126_115344/`](dados/coleta_20261126_115344/): [CSV parcial](dados/coleta_20261126_115344/medicao_parcial.csv), [resumo](dados/coleta_20261126_115344/resumo_parcial.csv), [saída bruta do PowerShell](dados/coleta_20261126_115344/saida_bruta_powershell_parcial.txt) e [saída bruta do fsutil](dados/coleta_20261126_115344/blocos_fsutil.txt). Payloads binários e cópias de teste não foram publicados.

## Estrutura

- [`scripts/medir.ps1`](scripts/medir.ps1) — coleta Windows; cria uma pasta exclusiva por execução e não apaga dados existentes.
- [`medir.ps1`](medir.ps1) e [`medir.sh`](medir.sh) — versões que já estavam no repositório; mantidas durante a padronização.
- [`dados/`](dados/) — logs e CSVs. Veja [instruções para preservar as saídas](dados/README.md).
- [`graficos/`](graficos/) — os HTMLs fornecidos pelo grupo; ainda são rascunhos com dados estáticos e não correspondem à coleta parcial.
- [Relatório PDF parcial](relatorio_projeto2_BYG.pdf) — documenta as nove rodadas completas, as estatísticas descritivas e as limitações. As hipóteses são reconstruções provisórias porque a Ficha 3 original não estava disponível; o relatório não deve ser apresentado como coleta final.

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
- O CSV parcial não contém medidas de download e bateria; consulte os arquivos brutos e não preencha esses campos por estimativa.
- As visualizações só devem ser atualizadas depois da coleta restante e da conferência de todas as rodadas.

## Referências

- [OSTEP, capítulos 39 e 40](https://pages.cs.wisc.edu/~remzi/OSTEP/)
- [Microsoft: fsutil](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil)
- [Microsoft: fsutil file](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-file)
- [Microsoft: Win32_Battery](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-battery)
- [CPUID HWMonitor](https://www.cpuid.com/softwares/hwmonitor.html)

## Uso de IA

A IA organizou o repositório, preparou e executou parcialmente o script de coleta e consolidou os registros completos. A execução foi interrompida antes de terminar o cenário com distorção em 50 arquivos. As medições de temperatura foram fornecidas pelo grupo via HWMonitor; o grupo deve revisar os resultados e concluir a coleta antes da entrega final.
