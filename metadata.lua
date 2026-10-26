local metadata = {}
local utils = require("utils")

-- Onde o marcador fica dentro do pacote gerado.
metadata.PACKAGE_DIR = "/usr/share/deb2pacman"

-- Locais consultados no sistema para descobrir pacotes instalados.
metadata.INSTALL_DIR = "/usr/share/deb2pacman"
metadata.LOCAL_DB = "/var/lib/pacman/local"

local function value_is_empty(value)
	return value == nil or utils.trim(value) == ""
end

--- Lê um arquivo de metadados no formato chave=valor.
function metadata.parse_file(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end

	local data = {}
	for line in file:lines() do
		if line ~= "" and not line:match("^%s*#") then
			local key, value = line:match("^([^=]+)=(.*)$")
			if key then
				data[utils.trim(key)] = utils.trim(value)
			end
		end
	end
	file:close()

	return data
end

--- Lê o arquivo desc do banco local do pacman.
function metadata.parse_desc(path)
	local file = io.open(path, "r")
	if not file then
		return {}
	end

	local data = {}
	local current_key

	for line in file:lines() do
		local key = line:match("^%%([A-Z_]+)%%$")
		if key then
			current_key = key:lower()
			data[current_key] = ""
		elseif current_key and line ~= "" then
			if data[current_key] == "" then
				data[current_key] = line
			else
				data[current_key] = data[current_key] .. "\n" .. line
			end
		end
	end

	file:close()
	return data
end

--- Serializa os metadados que serão instalados junto com o pacote.
function metadata.serialize(data)
	local keys = {
		"format",
		"pkgname",
		"deb_package",
		"deb_version",
		"pkgver",
		"source_type",
		"source",
		"converted_at",
	}

	local lines = { "# deb2pacman metadata v1" }
	for _, key in ipairs(keys) do
		local value = data[key]
		if not value_is_empty(value) then
			value = tostring(value):gsub("[\r\n]+", " ")
			lines[#lines + 1] = key .. "=" .. value
		end
	end

	return table.concat(lines, "\n") .. "\n"
end

--- Escreve o marcador dentro da árvore do pacote gerado.
function metadata.write_package_marker(pkg_root, data)
	local directory = pkg_root .. metadata.PACKAGE_DIR
	local ok = os.execute("mkdir -p " .. utils.shell_quote(directory))
	if ok == nil or ok == false then
		return false, "Não foi possível criar " .. directory
	end

	local path = directory .. "/" .. utils.sanitize_filename(data.pkgname) .. ".meta"
	local file, err = io.open(path, "w")
	if not file then
		return false, err or ("Não foi possível criar " .. path)
	end

	file:write(metadata.serialize(data))
	file:close()
	return true
end

--- Retorna um mapa com todos os pacotes instalados no banco local do pacman.
function metadata.read_installed_db(local_db)
	local installed = {}
	local pipe = io.popen(
		"find " .. utils.shell_quote(local_db or metadata.LOCAL_DB) .. " -mindepth 1 -maxdepth 1 -type d 2>/dev/null"
	)
	if not pipe then
		return installed
	end

	for directory in pipe:lines() do
		local info = metadata.parse_desc(directory .. "/desc")
		if not value_is_empty(info.name) then
			installed[info.name] = info
		end
	end
	pipe:close()

	return installed
end

--- Lista os pacotes convertidos que estão instalados no sistema.
--
-- Pacotes novos possuem um marcador em /usr/share/deb2pacman.
-- Pacotes antigos (sem marcador) são detectados por heurística: nome -bin,
-- sem URL, sem repositório de origem e sem validação.
function metadata.list_installed(opts)
	opts = opts or {}
	local install_dir = opts.install_dir or metadata.INSTALL_DIR
	local installed = metadata.read_installed_db(opts.local_db)
	local entries = {}
	local seen = {}

	local pipe = io.popen(
		"find "
			.. utils.shell_quote(install_dir)
			.. " -mindepth 1 -maxdepth 1 -type f -name '*.meta' 2>/dev/null"
	)

	if pipe then
		for path in pipe:lines() do
			local data = metadata.parse_file(path)
			local name = data and data.pkgname
			local package = name and installed[name]

			if package then
				entries[#entries + 1] = {
					pkgname = name,
					installed_version = package.version,
					deb_package = not value_is_empty(data.deb_package) and data.deb_package
						or name:gsub("%-bin$", ""),
					deb_version = data.deb_version,
					pkgver = data.pkgver,
					source = not value_is_empty(data.source) and data.source or nil,
					source_type = not value_is_empty(data.source_type) and data.source_type or nil,
					converted_at = data.converted_at,
					legacy = false,
				}
				seen[name] = true
			end
		end
		pipe:close()
	end

	-- Compatibilidade com pacotes convertidos antes da existência do marcador.
	for name, package in pairs(installed) do
		local validation = tostring(package.validation or ""):lower()
		if
			not seen[name]
			and name:match("%-bin$")
			and value_is_empty(package.url)
			and value_is_empty(package.installed_db)
			and (validation == "" or validation == "none")
		then
			entries[#entries + 1] = {
				pkgname = name,
				installed_version = package.version,
				deb_package = name:gsub("%-bin$", ""),
				legacy = true,
			}
		end
	end

	table.sort(entries, function(a, b)
		return a.pkgname < b.pkgname
	end)

	return entries
end

return metadata
