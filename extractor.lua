local extractor = {}

function extractor.extract(deb_file, tmp_dir, pwd, verbose, logger)
	local ar_cmd = verbose and "ar xv" or "ar x"
	local tar_cmd = verbose and "tar -xvf" or "tar -xf"
	local redirect = verbose and "" or " >/dev/null 2>&1"

	if verbose then
		logger.warn("Extraindo contêiner AR...")
	end
	os.execute("cd " .. tmp_dir .. "/src && " .. ar_cmd .. " " .. pwd .. "/" .. deb_file .. redirect)

	if verbose then
		logger.warn("Extraindo arquivos de dados...")
	end
	os.execute("cd " .. tmp_dir .. "/pkg && " .. tar_cmd .. " ../src/data.tar.*" .. redirect)

	if verbose then
		logger.warn("Extraindo metadados de controle...")
	end
	os.execute("cd " .. tmp_dir .. "/control && " .. tar_cmd .. " ../src/control.tar.*" .. redirect)
end

return extractor
