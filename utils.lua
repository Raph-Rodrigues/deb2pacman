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

return utils
