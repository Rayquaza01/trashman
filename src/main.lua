--[[pod_format="raw",created="2024-03-15 13:58:36",modified="2025-01-10 00:13:36",revision=553]]
-- Trash v1.0
-- by Arnaught

--- @class __FileMetadata
--- @field TrashInfo? __TrashInfo

--- @class __TrashInfo
--- @field Path string
--- @field DeletionDate string

cd(env().path)
local argv = env().argv or {}

local is_cli = false
local is_tooltray = false

local TRASH_FOLDER = "/appdata/trash"
local TRASH_FILE = TRASH_FOLDER .. "/.trash"

if not fstat(TRASH_FOLDER) then
	mkdir(TRASH_FOLDER)
end

local trash = {}

function update_trash_dir()
    store(TRASH_FILE, "")
end

--- Parses arguments to find flag arguments and file arguments
--- Flag arguments start with --
--- Any arguments after the literal argument "--" will *always* be interpreted as a file, regardless of whether it starts with --
--- Returns array of flag arguments and array of file arguments
--- @return string[], string[]
function parse_arguments()
    local file_arguments = {}
    local flag_arguments = {}

    local is_always_file = false

    for arg in all(argv) do
        if not is_always_file then
            if arg == "--" then
                is_always_file = true
            elseif arg:find("^%-%-") then
                add(flag_arguments, arg)
            else
                add(file_arguments, arg)
            end
        else
            add(file_arguments, arg)
        end
    end

    return flag_arguments, file_arguments
end

--- Searches for a term in a table
--- If term is not found, return -1
--- @param tbl table
--- @param term any
--- @return integer
function search(tbl, term)
    for i, item in ipairs(tbl) do
        if item == term then
            return i
        end
    end

    return -1
end

function amap(tbl, cb)
    local res = {}

    for i, item in ipairs(tbl) do
        add(res, cb(item, i, tbl))
    end

    return res
end

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

    if is_cli then
        print(string.format("Restored \fe%s\f7 to \fe%s\f7", f, path))
    else
        notify(string.format("Restored %s to %s", f, path))
    end
end

--- Restore all files from trash
function restore_all_trash()
	local trash_files = ls(TRASH_FOLDER)
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
	rm(TRASH_FOLDER .. "/" .. f)
	notify(string.format("Permanantly deleted %s", f))
end

--- Permanantly delete all files from trash
function empty_trash()
	local trash_files = ls(TRASH_FOLDER)
	for f in all(trash_files) do
		rm(TRASH_FOLDER .. "/" .. f)
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
    local dest = unique_filename(TRASH_FOLDER, file)

	local metadata = {
		TrashInfo = {
			Path = file,
			DeletionDate = date()
		}
	}

	store_metadata(file, metadata)
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

    update_trash_dir()
end

function print_trash()
    if #trash > 0 then
        for t in all(trash) do
            print(string.format("\fe%s\f7 (\fc%s\f7) \f8%s\f7", t.name, t.Path, t.DeletionDate))
        end
    else
        print("Nothing in trash")
    end
end

function _init()
	list_trash()

    local flag_arguments, file_arguments = parse_arguments()

    if #flag_arguments > 0 then
        is_cli = true

        if search(flag_arguments, "--list") > -1 or search(flag_arguments, "--search") > -1 then
            print_trash()
            exit(0)
        elseif search(flag_arguments, "--empty") > -1 then
            empty_trash()

            update_trash_dir()
            exit(0)
        elseif search(flag_arguments, "--restore") > -1 then
            for f in all(file_arguments) do
                restore_trash(f)
            end

            update_trash_dir()

            exit(0)
        elseif search(flag_arguments, "--restore-all") > -1 then
            restore_all_trash()

            update_trash_dir()
            exit(0)
        elseif search(flag_arguments, "--tooltray") > -1 then
            is_tooltray = true
        end
    elseif #file_arguments > 0 then
        is_cli = true

        -- if file arguments are available, but no flag arguments
        -- delete files
        for f in all(file_arguments) do
            if fstat(f) then
                put_trash(fullpath(f))
            end
        end

        update_trash_dir()

        exit(0)
    end


    if is_tooltray then
        window(16, 16)
    else
        window({
            width = 256, height = 64,
            title = "Trash Manager"
        })

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
    end

	on_event("drop_items", function (msg)
        local files = amap(msg.items, function (f)
            return f.fullpath
        end)
        put_multiple_trash(files)

        update_trash_dir()
	end)

    on_event("modified:" .. TRASH_FILE, function ()
        list_trash()
    end)

	mx, my, mb = 0, 0, 0
	prev_mb = 0
	row = -1
end

function _update()
	prev_mb = mb
	mx, my, mb = mouse()

    if is_tooltray then
        if mb ~= prev_mb then
            if (mb & 0x1) == 0x1 then
                create_process(env().prog_name)
            elseif (mb & 0x2) == 0x2 then
                empty_trash()
                list_trash()
            end
        end
    else
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
        cls()

        if row >= 0 and row < #trash then
            rectfill(0, row * 8, get_display():width(), (row + 1) * 8, 16)
        end

        for i, t in ipairs(trash) do
            print(string.format("\fe%s\f7 (\fc%s\f7) \f8%s\f7", t.name, t.Path, t.DeletionDate), 0, (i - 1) * 9)
        end
    end
end
