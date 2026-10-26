local logger = {}
local c = {
	reset = "\27[0m",
	green = "\27[32m",
	blue = "\27[34m",
	red = "\27[31m",
	yellow = "\27[33m",
	bold = "\27[1m",
}

function logger.info(msg)
	print(c.blue .. c.bold .. ":: " .. c.reset .. c.bold .. msg .. c.reset)
end
function logger.success(msg)
	print(c.green .. c.bold .. "=> " .. c.reset .. c.bold .. msg .. c.reset)
end
function logger.warn(msg)
	print(c.yellow .. c.bold .. "-> " .. c.reset .. msg)
end
function logger.err(msg)
	print(c.red .. c.bold .. "Erro: " .. c.reset .. msg)
	os.exit(1)
end
function logger.color()
	return c
end

return logger
