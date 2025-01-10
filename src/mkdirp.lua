--- Make a directory, creating any missing folders as nessecary
--- @param name string
function mkdirp(name)
	if not fstat(name) then
		local parent = name:dirname()
		if parent == "" then
			parent = "/"
		end

		if parent ~= "/" and not fstat(parent) then
			mkdirp(parent)
		end

		mkdir(name)
	end
end
