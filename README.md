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
You can use Ctrl+Drag to move it inside the
tooltray. (Tip: Hold right click on the indicator
to focus it first)

The indicator will display a different icon
depending on if the trash is empty.

Left clicking the indicator will open the GUI.
Middle clicking the indicator will empty the trash.

## filenav.p64 Compatibility

Picotron actually has a trash system builtin. When
you delete a file from filenav.p64, it will be
moved to `/ram/compost`.

Since `/ram/compost` is in ram, files there won't
be persistently saved. All trash will be
permanently deleted when Picotron is restarted.
filenav.p64 also doesn't save metadata such as the
restore path or the deletion date.

You can link `/ram/compost` to Trash Manager's
trash location. This will make the trash
persistent. However, there is still metadata
missing.

When metadata is missing, the restore path is
assumed to be in "/", and the deletion date uses
the file's modified time instead. Entries with
missing metadata will be marked with an (!) after
their restore path.

If you would like to enable filenav.p64
compatibility, place the following in
`/appdata/system/startup.lua`:

```lua
mount("/ram/compost", "/appdata/trash/files")
```

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
