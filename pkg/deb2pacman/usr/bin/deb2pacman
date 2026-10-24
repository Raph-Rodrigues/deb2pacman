#!/usr/bin/env lua

-- ==============================================================================
-- 1. CONFIGURAÇÃO VISUAL E FUNÇÕES DE LOG
-- ==============================================================================
-- Tabela com códigos de escape ANSI para adicionar cores às mensagens do terminal.
local c = {
	reset = "\27[0m",
	green = "\27[32m",
	blue = "\27[34m",
	red = "\27[31m",
	yellow = "\27[33m",
	bold = "\27[1m",
}

-- Funções auxiliares para padronizar as mensagens exibidas ao usuário.
local function info(msg)
	print(c.blue .. c.bold .. ":: " .. c.reset .. c.bold .. msg .. c.reset)
end
local function success(msg)
	print(c.green .. c.bold .. "=> " .. c.reset .. c.bold .. msg .. c.reset)
end
local function err(msg)
	print(c.red .. c.bold .. "ERRO: " .. c.reset .. msg)
	os.exit(1)
end

-- ==============================================================================
-- 2. LEITURA E TRATAMENTO DOS ARGUMENTOS DA CLI
-- ==============================================================================
local verbose = false
local deb_file = nil

-- Verifica se o usuário não passou nenhum argumento.
if #arg == 0 then
	err("Nenhum arquivo fornecido! Use -h para ajuda.")
end

-- Itera sobre todos os argumentos passados no terminal.
for i = 1, #arg do
	if arg[i] == "-h" or arg[i] == "--help" then
		-- Exibe o menu de ajuda e encerra o script.
		print(c.bold .. "deb2pacman - Conversor de pacotes Debian para distros base Arch Linux" .. c.reset)
		print("\nUso: deb2pacman [opções] <arquivo.deb>\n")
		print("Opções:")
		print(" -v, --verbose Mostrar saída detalhada (arquivos sendo extraídos)")
		print(" -h, --help    Mostra esta mensagem de ajuda e encerra o CLI")
		os.exit(0)
	elseif arg[i] == "-v" or arg[i] == "--verbose" then
		-- Ativa o modo de log detalhado.
		verbose = true
	else
		-- Se não for uma flag conhecida, assume que é o caminho do arquivo .deb.
		deb_file = arg[i]
	end
end

-- ==============================================================================
-- 3. VALIDAÇÃO DO ARQUIVO DE ENTRADA
-- ==============================================================================
-- Garante que um arquivo foi definido.
if not deb_file then
	err("Nenhum arquivo .deb fornecido!")
end

-- Verifica se o nome do arquivo termina com a extensão '.deb'.
if not deb_file:match("%.deb$") then
	err("O arquivo fornecido não possui extensão .deb (" .. deb_file .. ")")
end

-- Tenta abrir o arquivo no modo leitura ("r") para confirmar que ele existe.
local f = io.open(deb_file, "r")
if not f then
	err("Arquivo não encontrado: " .. deb_file)
end
f:close()

-- ==============================================================================
-- 4. MAPEAMENTO DE DEPENDÊNCIAS (Debian -> Arch)
-- ==============================================================================
-- Nomes de pacotes variam entre as distribuições. Este dicionário converte
-- os nomes das dependências comuns do ecossistema Debian para o Arch Linux.
local dep_map = {
	["libc6"] = "glibc",
	["python3"] = "python",
	["libgtk-3-0"] = "gtk3",
	["libasound2"] = "alsa-lib",
	["libx11-6"] = "libx11",
	["libnss3"] = "nss",
	["zlib1g"] = "zlib",
}

-- ==============================================================================
-- 5. PREPARAÇÃO DO AMBIENTE TEMPORÁRIO
-- ==============================================================================
-- Captura o diretório atual de onde o script foi executado.
local pwd = io.popen("pwd"):read("*l")

-- Cria um nome de diretório temporário seguro no sistema.
local tmp_dir = os.tmpname()
os.remove(tmp_dir) -- Remove o arquivo criado pelo os.tmpname para recriá-lo como pasta.

-- Cria a estrutura de pastas temporárias necessárias para a extração:
-- /src (arquivo deb original extraído), /pkg (arquivos do sistema), /control (metadados).
os.execute("mkdir -p " .. tmp_dir .. "/{src,pkg,control}")
info("Extraindo pacote " .. deb_file .. "...")

-- ==============================================================================
-- 6. EXTRAÇÃO DOS ARQUIVOS DO PACOTE (.deb)
-- ==============================================================================
-- Um pacote .deb é, na verdade, um arquivo 'ar' que contém arquivos compactados.
-- Definimos as flags dos comandos de extração com base no modo verbose.
local ar_cmd = verbose and "ar xv" or "ar x"
local tar_cmd = verbose and "tar -xvf" or "tar -xf"
local redirect = verbose and "" or " >/dev/null 2>&1"

if verbose then
	print(c.yellow .. "-> Extraindo contêiner AR..." .. c.reset)
end
-- Extrai o conteúdo do .deb (data.tar, control.tar, debian-binary) para a pasta /src.
os.execute("cd " .. tmp_dir .. "/src && " .. ar_cmd .. " " .. pwd .. "/" .. deb_file .. redirect)

if verbose then
	print(c.yellow .. "-> Extraindo arquivos de dados..." .. c.reset)
end
-- Extrai os binários e arquivos que serão instalados no sistema para a pasta /pkg.
os.execute("cd " .. tmp_dir .. "/pkg && " .. tar_cmd .. " ../src/data.tar.*" .. redirect)

if verbose then
	print(c.yellow .. "-> Extraindo metadados de controle..." .. c.reset)
end
-- Extrai os arquivos de configuração do pacote Debian para a pasta /control.
os.execute("cd " .. tmp_dir .. "/control && " .. tar_cmd .. " ../src/control.tar.*" .. redirect)

-- ==============================================================================
-- 7. PARSER DOS METADADOS DEBIAN
-- ==============================================================================
info("Lendo metadados (control)...")
-- Abre o arquivo 'control', que guarda as informações do pacote Debian.
local control_file = io.open(tmp_dir .. "/control/control", "r")

-- Valores padrão caso alguma informação não seja encontrada.
local pkgname, pkgver, arch, pkgdesc = "pacote-convertido", "1.0-1", "x86_64", "Convertido de " .. deb_file
local depends_list = {}

if control_file then
	-- Lê o arquivo linha por linha buscando pelas chaves específicas.
	for line in control_file:lines() do
		if line:match("^Package: (.*)") then
			pkgname = line:match("^Package: (.*)"):lower()
		end

		if line:match("^Version: (.*)") then
			-- O Arch Linux não aceita hífens na versão principal do pacote.
			-- Trocamos hífens por underlines (_) e adicionamos '-1' (pkgrel).
			pkgver = line:match("^Version: (.*)"):gsub("-", "_") .. "-1"
		end

		if line:match("^Architecture: (.*)") then
			-- Mapeia a arquitetura do Debian para o padrão do Arch.
			local a = line:match("^Architecture: (.*)")
			arch = (a == "amd64" and "x86_64" or a == "i386" and "i686" or a == "all" and "any" or a)
		end

		if line:match("^Description: (.*)") then
			pkgdesc = line:match("^Description: (.*)")
		end

		if line:match("^Depends: (.*)") then
			-- Processa a linha de dependências separando por vírgulas.
			for dep in line:match("^Depends: (.*)"):gmatch("([^,]+)") do
				-- Limpa espaços e remove as especificações de versão (ex: "(>= 2.1)").
				local clean_dep = dep:gsub("%(.-%)", ""):gsub("%s+", "")

				if clean_dep ~= "" then
					-- Traduz a dependência se ela existir no nosso mapa (dep_map).
					local arch_dep = dep_map[clean_dep] or clean_dep

					-- Verifica se a dependência já foi adicionada para evitar duplicatas.
					local exists = false
					for _, v in ipairs(depends_list) do
						if v == arch_dep then
							exists = true
							break
						end
					end
					if not exists then
						table.insert(depends_list, arch_dep)
					end
				end
			end
		end
	end
	control_file:close()

	-- Exibe os metadados extraídos se o modo verbose estiver ativo.
	if verbose then
		print(c.yellow .. "-> Metadados encontrados:" .. c.reset)
		print("   Nome: " .. pkgname)
		print("   Versão: " .. pkgver)
		print("   Arquitetura: " .. arch)
		print("   Dependências: " .. table.concat(depends_list, ", "))
	end
end

-- ==============================================================================
-- 8. GERAÇÃO DO ARQUIVO DE CONTROLE DO ARCH LINUX (.PKGINFO)
-- ==============================================================================
info("Gerando .PKGINFO para o Arch...")
-- O pacman utiliza um arquivo oculto chamado .PKGINFO na raiz do pacote.
local pkginfo = io.open(tmp_dir .. "/pkg/.PKGINFO", "w")

-- Escreve as variáveis do pacote traduzidas. Adicionamos '-bin' ao nome
-- para seguir o padrão do AUR de pacotes binários pré-compilados.
pkginfo:write("pkgname = " .. pkgname .. "-bin\n")
pkginfo:write("pkgver = " .. pkgver .. "\n")
pkginfo:write("pkgdesc = " .. pkgdesc .. "\n")
pkginfo:write("arch = " .. arch .. "\n")

-- Escreve cada dependência linha por linha usando a chave 'depend'.
for _, dep in ipairs(depends_list) do
	pkginfo:write("depend = " .. dep .. "\n")
end

-- Marca a data atual de criação do pacote (Unix timestamp).
pkginfo:write("builddate = " .. os.time() .. "\n")
pkginfo:close()

-- ==============================================================================
-- 9. EMPACOTAMENTO FINAL E LIMPEZA
-- ==============================================================================
-- Define o nome do pacote de saída seguindo a nomenclatura do Arch.
local output_pkg = pkgname .. "-bin-" .. pkgver .. "-" .. arch .. ".pkg.tar.zst"

info("Compactando novo pacote pacman...")
-- Compacta a pasta de arquivos (/pkg) junto com o .PKGINFO gerado.
-- Usa o bsdtar com compressão zstd (padrão atual do pacman).
local bsdtar_cmd = verbose and "bsdtar --zstd -cvf" or "bsdtar --zstd -cf"
os.execute("cd " .. tmp_dir .. "/pkg && " .. bsdtar_cmd .. " " .. pwd .. "/" .. output_pkg .. " .PKGINFO *" .. redirect)

-- Exclui a pasta temporária do sistema.
os.execute("rm -rf " .. tmp_dir)

-- ==============================================================================
-- 10. MENSAGEM DE CONCLUSÃO
-- ==============================================================================
success("Concluído! Pacote criado: " .. c.yellow .. output_pkg)
print("\nInstale com: sudo pacman -U " .. output_pkg)
