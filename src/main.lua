--[[pod_format="raw",created="2024-03-15 13:58:36",modified="2025-01-10 00:13:36",revision=553]]
-- Trash v1.0
-- by Arnaught

include("args.lua")
include("array.lua")
include("date.lua")
include("filesizes.lua")
include("unique_filename.lua")

local width
local height
local rows

local offset = 0

local is_cli = false
local is_tooltray = false

local TRASH_FOLDER = "/appdata/trash"
local TRASH_FILES = TRASH_FOLDER .. "/files"
local TRASH_INFO = TRASH_FOLDER .. "/info"
local TRASH_UPDATE_FILE = TRASH_FOLDER .. "/.trash"

if not fstat(TRASH_FOLDER) then
	mkdir(TRASH_FOLDER)
end

if not fstat(TRASH_FILES) then
	mkdir(TRASH_FILES)
end

if not fstat(TRASH_INFO) then
	mkdir(TRASH_INFO)
end

local total_size = 0
local trash = {}

function update_trash_dir()
	store(TRASH_UPDATE_FILE, "")
end

--- Lists all elements in the trash folder and caches their metadata in a global table to be displayed
function list_trash()
	total_size = 0
	trash = {}

	for f in all(ls(TRASH_FILES)) do
		local file = TRASH_FILES .. "/" .. f
		local info_file = string.format("%s/%s.trashinfo", TRASH_INFO, file:basename())

		local ftype = fstat(file)

		if ftype then
			local size = getSize(file)

			--- @cast size integer
			total_size += size

			local Path, DeletionDate, OK
			if fstat(info_file) then
				OK = true
				local metadata = fetch(info_file)
				Path = metadata.TrashInfo.Path
				DeletionDate = metadata.TrashInfo.DeletionDate
			else
				OK = false
				local metadata = fetch_metadata(file)
				Path = "/" .. f
				DeletionDate = metadata.modified
			end

			add(trash, {
				Name = f,
				Path = Path,
				DeletionDate = DeletionDate,
				Type = ftype,
				Size = size,
				OK = OK
			})
		end
	end
end

--- Restore a file from trash to the path stored in metadata
--- Should be a filename inside the trash folder
--- @param f string
function restore_trash(f)
	local file = TRASH_FILES .. "/" .. f
	local info_file = string.format("%s/%s.trashinfo", TRASH_INFO, file:basename())

	if fstat(file) then
		local path = fstat(info_file) and
			fetch(info_file).TrashInfo.Path or
			"/" .. f

		-- If a file exists in the location we are restoring to
		-- then the restored file will overwrite whatever is currently there
		-- to avoid this, we can create a unique filename for the destination
		path = unique_filename(path:dirname(), path)

		rm(info_file)
		mv(file, path)

		if is_cli then
			print(string.format("Restored \fe%s\f7 to \fe%s\f7", f, path))
		else
			notify(string.format("Restored %s to %s", f, path))
		end
	end
end

--- Restore all files from trash
function restore_all_trash()
	local trash_files = ls(TRASH_FILES)
	for f in all(trash_files) do
		restore_trash(f)
	end

	if is_cli then
		print(string.format("Restored \fe%d\f7 items", #trash_files))
	else
		notify(string.format("Restored %d items", #trash_files))
	end
end

--- Permanantly delete a file from trash
--- Should be a filename inside the trash folder
--- @param f string
function delete_trash(f)
	local file = TRASH_FILES .. "/" .. f
	local info_file = string.format("%s/%s.trashinfo", TRASH_INFO, file:basename())

	if fstat(file) then
		rm(file)
		rm(info_file)

		if is_cli then
			print(string.format("Permanantly deleted \fe%s\f7", f))
		else
			notify(string.format("Permanantly deleted %s", f))
		end
	end
end

function delete_multiple_trash(files)
	local c = 0
	for f in all(files) do
		if fstat(TRASH_FILES .. "/" .. f) then
			c += 1
			delete_trash(f)
		end
	end

	if is_cli then
		print(string.format("Permanantly deleted \fe%d\f7 files", c))
	else
		notify(string.format("Permanantly deleted %d files", c))
	end
end

--- Permanantly delete all files from trash
function empty_trash()
	local trash_files = ls(TRASH_FILES)
	for f in all(trash_files) do
		delete_trash(f)
	end

	if is_cli then
		print(string.format("Permanantly deleted \fe%d\f7 items", #trash_files))
	else
		notify(string.format("Permanantly deleted %d items", #trash_files))
	end
end

--- Trash a file
--- Will add a TrashInfo metadata key, containing the deletion date and original path,
--- and move the file to the trash folder
--- @param file string
function put_trash(file)
	local dest = unique_filename(TRASH_FILES, file)
	local info_file = string.format("%s/%s.trashinfo", TRASH_INFO, dest:basename())

	local metadata = {
		TrashInfo = {
			Path = file,
			DeletionDate = date()
		}
	}

	store(info_file, metadata)
	mv(file, dest)

	if is_cli then
		print(string.format("Moved \fe%s\f7 to trash", file))
	else
		notify(string.format("Moved %s to trash", file))
	end
end

--- Put a list of files to trash
--- @param files string[]
function put_multiple_trash(files)
	local c = 0
	for f in all(files) do
		if fstat(f) then
			c += 1
			put_trash(f)
		end
	end

	if is_cli then
		print(string.format("Moved \fe%d\f7 files to trash", c))
	else
		notify(string.format("Moved %d files to trash", c))
	end
end

--- Print all trash items in cli
--- Format: Path, Trash name, Filesize, Deletion date
function print_trash()
	if #trash > 0 then
		for t in all(trash) do
			local OK = ""
			if not t.OK then
				OK = "(\f8!\f7)"
			end
			print(string.format("\fc%s\f7%s (\fe%s\f7) \fu%s\f7 \f8%s\f7", t.Path, OK, t.Name, sizeToReadable(t.Size), toLocalTime(t.DeletionDate)))
		end
	else
		print("Nothing in trash")
	end
end

--- Search for an item in trash and print the results to screen
--- Format: Path, Trash name, Filesize, Deletion date
--- @param term string
function search_trash(term)
	if #trash > 0 then
		for t in all(trash) do
			local s, e = t.Path:find(term)
			if s then
				local path = string.format(
				"%s\fb%s\fc%s",
				t.Path:sub(0, s - 1),
				t.Path:sub(s, e),
				t.Path:sub(e + 1, #t.Path)
				)

				print(string.format("\fc%s\f7 (\fe%s\f7) \fu%s\f7 \f8%s\f7", path, t.Name, sizeToReadable(t.Size), toLocalTime(t.DeletionDate)))
			end
		end
	else
		print("Nothing in trash")
	end
end

function _init()
	cd(env().path)
	local argv = env().argv or {}

	update_trash_dir()
	list_trash()

	local flag_arguments, file_arguments = parse_arguments(argv)

	if #flag_arguments > 0 then
		is_cli = true

		if includes(flag_arguments, "--help") then
			create_process("/system/apps/notebook.p64", { argv = { env().prog_name .. "/README.txt" } })
			exit()
		elseif includes(flag_arguments, "--list") or includes(flag_arguments, "--search") then
			if #file_arguments > 0 then
				search_trash(file_arguments[1])
			else
				print_trash()
			end
			exit(0)
		elseif includes(flag_arguments, "--empty") or includes(flag_arguments, "--delete-all") then
			empty_trash()

			update_trash_dir()
			exit(0)
		elseif includes(flag_arguments, "--delete") then
			delete_multiple_trash(file_arguments)

			update_trash_dir()
			exit(0)
		elseif includes(flag_arguments, "--restore") then
			for f in all(file_arguments) do
				restore_trash(f)
			end

			update_trash_dir()

			exit(0)
		elseif includes(flag_arguments, "--restore-all") then
			restore_all_trash()

			update_trash_dir()
			exit(0)
		elseif includes(flag_arguments, "--tooltray") then
			is_tooltray = true
			is_cli = false
		end
	elseif #file_arguments > 0 then
		is_cli = true

		-- if file arguments are available, but no flag arguments
		-- delete files
		local files = amap(file_arguments, function (f)
			return fullpath(f)
		end)
		put_multiple_trash(files)

		update_trash_dir()

		exit(0)
	end


	if is_tooltray then
		window(16, 16)
	else
		window({
			width = 256, height = 128,
			title = "Trash Manager"
		})

		width = get_display():width()
		height = get_display():height()
		rows = flr(height / 10) - 1

		menuitem({
			id = 1,
			label = "Empty",
			action = function ()
				empty_trash()
				update_trash_dir()
			end
		})

		menuitem({
			id = 2,
			label = "Restore All",
			action = function ()
				restore_all_trash()
				update_trash_dir()
			end
		})

		menuitem({
			divider = true
		})

		menuitem({
			id = 4,
			label = "Help",
			shortcut = "F1",
			action = function ()
				create_process("/system/apps/notebook.p64", { argv = { env().prog_name .. "/README.txt" } })
			end
		})

		menuitem({
			id = 5,
			label = "Refresh",
			shortcut = "F5",
			action = update_trash_dir
		})
	end

	on_event("drop_items", function (msg)
		local files = amap(msg.items, function (f)
			return f.fullpath
		end)
		put_multiple_trash(files)

		update_trash_dir()
	end)

	on_event("modified:" .. TRASH_UPDATE_FILE, function()
		list_trash()
	end)

	on_event("resize", function()
		width = get_display():width()
		height = get_display():height()
		rows = flr(height / 10) - 1
	end)

	mx, my, mb, wheel_x, wheel_y = 0, 0, 0, 0, 0
	prev_mb = 0
	row = -1
end

function _update()
	prev_mb = mb
	mx, my, mb, wheel_x, wheel_y = mouse()

	if is_tooltray then
		if mb ~= prev_mb then
			if (mb & 0x1) == 0x1 then
				create_process(env().prog_name)
			elseif (mb & 0x2) == 0x2 then
				empty_trash()
				update_trash_dir()
			end
		end
	else
		if keyp("f1") then
			create_process("/system/apps/notebook.p64", { argv = { env().prog_name .. "/README.txt" } })
		end

		if keyp("f5") then
			update_trash_dir()
		end

		row = flr(my / 10)

		if btnp(2) then
			offset -= 1
		elseif btnp(3) then
			offset += 1
		end

		offset -= wheel_y

		offset = mid(0, mid(#trash, #trash - rows, 0), offset)

		local count = min(#trash, rows)

		if row >= 0 and row < count and mb ~= prev_mb then
			if (mb & 0x1) == 0x1 then
				restore_trash(trash[row + offset + 1].Name)
				update_trash_dir()
			elseif (mb & 0x2) == 0x2 then
				delete_trash(trash[row + offset + 1].Name)
				update_trash_dir()
			end
		end
	end
end

function _draw()
	if is_tooltray then
		cls(1)

		if #trash > 0 then
			spr(2)
		else
			spr(1)
		end
	else
		cls(7)

		local count = min(#trash, rows)

		if mx >= 0 and mx <= width and row >= 0 and row < count then
			rectfill(0, row * 10, get_display():width(), (row + 1) * 10 - 1, 6)
		end

		for i = 1, count, 1 do
			local t = trash[i + offset]
			local OK = ""
			if not t.OK then
				OK = "(\f8!\f5)"
			end

			print(string.format("\fg%s\f5%s \fu%s\f5 \f8%s\f5", t.Path, OK, sizeToReadable(t.Size), toLocalTime(t.DeletionDate)), 0, (i - 1) * 10 + 1)
			line(0, (i - 1) * 10 - 1, width, (i - 1) * 10 - 1, 5)
		end
		line(0, (count) * 10 - 1, width, (count) * 10 - 1, 5)

		rectfill(0, height - 10, width, height, 0)
		print(string.format("\fc%d\f7 items, \fe%s\f7", #trash, sizeToReadable(total_size)), 0, height - 8, 7)

		if offset == 0 then
			print("TOP", width - 16, height - 8, 7)
		elseif offset == mid(#trash, #trash - rows, 0) then
			print("BOT", width - 16, height - 8, 7)
		else
			print(string.format("%02.0f%%", (offset + 1) / #trash * 100), width - 16, height - 8, 7)
		end

		if #trash == 0 then
			print("Nothing in trash!", width / 2 - 38, height / 2 - 10, 0)
		end
	end
end
