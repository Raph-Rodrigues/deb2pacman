#!/usr/bin/env lua

-- Permite executar o script de qualquer diretório instalando os módulos ao lado dele.
local script_dir = debug.getinfo(1, "S").source:match("^@(.*)[/\\]")
if script_dir and script_dir ~= "" then
	package.path = script_dir .. "/?.lua;" .. package.path
end

local logger = require("logger")
local converter = require("converter")
local updater = require("updater")
local sources = require("sources")
local utils = require("utils")

local verbose = false
local deb_file = nil
local mode = "convert"
local source_url = nil
local assume_yes = false

if #arg == 0 then
	logger.err("Nenhum arquivo fornecido. Use -h para ajuda.")
end

local function print_help()
	local c = logger.color()
	print(c.bold .. "deb2pacman - Conversor de pacotes Debian para Arch Linux" .. c.reset)
	print("\nUso:")
	print("  deb2pacman [opções] <arquivo.deb>")
	print("  deb2pacman -u [opções]\n")
	print("Opções:")
	print("  -u, --update          Lista os pacotes convertidos instalados e atualiza todos")
	print("  -s, --source-url URL  URL do .deb original (salva para atualizações futuras)")
	print("  -y, --yes             Atualiza sem pedir confirmação (use com -u)")
	print("  -v, --verbose         Mostrar saída detalhada")
	print("  -h, --help            Mostra esta mensagem de ajuda e sai")
	print("\nFontes de atualização: " .. sources.config_path())
end

local index = 1
while index <= #arg do
	local current = arg[index]

	if current == "-h" or current == "--help" then
		print_help()
		os.exit(0)
	elseif current == "-v" or current == "--verbose" then
		verbose = true
	elseif current == "-u" or current == "--update" then
		mode = "update"
	elseif current == "-y" or current == "--yes" then
		assume_yes = true
	elseif current == "-s" or current == "--source-url" then
		index = index + 1
		source_url = arg[index]
		if not source_url or source_url == "" then
			logger.err("A opção --source-url requer uma URL")
		end
	elseif current:match("^%-%-source%-url=") then
		source_url = current:match("^%-%-source%-url=(.*)$")
		if not source_url or source_url == "" then
			logger.err("A opção --source-url requer uma URL")
		end
	elseif current:sub(1, 1) == "-" then
		logger.err("Opção desconhecida: " .. current)
	else
		if deb_file then
			logger.err("Apenas um arquivo .deb pode ser convertido por vez")
		end
		deb_file = current
	end

	index = index + 1
end

if mode == "update" then
	if deb_file then
		logger.err("A opção -u/--update não aceita um arquivo .deb")
	end
	if source_url then
		logger.err("A opção --source-url só pode ser usada ao converter um .deb")
	end

	updater.run({
		verbose = verbose,
		yes = assume_yes,
		logger = logger,
	})
	os.exit(0)
end

if assume_yes then
	logger.err("A opção --yes só pode ser usada com -u/--update")
end

if not deb_file or not deb_file:lower():match("%.deb$") then
	logger.err("O arquivo fornecido é inválido ou não possui a extensão .deb")
end

if source_url and not source_url:match("^[%a][%w+.-]*://") then
	logger.err("URL de origem inválida: " .. source_url)
end

local pwd_pipe = io.popen("pwd")
local pwd = pwd_pipe:read("*l")
pwd_pipe:close()

local deb_path = utils.to_absolute(deb_file, pwd)
if not utils.file_exists(deb_path) then
	logger.err("Arquivo não encontrado: " .. deb_path)
end

local result = converter.convert(deb_path, {
	output_dir = pwd,
	source = source_url or deb_path,
	source_type = source_url and "url" or "file",
	display_name = deb_file,
	verbose = verbose,
	logger = logger,
})

logger.success("Concluído! Pacote criado: " .. logger.color().yellow .. result.output_pkg)
print("\nInstale com: sudo pacman -U " .. utils.shell_quote(result.output_pkg))
if source_url then
	print("Fonte salva para atualizações: " .. source_url)
end
