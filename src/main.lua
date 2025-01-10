--[[pod_format="raw",created="2024-03-15 13:58:36",modified="2025-01-10 00:13:36",revision=553]]
-- Trash v1.0
-- by Arnaught

include("args.lua")
include("array.lua")
include("filesizes.lua")
include("unique_filename.lua")

--- @class __FileMetadata
--- @field TrashInfo? __TrashInfo

--- @class __TrashInfo
--- @field Path string
--- @field DeletionDate string

local width
local height
local rows

offset = 0

local is_cli = false
local is_tooltray = false

local TRASH_FOLDER = "/appdata/trash"
local TRASH_FILE = TRASH_FOLDER .. "/.trash"

if not fstat(TRASH_FOLDER) then
	mkdir(TRASH_FOLDER)
end

local total_size = 0
local trash = {}

function update_trash_dir()
    store(TRASH_FILE, "")
end

--- Lists all elements in the trash folder and caches their metadata in a global table to be displayed
function list_trash()
    total_size = 0
	trash = {}

	for f in all(ls(TRASH_FOLDER)) do
        local file = TRASH_FOLDER .. "/" .. f

        local ftype, size = fstat(file)

        if ftype then
            --- @cast size integer
            total_size += size

            local metadata = fetch_metadata(file).TrashInfo
            if metadata ~= nil then
                add(trash, {
                    name = f,
                    Path = metadata.Path,
                    DeletionDate = metadata.DeletionDate,
                    Type = ftype,
                    Size = size
                })
            end
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
    path = unique_filename(path:dirname(), path)

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
    cd(env().path)
    local argv = env().argv or {}

	list_trash()
    local flag_arguments, file_arguments = parse_arguments(argv)

    if #flag_arguments > 0 then
        is_cli = true

        if search(flag_arguments, "--list") > -1 then
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
    end

	on_event("drop_items", function (msg)
        local files = amap(msg.items, function (f)
            return f.fullpath
        end)
        put_multiple_trash(files)

        update_trash_dir()
	end)

    on_event("modified:" .. TRASH_FILE, function()
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
                restore_trash(trash[row + offset + 1].name)
                update_trash_dir()
            elseif (mb & 0x2) == 0x2 then
                delete_trash(trash[row + offset + 1].name)
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
            print(string.format("\fg%s\f5 \fu%s\f5 \f8%s\f5", t.Path, sizeToReadable(t.Size), t.DeletionDate), 0, (i - 1) * 10 + 1)
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
