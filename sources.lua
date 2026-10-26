local sources = {}
local utils = require("utils")

-- Fontes usadas quando o pacote não possui uma URL salva.
-- Para apps fora desta lista, adicione uma linha em
-- ~/.config/deb2pacman/sources.conf:
--
--   nome-do-pacote=https://exemplo.com/app-latest.deb
--
-- A chave pode ser o nome Debian (ex.: google-chrome-stable) ou o nome
-- instalado no Arch (ex.: google-chrome-stable-bin).
-- As URLs embutidas apontam para a arquitetura amd64/x86_64.
sources.BUILTIN = {
	["google-chrome-stable"] = "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
	["google-chrome-stable-bin"] = "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
	["code"] = "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64",
	["code-bin"] = "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64",
	["discord"] = "https://discord.com/api/download?platform=linux&format=deb",
	["discord-bin"] = "https://discord.com/api/download?platform=linux&format=deb",
	["uaitex"] = "https://uaitex.uaifisica.com.br/downloads/UaiTex-1.3.1-Linux-amd64.deb",
	["uaitex-bin"] = "https://uaitex.uaifisica.com.br/downloads/UaiTex-1.3.1-Linux-amd64.deb",
}

function sources.config_path()
	local config_home = os.getenv("XDG_CONFIG_HOME")
	if config_home and config_home ~= "" then
		return config_home .. "/deb2pacman/sources.conf"
	end

	local home = os.getenv("HOME") or "."
	return home .. "/.config/deb2pacman/sources.conf"
end

function sources.load_config()
	local path = sources.config_path()
	local file = io.open(path, "r")
	if not file then
		return {}
	end

	local config = {}
	for line in file:lines() do
		if line ~= "" and not line:match("^%s*#") then
			local key, value = line:match("^([^=]+)=(.*)$")
			if key and value then
				config[utils.trim(key)] = utils.trim(value)
			end
		end
	end
	file:close()

	return config
end

--- Resolve a fonte de atualização de um pacote.
-- Retorna: url/caminho, tipo ("url" ou "file") e origem ("config", "metadata" ou "builtin").
function sources.resolve(entry)
	local config = sources.load_config()
	local keys = { entry.pkgname, entry.deb_package }

	for _, key in ipairs(keys) do
		if key and config[key] and config[key] ~= "" then
			return config[key], "url", "config"
		end
	end

	if entry.source and entry.source ~= "" then
		if entry.source_type == "url" or entry.source:match("^https?://") then
			return entry.source, "url", "metadata"
		end
	end

	for _, key in ipairs(keys) do
		if key and sources.BUILTIN[key] then
			return sources.BUILTIN[key], "url", "builtin"
		end
	end

	if entry.source and utils.file_exists(entry.source) then
		return entry.source, "file", "metadata"
	end

	return nil
end

return sources
