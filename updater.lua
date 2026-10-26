local updater = {}
local metadata = require("metadata")
local sources = require("sources")
local converter = require("converter")
local utils = require("utils")

local function file_has_content(path)
	local file = io.open(path, "rb")
	if not file then
		return false
	end

	local size = file:seek("end")
	file:close()
	return size ~= nil and size > 0
end

local function is_deb_file(path)
	local ok, _, code = os.execute("ar t " .. utils.shell_quote(path) .. " >/dev/null 2>&1")
	return not (ok == nil or ok == false or (type(ok) == "number" and ok ~= 0))
end

local function download(url, destination, verbose, logger)
	if not utils.command_exists("curl") then
		logger.err("curl não encontrado. Instale o pacote 'curl' para atualizar pacotes.")
	end

	local flags = verbose and "-fL --retry 3 --progress-bar" or "-fsSL --retry 3"
	local ok, _, code = os.execute(
		"curl " .. flags .. " -o " .. utils.shell_quote(destination) .. " " .. utils.shell_quote(url)
	)

	if ok == nil or ok == false or (type(ok) == "number" and ok ~= 0) then
		return false, "curl terminou com código " .. tostring(code or "desconhecido")
	end

	if not file_has_content(destination) then
		return false, "o arquivo baixado está vazio"
	end

	return true
end

local function install_packages(paths, logger)
	if #paths == 0 then
		return true
	end

	if not utils.command_exists("pacman") then
		logger.err("pacman não encontrado. Este recurso funciona apenas no Arch Linux e derivados.")
	end

	local pipe = io.popen("id -u")
	local uid = pipe and pipe:read("*l")
	if pipe then
		pipe:close()
	end

	local prefix = ""
	if uid ~= "0" then
		if not utils.command_exists("sudo") then
			logger.err("sudo não encontrado. Execute como root ou instale o sudo.")
		end
		prefix = "sudo "
	end

	local quoted = {}
	for _, path in ipairs(paths) do
		quoted[#quoted + 1] = utils.shell_quote(path)
	end

	local command = prefix .. "pacman -U --noconfirm " .. table.concat(quoted, " ")
	logger.info("Instalando pacotes atualizados...")
	local ok, _, code = os.execute(command)
	if ok == nil or ok == false or (type(ok) == "number" and ok ~= 0) then
		return false, code
	end

	return true
end

local function cleanup(workdir)
	if workdir then
		os.execute("rm -rf " .. utils.shell_quote(workdir))
	end
end

local function print_source(entry)
	if not entry.update_source then
		return "sem fonte de atualização"
	end

	if entry.update_source_type == "file" then
		return "arquivo local (" .. entry.update_source .. ")"
	end

	local labels = {
		config = "configuração",
		metadata = "metadados",
		builtin = "embutida",
	}
	local origin = entry.update_source_origin or "url"
	return "fonte: " .. (labels[origin] or origin)
end

--- Lista os pacotes convertidos instalados e atualiza todos os que tiverem fonte.
function updater.run(opts)
	opts = opts or {}
	local logger = opts.logger or require("logger")
	local entries = metadata.list_installed({
		install_dir = opts.install_dir,
		local_db = opts.local_db,
	})

	if #entries == 0 then
		logger.warn("Nenhum pacote convertido pelo deb2pacman foi encontrado instalado.")
		print("  Pacotes convertidos antes da versão com metadados podem não aparecer.")
		print("  Reconverta com --source-url <url> para habilitar atualizações.")
		return
	end

	logger.info("Pacotes .deb convertidos e instalados no sistema:")
	for _, entry in ipairs(entries) do
		entry.update_source, entry.update_source_type, entry.update_source_origin = sources.resolve(entry)
		print(string.format("  %-32s %-20s %s", entry.pkgname, entry.installed_version or "?", print_source(entry)))
		if not entry.update_source then
			print("    Adicione uma URL em " .. sources.config_path())
		end
	end
	print("")

	local with_source = 0
	for _, entry in ipairs(entries) do
		if entry.update_source then
			with_source = with_source + 1
		end
	end

	if with_source == 0 then
		logger.warn("Nenhum pacote possui fonte de atualização conhecida.")
		print("  Configure as URLs em " .. sources.config_path())
		return
	end

	local workdir = utils.make_temp_dir()
	if not workdir then
		logger.err("Não foi possível criar o diretório temporário")
	end

	local output_dir = workdir .. "/out"
	local ok_mkdir = os.execute("mkdir -p " .. utils.shell_quote(output_dir))
	if ok_mkdir == nil or ok_mkdir == false then
		cleanup(workdir)
		logger.err("Não foi possível criar o diretório de saída: " .. output_dir)
	end

	local updates = {}
	local failed = 0

	for _, entry in ipairs(entries) do
		if entry.update_source then
			logger.info("Verificando " .. entry.pkgname .. "...")

			local deb_path
			if entry.update_source_type == "url" then
				deb_path = workdir .. "/" .. utils.sanitize_filename(entry.pkgname) .. ".deb"
				local downloaded, download_err = download(entry.update_source, deb_path, opts.verbose, logger)
				if not downloaded then
					logger.warn("Não foi possível baixar " .. entry.pkgname .. ": " .. tostring(download_err))
					failed = failed + 1
					deb_path = nil
				end
			else
				deb_path = entry.update_source
				if not utils.file_exists(deb_path) then
					logger.warn("Arquivo de origem não encontrado para " .. entry.pkgname .. ": " .. deb_path)
					failed = failed + 1
					deb_path = nil
				end
			end

			if deb_path then
				if not is_deb_file(deb_path) then
					logger.warn("O arquivo de origem de " .. entry.pkgname .. " não é um .deb válido; ignorando.")
					failed = failed + 1
				else
					local result = converter.convert(deb_path, {
						output_dir = output_dir,
						source = entry.update_source,
						source_type = entry.update_source_type,
						display_name = entry.pkgname,
						quiet = not opts.verbose,
						verbose = opts.verbose,
						logger = logger,
					})

					if result.pkgname ~= entry.pkgname then
						logger.warn(
							"A fonte de "
								.. entry.pkgname
								.. " gerou o pacote "
								.. result.pkgname
								.. "; ignorando para não instalar um pacote diferente."
						)
						failed = failed + 1
					else
						local comparison = utils.version_compare(entry.installed_version, result.pkgver)
						if comparison == nil then
							logger.warn("Não foi possível comparar as versões de " .. entry.pkgname .. "; ignorando.")
							failed = failed + 1
						elseif comparison < 0 then
							print("  " .. entry.pkgname .. ": " .. entry.installed_version .. " -> " .. result.pkgver)
							updates[#updates + 1] = {
								entry = entry,
								result = result,
							}
						elseif comparison == 0 then
							print("  " .. entry.pkgname .. ": já está atualizado (" .. entry.installed_version .. ")")
						else
							print("  " .. entry.pkgname .. ": versão instalada é mais nova; ignorando")
						end
					end
				end
			end
		end
	end

	if #updates == 0 then
		if failed > 0 then
			logger.warn("Nenhuma atualização pôde ser aplicada; veja os avisos acima.")
		else
			logger.success("Nenhuma atualização disponível.")
		end
		cleanup(workdir)
		return
	end

	if not opts.yes then
		io.write("Atualizar " .. #updates .. " pacote(s)? [s/N] ")
		io.flush()
		local answer = (io.read("*l") or ""):lower()
		if not answer:match("^[sy]") then
			logger.warn("Atualização cancelada.")
			cleanup(workdir)
			return
		end
	end

	local paths = {}
	for _, update in ipairs(updates) do
		paths[#paths + 1] = update.result.output_path
	end

	local installed, install_err = install_packages(paths, logger)
	if not installed then
		logger.err(
			"Falha ao instalar as atualizações"
				.. (install_err and (" (código " .. tostring(install_err) .. ")") or "")
				.. ". Pacotes convertidos mantidos em "
				.. output_dir
		)
	end

	cleanup(workdir)
	logger.success("Atualização concluída: " .. #updates .. " pacote(s).")
end

return updater
