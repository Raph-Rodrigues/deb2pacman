local builder = {}
local translator = require("translator")
local utils = require("utils")

function builder.parse_control(tmp_dir, deb_file, verbose, logger)
	local control_file = io.open(tmp_dir .. "/control/control", "r")
	local pkgname, pkgver, arch, pkgdesc = "pacote-convertido", "1.0-1", "x86_64", "Convertido de " .. deb_file
	local depends_list = {}

	if control_file then
		for line in control_file:lines() do
			if line:match("^Package: (.*)") then
				pkgname = line:match("^Package: (.*)"):lower()
			end
			if line:match("^Version: (.*)") then
				pkgver = line:match("^Version: (.*)"):gsub("-", "_") .. "-1"
			end
			if line:match("^Architecture: (.*)") then
				local a = line:match("^Architecture: (.*)")
				arch = (a == "amd64" and "x86_64" or a == "i386" and "i686" or a == "all" and "any" or a)
			end
			if line:match("^Description: (.*)") then
				pkgdesc = line:match("^Description: (.*)")
			end
			if line:match("^Depends: (.*)") then
				depends_list = translator.translate_deps(line:match("^Depends: (.*)"))
			end
		end
		control_file:close()
	end

	if verbose then
		logger.warn("Metadados encontrados:")
		print("   Nome: " .. pkgname .. "\n   Versão: " .. pkgver .. "\n   Arquitetura: " .. arch)
		print("   Dependências: " .. table.concat(depends_list, ", "))
	end
	return pkgname, pkgver, arch, pkgdesc, depends_list
end

function builder.build(tmp_dir, pwd, pkgname, pkgver, arch, pkgdesc, deps, verbose, logger)
	local pkginfo = io.open(tmp_dir .. "/pkg/.PKGINFO", "w")
	if not pkginfo then
		logger.err("Não foi possível criar o arquivo .PKGINFO")
	end

	pkginfo:write("pkgname = " .. pkgname .. "-bin\n")
	pkginfo:write("pkgver = " .. pkgver .. "\n")
	pkginfo:write("pkgdesc = " .. pkgdesc .. "\n")
	pkginfo:write("arch = " .. arch .. "\n")
	for _, dep in ipairs(deps) do
		pkginfo:write("depend = " .. dep .. "\n")
	end
	pkginfo:write("builddate = " .. os.time() .. "\n")
	pkginfo:close()

	local output_pkg = pkgname .. "-bin-" .. pkgver .. "-" .. arch .. ".pkg.tar.zst"
	local output_path = utils.to_absolute(output_pkg, pwd)
	local bsdtar_cmd = verbose and "bsdtar --zstd -cvf" or "bsdtar --zstd -cf"
	local redirect = verbose and "" or " >/dev/null 2>&1"
	local q = utils.shell_quote

	local ok, _, code = os.execute(
		"cd "
			.. q(tmp_dir .. "/pkg")
			.. " && "
			.. bsdtar_cmd
			.. " "
			.. q(output_path)
			.. " .PKGINFO *"
			.. redirect
	)
	if ok == nil or ok == false or (type(ok) == "number" and ok ~= 0) then
		logger.err("Falha ao criar o pacote final" .. (code and (" (código " .. code .. ")") or ""))
	end

	return output_pkg
end

return builder
