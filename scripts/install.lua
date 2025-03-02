--[[pod_format="raw",created="2025-03-02 04:49:01",modified="2025-03-02 04:49:46",revision=2]]
cd(env().path)

cp("src", "trash.p64")
cp("src", "trash.p64.png")
print("Built src to trash.p64")

cp("trash.p64", "/appdata/system/util/trash.p64")
print("Installed trash.p64 to /appdata/system/util")