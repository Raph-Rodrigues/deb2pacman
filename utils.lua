local utils = {}

--- Envolve um valor em aspas simples para uso seguro em comandos de shell.
function utils.shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

--- Converte um caminho relativo em absoluto usando o diretório atual informado.
function utils.to_absolute(path, cwd)
	if path:sub(1, 1) == "/" then
		return path
	end
	return (cwd or ".") .. "/" .. path
end

--- Remove espaços no início e no fim de uma string.
function utils.trim(value)
	return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Verifica se um arquivo existe e pode ser aberto para leitura.
function utils.file_exists(path)
	local file = io.open(path, "rb")
	if not file then
		return false
	end
	file:close()
	return true
end

--- Cria um diretório temporário único.
function utils.make_temp_dir()
	local path = os.tmpname()
	os.remove(path)

	local ok = os.execute("mkdir -p " .. utils.shell_quote(path))
	if ok == nil or ok == false then
		return nil
	end

	return path
end

--- Verifica se um comando está disponível no PATH.
function utils.command_exists(command)
	local pipe = io.popen("command -v " .. utils.shell_quote(command) .. " >/dev/null 2>&1")
	if not pipe then
		return false
	end

	local ok = pipe:close()
	return ok ~= nil and ok ~= false
end

--- Compara duas versões no formato do pacman usando vercmp.
function utils.version_compare(a, b)
	if not a or not b then
		return nil
	end

	local pipe = io.popen("vercmp " .. utils.shell_quote(a) .. " " .. utils.shell_quote(b) .. " 2>/dev/null")
	if pipe then
		local output = pipe:read("*l")
		pipe:close()

		local result = tonumber(output)
		if result then
			return result
		end
	end

	-- Fallback simples caso o vercmp não esteja disponível.
	if a == b then
		return 0
	end
	return a < b and -1 or 1
end

--- Remove caracteres indesejados de um nome de arquivo.
function utils.sanitize_filename(value)
	return (tostring(value or "pacote"):gsub("[^%w%._+-]", "_"))
end

return utils
