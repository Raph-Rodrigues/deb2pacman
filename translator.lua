local translator = {}
local dep_map = {
	["libc6"] = "glibc",
	["python3"] = "python",
	["libgtk-3-0"] = "gtk3",
	["libgtk-3-0t64"] = "gtk3",
	["libasound2"] = "alsa-lib",
	["libasound2t64"] = "alsa-lib",
	["libx11-6"] = "libx11",
	["libnss3"] = "nss",
	["zlib1g"] = "zlib",
	["libgbm1"] = "mesa",
	["libxss1"] = "libxss",
	["libxtst6"] = "libxtst",
	["libdrm2"] = "libdrm",
	["libxkbcommon0"] = "libxkbcommon",
	["libatspi2.0-0"] = "at-spi2-core",
	["libatspi2.0-0t64"] = "at-spi2-core",
}

function translator.translate_deps(depends_str)
	local deps_list = {}
	for dep in depends_str:gmatch("([^,]+)") do
		local first_option = dep:match("([^|]+)") or dep
		local clean_dep = first_option:gsub("%(.-%)", ""):gsub("%s+", "")
		if clean_dep ~= "" then
			local arch_dep = dep_map[clean_dep] or clean_dep
			local exists = false
			for _, v in ipairs(deps_list) do
				if v == arch_dep then
					exists = true
					break
				end
			end
			if not exists then
				table.insert(deps_list, arch_dep)
			end
		end
	end
	return deps_list
end

return translator
