# Projeto 2 — Custo de organizar músicas em um MP3

**Disciplina:** Sistemas Operacionais · Universidade Presbiteriana Mackenzie · Turma 4P · Grupo BYG

**Pergunta:** quanto custa para o sistema operacional organizar músicas baixadas em um MP3?

O experimento observa o trabalho de armazenamento e organização de arquivos em diretórios NTFS, comparando 10 e 50 arquivos de teste de 4 MiB em ambiente limpo e com carga concorrente. A perspectiva é de persistência e entrada/saída: criação de arquivos, cópia para um diretório de destino e metadados do diretório.

## Integrantes e frentes

| Integrante | Frente | Cor |
|---|---|---|
| Laura Yumi Rodrigues Shiguemori | Velocidade de download (Mbps) | Roxo `#7c3aed` |
| Giovani de Oliveira Cestari · RA 10738542 | Blocos alocados do diretório | Verde `#16a34a` |
| Beatriz Bianco · RA 10735936 | Descarga de bateria (%/min) | Rosa `#e11d48` |
| Felipe Mendes | Temperatura (°C) e variância amostral da velocidade (Mbps²) | Azul `#2563eb` |

## Estrutura

- [`scripts/medir.ps1`](scripts/medir.ps1) — coleta Windows, com saídas preservadas em uma pasta única por execução.
- [`medir.ps1`](medir.ps1) e [`medir.sh`](medir.sh) — versões que já estavam no repositório; mantidas durante a padronização.
- `dados/coleta_<data>_<hora>/` — logs brutos, saída de `fsutil`, CSVs e arquivos de teste produzidos pela nova coleta.
- `graficos/` — gráficos finais a serem consolidados a partir dos CSVs conferidos.
- `relatorio_projeto2_BYG.pdf` — relatório final após validação dos dados reais.

Os três últimos itens dependem da execução da coleta e da conferência das fontes originais. Nenhum resultado numérico foi preenchido neste README sem os respectivos dados brutos.

## Como coletar no Windows

1. Conecte o notebook à energia somente se a medição de bateria não for necessária; registre se estava na tomada.
2. Abra o PowerShell como Administrador e navegue até a pasta clonada do projeto.
3. Execute:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\medir.ps1 -ComDistorcao
```

O script baixa um arquivo binário de 4 MiB por rodada para estimar a velocidade de download, duplica esse conteúdo como arquivos de teste e mede a cópia local. Para cada condição, coleta três rodadas de 10 e 50 arquivos no cenário limpo e, com `-ComDistorcao`, repete com carga concorrente de CPU e disco. Após cada rodada, informe a temperatura observada no HWMonitor; pressione Enter se a leitura estiver indisponível.

As saídas ficam numa pasta exclusiva em `dados/`; o script não apaga arquivos existentes. Preserve a pasta inteira e envie os CSVs e os dois arquivos brutos para consolidação. Sem conexão, rode com `-SemInternet`; nesse caso, a métrica de download fica ausente e os arquivos de origem são gerados localmente.

## Leitura dos resultados e limites

- `Velocidade_copia_Mbps` descreve a cópia local para o diretório de destino; `Download_Mbps` é uma amostra de download de 4 MiB por rodada. São operações diferentes.
- O conteúdo baixado é um arquivo de teste binário, não uma música codificada em MP3. Os resultados medem operações de arquivo sobre esse conjunto de teste.
- O destino é um diretório NTFS local. Isso não representa a latência de um MP3 físico conectado por USB.
- A leitura de temperatura depende de entrada manual do HWMonitor. A leitura de bateria depende dos sensores WMI disponíveis.
- A consulta de metadados bruta do NTFS é preservada em `blocos_fsutil.txt`. O valor de blocos de 4 KiB só é derivado quando a saída expõe o tamanho alocado de `$INDEX_ALLOCATION`; quando não for possível interpretar, fica sem valor em vez de ser estimado.
- Médias, desvios padrão e variância amostral devem ser calculados após a coleta e conferidos contra cada rodada individual antes de atualizar gráficos e relatório.

## Referências

- [OSTEP, capítulos 39 e 40](https://pages.cs.wisc.edu/~remzi/OSTEP/)
- [Microsoft: fsutil](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil)
- [Microsoft: fsutil file](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-file)
- [Microsoft: Win32_Battery](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-battery)
- [CPUID HWMonitor](https://www.cpuid.com/softwares/hwmonitor.html)

## Uso de IA

A IA ajudou a organizar a estrutura e preparar o script de coleta. A execução no notebook, as leituras do HWMonitor e a revisão dos resultados devem ser realizadas pelo grupo. Os dados só serão publicados após a conferência dos logs reais.
