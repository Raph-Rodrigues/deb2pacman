# 📦 deb2pacman
<div align="center">
 
**Converta pacotes Debian (`.deb`) em pacotes nativos do Arch Linux (`.pkg.tar.zst`) com um único comando.**
 
![Lua](https://img.shields.io/badge/Lua-5.x-2C2D72?logo=lua&logoColor=white)
![Arch Linux](https://img.shields.io/badge/Arch%20Linux-pacman-1793D1?logo=archlinux&logoColor=white)
![Plataforma](https://img.shields.io/badge/plataforma-Linux-informational)
![Interface](https://img.shields.io/badge/interface-CLI-success)
 
</div>

---
 
## 📑 Sumário
 
- [Visão geral](#-visão-geral)
- [Funcionalidades](#-funcionalidades)
- [Requisitos](#-requisitos)
- [Instalação](#-instalação)
- [Uso](#-uso)
- [Atualização de pacotes](#-atualização-de-pacotes)
- [Exemplo completo](#-exemplo-completo)
- [Como funciona](#️-como-funciona)
- [Regras de conversão](#-regras-de-conversão)
- [Estrutura do pacote gerado](#-estrutura-do-pacote-gerado)
- [Personalizando o mapa de dependências](#-personalizando-o-mapa-de-dependências)
- [Versionamento e release](#-versionamento-e-release)
- [Limitações conhecidas](#️-limitações-conhecidas)
- [Códigos de saída](#-códigos-de-saída)
---
 
## 🔎 Visão geral
 
O **deb2pacman** é um utilitário de linha de comando, escrito em Lua e organizado em módulos, que pega um arquivo `.deb` (formato de pacote do Debian, Ubuntu e derivados) e produz um pacote `.pkg.tar.zst` que pode ser instalado diretamente com `pacman -U`.
 
Ele **não recompila nada**: os binários e arquivos do programa são reaproveitados como estão. O script apenas extrai o conteúdo do `.deb`, traduz os metadados (nome, versão, arquitetura, descrição e dependências) para o formato que o `pacman` entende e reempacota tudo.
 
> 💡 Ideal para programas distribuídos apenas como `.deb` (navegadores, editores, ferramentas proprietárias) quando você quer que o `pacman` os gerencie, em vez de instalá-los "por fora" do gerenciador de pacotes.
 
---
 
## 🌟 Funcionalidades
 
| Recurso | Descrição |
| --- | --- |
| 🗜️ **Extração automática** | Abre o contêiner `ar` do `.deb` e descompacta `data.tar.*` (arquivos do programa) e `control.tar.*` (metadados), em qualquer compressão que o `tar` suporte (`.gz`, `.xz`, `.zst`…). |
| 🧾 **Leitura do `control`** | Extrai `Package`, `Version`, `Architecture`, `Description` e `Depends` do arquivo de controle do Debian. |
| 🔁 **Tradução de arquitetura** | `amd64` → `x86_64`, `i386` → `i686`, `all` → `any`. |
| 🔢 **Adaptação de versão** | Troca `-` por `_` na versão (o Arch não aceita hífen no `pkgver`) e acrescenta `-1` como `pkgrel`. |
| 🧩 **Tradução de dependências** | Converte nomes de pacotes Debian para Arch por meio de um dicionário (`dep_map`), remove restrições de versão e elimina duplicatas. |
| 📝 **Geração de `.PKGINFO`** | Cria o arquivo de metadados nativo do `pacman` na raiz do pacote. |
| 📦 **Empacotamento com zstd** | Gera o `.pkg.tar.zst` com `bsdtar` + compressão Zstandard, o padrão atual do `pacman`. |
| 🔊 **Modo verbose** | `-v` / `--verbose` mostra cada etapa, cada arquivo extraído/empacotado e os metadados encontrados. |
| 🔄 **Atualização assistida** | `-u` / `--update` lista os pacotes convertidos instalados, baixa as versões mais recentes e instala as atualizações com `pacman -U`. |
| 🏷️ **Metadados de origem** | Cada pacote gerado inclui um marcador em `/usr/share/deb2pacman/` com o nome Debian, a versão e a URL de origem. |
| 🌐 **Fontes configuráveis** | Fontes conhecidas para Chrome, VS Code e Discord, com suporte a URLs extras em `~/.config/deb2pacman/sources.conf`. |
| 🎨 **Interface colorida** | Mensagens com cores ANSI no estilo do `pacman` e tratamento de erros com código de saída. |
| 🧹 **Limpeza automática** | Todo o trabalho é feito em um diretório temporário, removido ao final. |
 
---
 
## 📦 Requisitos
 
| Pacote (Arch) | Fornece | Para que serve |
| --- | --- | --- |
| `lua` | `lua` | Interpretador que executa o script |
| `binutils` | `ar` | Abrir o contêiner do `.deb` |
| `tar` | `tar` | Extrair `data.tar.*` e `control.tar.*` |
| `libarchive` | `bsdtar` | Criar o pacote final com compressão zstd |
| `zstd` | `zstd` | Compressão do pacote final (e leitura de `.deb` com `data.tar.zst`) |
| `xz` | `xz` | Leitura de `.deb` com `data.tar.xz` *(normalmente já instalado)* |
| `curl` | `curl` | Baixar os `.deb` mais recentes no modo de atualização (`-u`) |

Além disso, o script usa `/bin/sh` com suporte a *brace expansion* (`{a,b,c}`), o que é o caso do Arch Linux, onde `/bin/sh` é o Bash. O modo de atualização também usa `pacman` (para `pacman -U` e `vercmp`) e `sudo` quando executado por um usuário comum.

Instale tudo com:

```bash
sudo pacman -S --needed lua binutils tar libarchive zstd xz curl
```
 
---
 
## 🚀 Instalação

O programa é dividido em `main.lua` e nos módulos `logger.lua`, `extractor.lua`, `builder.lua`, `translator.lua`, `utils.lua`, `converter.lua`, `metadata.lua`, `sources.lua` e `updater.lua`. O instalador copia todos eles para `/usr/local/lib/deb2pacman` e cria o comando `deb2pacman` em `/usr/local/bin`.

```bash
# 1. Clone o repositório
git clone <url-do-repositorio> deb2pacman
cd deb2pacman

# 2. Instale as dependências e os arquivos (usa os arquivos locais)
sudo ./install.sh
```

Também é possível instalar a versão da branch `main` diretamente pela internet:

```bash
curl -fsSL https://raw.githubusercontent.com/Raph-Rodrigues/deb2pacman/refs/heads/main/install.sh | sudo bash
```

Para desinstalar:

```bash
sudo rm -rf /usr/local/bin/deb2pacman /usr/local/lib/deb2pacman
```

> Se preferir não instalar, basta executar direto do repositório: `lua main.lua arquivo.deb`.
 
---
 
## 💻 Uso
 
```text
deb2pacman [opções] <arquivo.deb>
deb2pacman -u [opções]
```
 
### Opções
 
| Opção | Descrição |
| --- | --- |
| `-u`, `--update` | Lista os pacotes convertidos instalados e atualiza todos para a versão mais recente. |
| `-s`, `--source-url URL` | Salva a URL do `.deb` de origem para permitir atualizações futuras. |
| `-y`, `--yes` | Não pede confirmação antes de instalar as atualizações (use com `-u`). |
| `-v`, `--verbose` | Mostra saída detalhada: arquivos sendo extraídos/empacotados e metadados lidos. |
| `-h`, `--help` | Exibe o menu de ajuda e encerra. |
 
### Exemplos
 
```bash
# Conversão simples
deb2pacman google-chrome-stable_current_amd64.deb
 
# Conversão salvando a URL de origem para atualizações futuras
deb2pacman --source-url https://exemplo.com/app-latest.deb app_1.0_amd64.deb

# Listar os pacotes convertidos instalados e atualizar todos
deb2pacman -u

# Atualizar sem pedir confirmação
deb2pacman -u --yes

# Conversão com saída detalhada
deb2pacman -v google-chrome-stable_current_amd64.deb
 
# Ajuda
deb2pacman -h
```
 
### Instalando o pacote convertido
 
O pacote é criado no **diretório atual**. Instale-o com:
 
```bash
sudo pacman -U nome-do-pacote-bin-<versão>-<arquitetura>.pkg.tar.zst
```
 
---
 
## 🔄 Atualização de pacotes

O modo `-u`/`--update` procura os pacotes convertidos pelo deb2pacman que estão instalados no sistema, mostra a versão instalada e tenta atualizar todos para a versão mais recente disponível na fonte configurada.

```console
$ deb2pacman -u
:: Pacotes .deb convertidos e instalados no sistema:
  google-chrome-stable-bin        131.0.6778.85-1      fonte: embutida
  uaitex-bin                      1.2.9-1              sem fonte de atualização
    Adicione uma URL em /home/usuario/.config/deb2pacman/sources.conf

:: Verificando google-chrome-stable-bin...
  google-chrome-stable-bin: 131.0.6778.85-1 -> 132.0.6834.83-1
:: Instalando pacotes atualizados...
=> Atualização concluída: 1 pacote(s).
```

O fluxo geral é:

1. resolver a fonte de cada pacote (configuração, metadados do pacote, fonte embutida ou arquivo local);
2. baixar o `.deb` mais recente com `curl`;
3. converter para um diretório temporário;
4. comparar as versões com `vercmp`;
5. pedir confirmação (ou seguir direto com `--yes`);
6. instalar todos os pacotes mais novos com `sudo pacman -U --noconfirm`.

> Execute `deb2pacman -u` como usuário comum. O `sudo` é chamado apenas na etapa final de instalação; assim o programa consegue ler o seu `sources.conf`.

### Escolha da fonte

A URL é procurada nesta ordem:

1. `~/.config/deb2pacman/sources.conf` (ou `$XDG_CONFIG_HOME/deb2pacman/sources.conf`);
2. URL salva no marcador do pacote com `--source-url`;
3. fonte conhecida embutida para Google Chrome, VS Code e Discord;
4. caminho local do `.deb` usado na conversão, se o arquivo ainda existir.

### Configurando fontes

Para apps que não têm fonte embutida, crie o arquivo `~/.config/deb2pacman/sources.conf`:

```ini
# chave=URL do .deb mais recente
uaitex=https://exemplo.com/uaitex-latest-amd64.deb
meu-app=https://exemplo.com/meu-app-latest-amd64.deb
```

A chave pode ser o nome Debian (`uaitex`) ou o nome instalado no Arch (`uaitex-bin`). Prefira uma URL que **sempre aponte para a versão mais recente**; URLs que contêm a versão (`app_1.2.3_amd64.deb`) precisam ser atualizadas manualmente na configuração a cada release.

### Pacotes convertidos por versões antigas

Pacotes novos incluem o marcador `/usr/share/deb2pacman/<pkgname>.meta`. Pacotes convertidos antes desse recurso não têm o marcador; o modo de atualização tenta detectá-los por heurística (nome terminado em `-bin`, sem URL, sem repositório de origem e sem validação). Eles aparecem na lista como "sem fonte de atualização" até você adicionar uma URL em `sources.conf` ou reconvertê-los com `--source-url`.

---

## 🧪 Exemplo completo
 
```console
$ deb2pacman google-chrome-stable_current_amd64.deb
:: Extraindo pacote google-chrome-stable_current_amd64.deb...
:: Lendo metadados (control)...
:: Compactando novo pacote pacman...
=> Concluído! Pacote criado: google-chrome-stable-bin-130.0.6723.91_1-1-x86_64.pkg.tar.zst
 
Instale com: sudo pacman -U google-chrome-stable-bin-130.0.6723.91_1-1-x86_64.pkg.tar.zst
```
 
Como o nome do arquivo de saída é montado:
 
```text
google-chrome-stable  -bin  -130.0.6723.91_1  -1      -x86_64  .pkg.tar.zst
└──── Package ───────┘ └─┬─┘ └──── Version ───┘ └pkgrel┘ └─ arch ┘
                         └ sufixo adicionado pelo script
```
 
---
 
## ⚙️ Como funciona
 
```mermaid
flowchart TD
    A[arquivo.deb] --> B[Validação<br/>extensão .deb + arquivo existe]
    B --> C[Diretório temporário<br/>src / pkg / control]
    C --> D["ar x → data.tar.* + control.tar.*"]
    D --> E["tar -xf data.tar.* → pkg/"]
    D --> F["tar -xf control.tar.* → control/"]
    F --> G[Parser do arquivo control<br/>Package · Version · Architecture<br/>Description · Depends]
    G --> H[Tradução<br/>arquitetura · versão · dependências]
    H --> I["Gera .PKGINFO + marcador de origem"]
    E --> J
    I --> J["bsdtar --zstd → .pkg.tar.zst"]
    J --> K[Remove diretório temporário]
    K --> L[Pacote pronto no diretório atual]
```
 
### Passo a passo
 
1. **Argumentos e validação:** lê as opções, confirma que um arquivo foi informado, que ele termina em `.deb` e que pode ser aberto.
2. **Ambiente temporário:** cria um diretório único (via `os.tmpname()`) com as subpastas `src/`, `pkg/` e `control/`.
3. **Extração:**
   - `ar x` abre o `.deb` em `src/`;
   - `tar -xf src/data.tar.*` extrai os arquivos do programa em `pkg/`;
   - `tar -xf src/control.tar.*` extrai os metadados em `control/`.
4. **Parser do `control`:** lê o arquivo linha a linha e coleta as informações relevantes. Se o arquivo não for encontrado, são usados valores padrão (veja [limitações](#️-limitações-conhecidas)).
5. **Tradução:** ajusta arquitetura, versão e dependências para o padrão do Arch.
6. **Geração dos metadados:** escreve o `.PKGINFO` e o marcador `/usr/share/deb2pacman/<pkgname>.meta` dentro de `pkg/`, com a versão Debian e a fonte usada.
7. **Empacotamento:** `bsdtar --zstd` compacta o conteúdo de `pkg/` (incluindo o `.PKGINFO` e o marcador) no diretório de onde o comando foi executado.
8. **Limpeza:** o diretório temporário é apagado.
---
 
## 🔄 Regras de conversão
 
### Metadados
 
| Campo no Debian (`control`) | Campo no Arch (`.PKGINFO`) | Regra aplicada |
| --- | --- | --- |
| `Package: nome` | `pkgname` | Convertido para minúsculas e acrescido do sufixo `-bin` (convenção do AUR para binários pré-compilados). |
| `Version: 1.0-2` | `pkgver` | Hífens viram `_` e `-1` é acrescentado: `1.0_2-1`. |
| `Architecture` | `arch` | `amd64` → `x86_64`, `i386` → `i686`, `all` → `any`; outros valores são mantidos como estão. |
| `Description` | `pkgdesc` | Apenas a primeira linha (resumo) é usada. |
| `Depends` | `depend` (uma linha por dependência) | Veja abaixo. |
| — | `builddate` | Timestamp Unix do momento da conversão. |
| `Package`, `Version`, arquivo/URL de origem | `/usr/share/deb2pacman/<pkgname>.meta` | Marcador usado pelo modo `-u` para saber a origem e a versão Debian. |
 
**Valores padrão** (usados se o `control` não for lido): `pkgname = pacote-convertido`, `pkgver = 1.0-1`, `arch = x86_64`, `pkgdesc = Convertido de <arquivo.deb>`.
 
### Dependências
 
Cada item do campo `Depends:` passa por este processamento:
 
1. A lista é separada por vírgulas.
2. Restrições de versão entre parênteses são removidas: `libfoo (>= 2.1)` → `libfoo`.
3. Espaços são removidos.
4. O nome é traduzido pelo `dep_map`; se não houver entrada, **o nome original é mantido**.
5. Duplicatas são descartadas.
Mapeamentos incluídos por padrão:
 
| Debian | Arch Linux |
| --- | --- |
| `libc6` | `glibc` |
| `python3` | `python` |
| `libgtk-3-0` | `gtk3` |
| `libasound2` | `alsa-lib` |
| `libx11-6` | `libx11` |
| `libnss3` | `nss` |
| `zlib1g` | `zlib` |
 
---
 
## 🗂️ Estrutura do pacote gerado
 
O `.pkg.tar.zst` contém exatamente a árvore de arquivos do `data.tar.*` do `.deb` (por exemplo `usr/`, `opt/`, `etc/`), mais o `.PKGINFO` na raiz e o marcador de origem em `usr/share/deb2pacman/`:
 
```text
.PKGINFO
opt/
usr/
usr/share/deb2pacman/google-chrome-stable-bin.meta
...
```
 
Exemplo de `.PKGINFO` gerado:
 
```ini
pkgname = google-chrome-stable-bin
pkgver = 130.0.6723.91_1-1
pkgdesc = The web browser from Google
arch = x86_64
depend = glibc
depend = alsa-lib
depend = libx11
builddate = 1767225600
```
 
Exemplo do marcador de origem:

```ini
format=1
pkgname=google-chrome-stable-bin
deb_package=google-chrome-stable
deb_version=130.0.6723.91-1
pkgver=130.0.6723.91_1-1
source_type=url
source=https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
converted_at=1767225600
```

Para inspecionar o resultado antes de instalar:
 
```bash
pacman -Qip nome-do-pacote.pkg.tar.zst   # metadados e dependências
pacman -Qlp nome-do-pacote.pkg.tar.zst   # lista de arquivos
```
 
---
 
## 🧩 Personalizando o mapa de dependências
 
Se o pacote convertido pedir uma dependência que não existe no Arch, adicione a tradução no dicionário `dep_map` do script:
 
```lua
local dep_map = {
	["libc6"] = "glibc",
	["python3"] = "python",
	-- ...
	["libgbm1"] = "mesa",           -- exemplo de nova entrada
	["libxss1"] = "libxss",         -- exemplo de nova entrada
}
```
 
Dica: use `pacman -F <arquivo.so>` (após `sudo pacman -Fy`) para descobrir qual pacote do Arch fornece uma biblioteca.
 
---
 
## 🔖 Versionamento e release

O `PKGBUILD` baixa automaticamente o tarball da tag `v${pkgver}` do GitHub. Para não editar a versão à mão, use o script `bump-version.sh`:

```bash
./bump-version.sh                 # 1.0.4 -> 1.0.5 (patch)
./bump-version.sh minor           # 1.0.4 -> 1.1.0
./bump-version.sh major           # 1.0.4 -> 2.0.0
./bump-version.sh set 3.2.1       # define uma versão específica
```

O script também zera o `pkgrel` e atualiza o `.SRCINFO` quando ele existir. Para criar o commit e a tag de release:

```bash
# 1. Commit primeiro as alterações de código
git add .
git commit -m "fix: ..."

# 2. Incrementa a versão, commita o PKGBUILD e cria a tag vX.Y.Z
./bump-version.sh patch --commit --tag

# 3. Envia o commit e a tag (a tag dispara o workflow de release)
git push origin HEAD --follow-tags
```

Ou use `./bump-version.sh patch --commit --tag --push` para fazer tudo de uma vez. O workflow `.github/workflows/release.yaml` compila o pacote e publica o `.pkg.tar.zst` na release da tag.

### Build local com makepkg

```bash
makepkg -si
```

Todos os artefatos do build ficam dentro de `build/`:

```text
build/
├── deb2pacman-1.0.4-1-any.pkg.tar.zst
├── deb2pacman/
│   ├── src/   # fontes extraídas
│   └── pkg/   # árvore de arquivos do pacote
├── logs/
└── sources/
```

---

## ⚠️ Limitações conhecidas
 
O deb2pacman faz uma conversão **direta e simples**; ele não substitui o trabalho de um `PKGBUILD` bem feito. Tenha em mente:
 
**Conteúdo do pacote**
- 🖥️ Arquivos `.desktop` podem apontar para caminhos ou binários que não existem ou têm nomes diferentes no Arch.
- 📜 Scripts do Debian (`preinst`, `postinst`, `prerm`, `postrm`) **não são convertidos** para `.INSTALL`.
- 🗃️ Arquivos de configuração (`conffiles`) não viram `backup=`, e o `.MTREE` não é gerado.
- 📁 Pacotes Debian que instalam diretamente em `/bin`, `/sbin` ou `/lib` podem entrar em conflito com o pacote `filesystem` do Arch (que usa links simbólicos para `/usr`).
**Dependências**
- 🔍 Dependências sem entrada no `dep_map` são copiadas com o nome Debian e podem não existir no Arch.
- ➗ Apenas o campo `Depends` é lido (`Pre-Depends`, `Recommends`, `Suggests` etc. são ignorados).
- 🔀 Alternativas (`pacote-a | pacote-b`) e qualificadores (`pacote:any`) não são tratados.
- 🔢 Restrições de versão são descartadas.
**Execução**
- 📂 Caminhos relativos e absolutos são aceitos, inclusive com espaços no nome do arquivo.
- 🧪 Se o arquivo `control` não existir após a extração, o script usa valores padrão (pacote chamado `pacote-convertido-bin`).
- ♻️ Se vários arquivos forem passados, apenas o **último** é convertido.
- 🏗️ Arquiteturas fora de `amd64`, `i386` e `all` (ex.: `arm64`) são mantidas com o nome do Debian, que o Arch não reconhece (`aarch64`).
- 📛 O pacote **sempre** recebe o sufixo `-bin` e `pkgrel` fixo em `1`.
**Atualizações**
- 🌐 O deb2pacman não descobre sozinho o link de download de qualquer aplicativo. Use `--source-url` na conversão ou cadastre o app em `~/.config/deb2pacman/sources.conf`.
- 📦 As fontes embutidas cobrem apenas Google Chrome, VS Code e Discord. Outros aplicativos precisam de uma URL configurada.
- 🔗 A URL precisa apontar para o `.deb` mais recente. Links que mudam a cada versão exigem atualização manual do `sources.conf`.
- 🕰️ Pacotes convertidos antes da existência dos metadados podem não ser detectados, ou aparecer como "sem fonte de atualização" até receberem uma URL.
- 🔢 A comparação usa `vercmp` do pacman. Épocas Debian (`1:2.0`) e versões muito incomuns podem não ser comparadas corretamente.
- 📁 Se a fonte for um arquivo local, ele não é baixado de novo: a atualização só acontece se o arquivo tiver sido substituído manualmente.
- 🔐 A instalação final usa `sudo pacman -U --noconfirm`; revise a lista antes de confirmar (ou evite `--yes` em ambientes não confiáveis).
> ✅ Antes de instalar, revise o `.PKGINFO` e a lista de arquivos do pacote gerado, especialmente se o `.deb` veio de uma fonte que você não conhece.
 
---
 
## 🚦 Códigos de saída
 
| Código | Situação |
| --- | --- |
| `0` | Conversão concluída com sucesso, atualização concluída/cancelada, ou ajuda exibida (`-h`). |
| `1` | Erro: nenhum argumento, arquivo não informado, extensão diferente de `.deb`, arquivo não encontrado, falha ao baixar/converter/instalar ou opções inválidas. |
 
---
 
<div align="center">
Feito em Lua 🌙 para quem quer o melhor dos dois mundos: pacotes `.deb` e a organização do `pacman`.
 
</div>

