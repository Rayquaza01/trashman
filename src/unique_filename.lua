--- Gets a unique filename to put in the destination folder
--- If a file of that name already exists, add a number to the end to avoid collisions
--- @param dest_folder string
--- @param file string
--- @return string
function unique_filename(dest_folder, file)
	local c = 1
	local basename = file:basename()
	local dest = string.format("%s/%s", dest_folder, basename)
	local ext = file:ext()
	local name = basename:sub(1, #basename - #ext - 1)

	while fstat(dest) do
		dest = string.format("%s/%s_%d.%s", dest_folder, name, c, ext)
		c += 1
	end

	return dest
end
