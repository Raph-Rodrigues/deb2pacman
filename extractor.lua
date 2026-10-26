local utils = require("utils")
local extractor = {}

local function run(command, logger, error_message)
	local ok, _, code = os.execute(command)
	if ok == nil or ok == false or (type(ok) == "number" and ok ~= 0) then
		logger.err(error_message .. (code and (" (código " .. code .. ")") or ""))
	end
end

function extractor.extract(deb_file, tmp_dir, verbose, logger)
	local ar_cmd = verbose and "ar xv" or "ar x"
	local tar_cmd = verbose and "tar -xvf" or "tar -xf"
	local redirect = verbose and "" or " >/dev/null 2>&1"
	local q = utils.shell_quote

	if verbose then
		logger.warn("Extraindo contêiner AR...")
	end
	run(
		"cd " .. q(tmp_dir .. "/src") .. " && " .. ar_cmd .. " " .. q(deb_file) .. redirect,
		logger,
		"Falha ao extrair o contêiner AR do pacote .deb"
	)

	if verbose then
		logger.warn("Extraindo arquivos de dados...")
	end
	run(
		"cd " .. q(tmp_dir .. "/pkg") .. " && " .. tar_cmd .. " ../src/data.tar.*" .. redirect,
		logger,
		"Falha ao extrair os arquivos de dados (data.tar.*)"
	)

	if verbose then
		logger.warn("Extraindo metadados de controle...")
	end
	run(
		"cd " .. q(tmp_dir .. "/control") .. " && " .. tar_cmd .. " ../src/control.tar.*" .. redirect,
		logger,
		"Falha ao extrair os metadados de controle (control.tar.*)"
	)
end

return extractor
