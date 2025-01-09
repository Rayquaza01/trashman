--[[pod_format="raw",created="2024-03-15 13:58:36",modified="2025-01-09 19:48:11",revision=550]]
-- Trash v1.0
-- by Arnaught

local TRASH_FOLDER = "/appdata/trash"

if not fstat(TRASH_FOLDER) then
	mkdir(TRASH_FOLDER)
end

local trash = {}

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

--- Lists all elements in the trash folder and caches their metadata in a global table to be displayed
function list_trash()
	trash = {}
	for f in all(ls(TRASH_FOLDER)) do
		local metadata = fetch_metadata(TRASH_FOLDER .. "/" .. f).TrashInfo
		if metadata ~= nil then
			add(trash, {
				name = f,
				Path = metadata.Path,
				DeletionDate = metadata.DeletionDate
			})
		end
	end
end

--- Restore a file from trash to the path stored in metadata
--- Should be a filename inside the trash folder
--- @param f string
function restore_trash(f)
	local file = TRASH_FOLDER .. "/" .. f
	local path = fetch_metadata(file).TrashInfo.Path

    -- If a file exists in the location we are restoring to
    -- then the restored file will overwrite whatever is currently there
    -- to avoid this, we can create a unique filename for the destination
    -- path = unique_filename(path:dirname(), path)

	-- Can't remove metadata item, so just blank it
	-- see /system/lib/fs.lua line 374
	store_metadata(file, { TrashInfo = {} })
	mv(file, path)

	notify(string.format("Restored %s to %s", f, path))
end

--- Restore all files from trash
function restore_all_trash()
	local trash_files = ls(TRASH_FOLDER)
	for f in all(trash_files) do
		restore_trash(f)
	end
	notify(string.format("Restored %d items", #trash_files))
end

--- Permanantly delete a file from trash
--- Should be a filename inside the trash folder
--- @param f string
function delete_trash(f)
	rm(TRASH_FOLDER .. "/" .. f)
	notify(string.format("Permanantly deleted %s", f))
end

--- Permanantly delete all files from trash
function empty_trash()
	local trash_files = ls(TRASH_FOLDER)
	for f in all(trash_files) do
		rm(TRASH_FOLDER .. "/" .. f)
	end
	notify(string.format("Permanantly deleted %d items", #trash_files))
end

--- Trash a file
--- Will add a TrashInfo metadata key, containing the deletion date and original path,
--- and move the file to the trash folder
--- @path file string
function put_trash(file)
    local dest = unique_filename(TRASH_FOLDER, file)

	local metadata = {
		TrashInfo = {
			Path = file,
			DeletionDate = date()
		}
	}

	store_metadata(file, metadata)
	mv(file, dest)

	notify(string.format("Moved %s to trash", file))
end

function _init()
	menuitem({
		id = 1,
		label = "Empty",
		action = function ()
			empty_trash()
			list_trash()
		end
	})

	menuitem({
		id = 2,
		label = "Restore All",
		action = function ()
			restore_all_trash()
			list_trash()
		end
	})

	window({
		width = 256, height = 64,
		title = "Trash Manager"
	})
	list_trash()

	on_event("drop_items", function (msg)
		for file in all(msg.items) do
			put_trash(file.fullpath)
			list_trash()
		end

		notify(string.format("Moved %d items to trash", #msg.items))
	end)

	mx, my, mb = 0, 0, 0
	prev_mb = 0
	row = -1
end

function _update()
	prev_mb = mb
	mx, my, mb = mouse()
	row = flr(my / 8)

	if row >= 0 and row < #trash and mb ~= prev_mb then
		if (mb & 0x1) == 0x1 then
			restore_trash(trash[row + 1].name)
			list_trash()
		elseif (mb & 0x2) == 0x2 then
			delete_trash(trash[row + 1].name)
			list_trash()
		end
	end
end

function _draw()
	cls()
	if row >= 0 and row < #trash then
		rectfill(0, row * 8, get_display():width(), (row + 1) * 8, 16)
	end

	for i, t in ipairs(trash) do
		print(string.format("\fe%s\f7 (\fc%s\f7) \f8%s\f7", t.name, t.Path, t.DeletionDate), 0, (i - 1) * 9)
	end
end
