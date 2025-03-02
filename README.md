# Trash Manager

## How to Use

Once opened, Trash Manager will display a list of
all files currently in the trash.

The information shown for each file is:
 - Restore path
 - File size
 - Deletion date

Left clicking a file will restore the file to it's
restore path. Right clicking a fill will
permanently delete it.

At the bottom of the UI is a statusbar that
includes:
 - Total items in trash
 - Total file size of all items in trash
 - Scroll indicator

The scroll indicator will display TOP when at the
top of the list, BOT when at the bottom of the
list, and a percentage otherwise.

To delete an file, simply drag it into the Trash
Manager window.

From the hamburger menu, you can also empty the
trash, restore all items, refresh the trash, and
open this help document.

## CLI

Trash Manager can be used from the terminal as
well. If using it in the terminal, you should save
the application in `/appdata/system/util` so you
can access it anywhere.

**Delete files**
 - trash [files]

**List files**
 - trash --list [search term]
 - trash --search [search term]

`--list` and `--search` are interchangeable.
Listing trash from the CLI works similarly to in
the GUI, though the information is slightly
different.

From the CLI, the information shown for each file is:
 - Restore path
 - Trash name
 - File size
 - Deletion date

The trash name is the unique filename that the
file is saved as in the trash directory. It is
needed to restore files from the CLI.

If you provide a search term, only files where the
restore path matches the search term will be
displayed. The search term can be a Lua Pattern.

**Restore files**
 - trash --restore [files]
 - trash --restore-all

Restoring a file will move it from the trash to
its restore path. The file arguments are the trash
name (from `trash --list`), not the restore path.

`--restore-all` will restore *all* items from trash.

**Permanently delete files**
 - trash --delete [files]
 - trash --delete-all
 - trash --empty

File arguments are the trash name (from `trash
--list`), not the restore path.

`--empty` and `--delete-all` are interchangeable.
Both will permanently delete all files in trash.

## Tooltray

Trash Manager can be used as a tooltray
application. The `--tooltray` argument will have
it launch as an indicator instead of a full GUI
application.

To include Trash Manager in the tooltray, include
the following in `/appdata/system/startup.lua`:

```lua
create_process("/appdata/system/util/trash.p64", {
    argv = {
        "--tooltray"
    },
    window_attribs = {
        workspace = "tooltray",
        x=360, y=5,
        width=16, height=16
    }
})
```

This will launch Trash Manager on the tooltray
next to the clock. (If you want it somewhere else,
change the x and y coordinates above)

Alternatively, you can launch trash.p64 with the
`--tooltray` argument and drag it to the tooltray.
You can drag it inside the tooltray.

The indicator will display a different icon
depending on if the trash is empty.

Left clicking the indicator will open the GUI.
Middle clicking the indicator will empty the trash.

## filenav.p64 Compatibility

You can integrate Trash Manager into filenav.p64
by replacing the `delete_selected_files` function
in filenav.p64. The easiest way to do this is with
sedish in your startup script.

```
sedish("/system/apps/filenav.p64/finfo.lua", {
	{
		[[function delete_selected_files()]],
		[[function delete_selected_files()
	if fstat("/appdata/system/util/trash.p64") == "folder" then
		local trash = {"--"}

		for k,v in pairs(finfo) do
			if (v.selected) then
				local fullpath = fullpath(v.filename)
				add(trash, fullpath)
			end
		end

		create_process("/appdata/system/util/trash.p64", {argv=trash})
		notify(string.format("moved %d items to trash", #trash - 1))
		return
	end]]
	}
})
```

Sedish can be found here: https://www.lexaloffle.com/bbs/?tid=140847

## Automatically Deleting Files

You can setup a script to permanently delete files
in trash after a certain amount of time (for
example, 30 days).

```
-- delete files older than 30 days ago
local DeletionCutoff = date(nil, nil, -30*86400)
for f in all(ls("/appdata/trash/files")) do
	local trash_file = "/appdata/trash/files/" .. f
	local info_file = "/appdata/trash/info/" .. f .. ".trashinfo"
	local TrashInfo = fetch(info_file).TrashInfo
	if TrashInfo.DeletionDate < DeletionCutoff then
		printh("Permanently deleting " .. f)
		rm(trash_file)
		rm(info_file)
	end
end
```

If you include this in your startup script, older
trash will automatically be cleared when starting
Picotron.

## Technical Details

Trash Manager is loosely following the XDG Trash
Specification

https://xdg.pages.freedesktop.org/xdg-specs/trash-spec/1.0/

The Trash directory is `/appdata/trash`. Trashed
files are saved in `/appdata/trash/files` and
metadata is stored in `/appdata/trash/info`

For each file in `/appdata/trash/files`, there
should be a corresponding `/appdata/trash/info`
file. Info files should have the same name as
trash files, but with `.trashinfo` appended.

Example:
 - `/appdata/trash/files/meow.bow-wow`
 - `/appdata/trash/info/meow.bow-wow.trashinfo`

`.trashinfo` files are PODs that contain metadata
for the trash items: Path and DeletionDate. Path
is the absolute path of the file before it was
deleted. DeletionDate is a UTC timestamp (from
`date()`)

`.trashinfo` files should have the following
format:

```lua
{
    TrashInfo = {
        Path = "/foo/bar/meow.bow-wow",
        DeletionDate = "2004-08-23 22:32:08"
    }
}
```

If a `.trashinfo` file is missing, its metadata
will be inferred. Path will be assumed to be in
"/", and DeletionDate will be assumed to be the
file's modified time.

Trash Manager will refresh the trash list when
`/appdata/trash/.trash` is updated.
