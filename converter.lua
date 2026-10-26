local converter = {}
local extractor = require("extractor")
local builder = require("builder")
local utils = require("utils")

local function prepare_workdir(logger)
	local workdir = utils.make_temp_dir()
	if not workdir then
		logger.err("Não foi possível criar o diretório temporário")
	end

	local q = utils.shell_quote
	local ok = os.execute(
		"mkdir -p "
			.. q(workdir .. "/src")
			.. " "
			.. q(workdir .. "/pkg")
			.. " "
			.. q(workdir .. "/control")
	)

	if ok == nil or ok == false then
		logger.err("Não foi possível preparar o diretório temporário: " .. workdir)
	end

	return workdir
end

local function source_type_for(path, explicit_type)
	if explicit_type and explicit_type ~= "" then
		return explicit_type
	end

	if tostring(path or ""):match("^https?://") then
		return "url"
	end

	return "file"
end

--- Converte um arquivo .deb em um pacote do pacman.
--
-- opts:
--   pwd/output_dir  diretório onde o pacote gerado será salvo
--   source          URL ou caminho original (salvo nos metadados)
--   source_type     "url" ou "file"
--   verbose         mostra a saída detalhada
--   logger          módulo de log
function converter.convert(deb_path, opts)
	opts = opts or {}
	local logger = opts.logger
	if not logger then
		error("converter.convert requer opts.logger")
	end

	local workdir = prepare_workdir(logger)
	local output_dir = opts.output_dir or opts.pwd or "."
	local source = opts.source or deb_path
	local display_name = opts.display_name or deb_path
	local quiet = opts.quiet

	if not quiet then
		logger.info("Extraindo pacote " .. display_name .. "...")
	end
	extractor.extract(deb_path, workdir, opts.verbose, logger)

	if not quiet then
		logger.info("Lendo metadados (control) ...")
	end
	local pkgname, pkgver, arch, pkgdesc, deps, deb_version =
		builder.parse_control(workdir, deb_path, opts.verbose, logger)

	local package_metadata = {
		format = 1,
		pkgname = pkgname .. "-bin",
		deb_package = pkgname,
		deb_version = deb_version,
		pkgver = pkgver,
		source_type = source_type_for(source, opts.source_type),
		source = source,
		converted_at = tostring(os.time()),
	}

	if not quiet then
		logger.info("Compactando novo pacote pacman...")
	end
	local output_pkg =
		builder.build(workdir, output_dir, pkgname, pkgver, arch, pkgdesc, deps, opts.verbose, logger, package_metadata)

	os.execute("rm -rf " .. utils.shell_quote(workdir))

	return {
		pkgname = package_metadata.pkgname,
		deb_package = pkgname,
		deb_version = deb_version,
		pkgver = pkgver,
		arch = arch,
		output_pkg = output_pkg,
		output_path = utils.to_absolute(output_pkg, output_dir),
	}
end

return converter
