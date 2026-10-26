#!/usr/bin/env lua

-- Permite executar o script de qualquer diretório instalando os módulos ao lado dele.
local script_dir = debug.getinfo(1, "S").source:match("^@(.*)[/\\]")
if script_dir and script_dir ~= "" then
	package.path = script_dir .. "/?.lua;" .. package.path
end

local logger = require("logger")
local extractor = require("extractor")
local builder = require("builder")
local utils = require("utils")

local verbose = false
local deb_file = nil

if #arg == 0 then
	logger.err("Nenhum arquivo fornecido. Use -h para ajuda.")
end

for i = 1, #arg do
	if arg[i] == "-h" or arg[i] == "--help" then
		local c = logger.color()
		print(c.bold .. "deb2pacman - Conversor de pacotes Debian para Arch Linux" .. c.reset)
		print("\nUso: lua main.lua [opções] <arquivo.deb>\n")
		print("Opções:")
		print("  -v, --verbose Mostrar saída detalhada (arquivos sendo extraídos)")
		print("  -h, --help    Mostra esta mensagem de ajuda e sai")
		os.exit(0)
	elseif arg[i] == "-v" or arg[i] == "--verbose" then
		verbose = true
	else
		deb_file = arg[i]
	end
end

if not deb_file or not deb_file:lower():match("%.deb$") then
	logger.err("O arquivo fornecido é inválido ou não possui a extensão .deb")
end

local pwd = io.popen("pwd"):read("*l")
local deb_path = utils.to_absolute(deb_file, pwd)

local f = io.open(deb_path, "rb")
if not f then
	logger.err("Arquivo não encontrado: " .. deb_path)
end
f:close()

local temp_dir = os.tmpname()
os.remove(temp_dir)

local q = utils.shell_quote
local ok = os.execute(
	"mkdir -p "
		.. q(temp_dir .. "/src")
		.. " "
		.. q(temp_dir .. "/pkg")
		.. " "
		.. q(temp_dir .. "/control")
)
if ok == nil or ok == false then
	logger.err("Não foi possível criar o diretório temporário: " .. temp_dir)
end

logger.info("Extraindo pacote " .. deb_file .. "...")
extractor.extract(deb_path, temp_dir, verbose, logger)

logger.info("Lendo metadados (control) ...")
local pkgname, pkgver, arch, pkgdesc, deps = builder.parse_control(temp_dir, deb_file, verbose, logger)

logger.info("Compactando novo pacote pacman...")
local output_pkg = builder.build(temp_dir, pwd, pkgname, pkgver, arch, pkgdesc, deps, verbose, logger)

os.execute("rm -rf " .. q(temp_dir))

logger.success("Concluído! Pacote criado: " .. logger.color().yellow .. output_pkg)
print("\nInstale com: sudo pacman -U " .. output_pkg)
