#!/usr/bin/env lua

local logger = require("logger")
local extractor = require("extractor")
local builder = require("builder")

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

if not deb_file or not deb_file:match("%,deb$") then
	logger.err("O arquivo forncecido é inválido ou não possui a extensão .deb")
end

local f = io.open(deb_file, "r")
if not f then
	logger.err("Arquivo não encontrado: " .. deb_file)
end
f:close()

local pwd = io.popen("pwd"):read("*l")
local temp_dir = os.tmpname()
os.remove(temp_dir)
os.execute("mkdir -p " .. temp_dir .. "/{src,pkg,control}")

logger.info("Extraindo pacote " .. deb_file .. "...")
extractor.extract(deb_file, temp_dir, pwd, verbose, logger)

logger.info("Lendo metadados (control) ...")
local pkgname, pkgver, arch, pkgdesc, deps = builder.parse_control(temp_dir, deb_file, verbose, logger)

logger.info("Compactando novo pacote pacman...")
local output_pkg = builder.build(temp_dir, pwd, pkgname, pkgver, arch, pkgdesc, deps, verbose, logger)

os.execute("rm -rf " .. temp_dir)

logger.success("Concluído! Pacote criado: " .. logger.color().yellow .. output_pkg)
print("\nInstale com: sudo pacman -U " .. output_pkg)
