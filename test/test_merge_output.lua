-- test_merge_output.lua
-- Tests: merged file creation, cue ordering (primary before yellow),
--        autoselect when loading, output filename format.

local H = dofile("test/helpers.lua")

H.reset_tmp()
H.write(H.srt("test.en.srt"),
    H.cue("00:00:01,000", "00:00:05,000", "Hello") ..
    H.cue("00:00:06,000", "00:00:10,000", "World"):gsub("^1\n", "2\n"))
H.write(H.srt("test.nl.srt"),
    H.cue("00:00:01,000", "00:00:05,000", "Hallo") ..
    H.cue("00:00:06,000", "00:00:10,000", "Wereld"):gsub("^1\n", "2\n"))

local loaded_path, autoselect
H.setup({
    video = H.video_uri(),
    add_subtitle = function(path, auto)
        loaded_path = path
        autoselect = auto
        return true
    end,
})
H.load()
activate()

-- Explicitly select en primary, nl secondary.
local dlg = H.dlg()
dlg.dropdowns.first_sub.selected = "en"
dlg.dropdowns.second_sub.selected = "nl"

local ok, err = H.click(dlg, "Merge and load")
assert(ok, "merge_selected should not error: " .. tostring(err))

-- Loaded AND activated.
assert(loaded_path, "merged subtitle should be loaded")
assert(loaded_path:find("%.en%-nl%.srt$"),
    "loaded path should be the merged file, got: " .. tostring(loaded_path))
assert(autoselect == true,
    "add_subtitle must be called with autoselect=true, got: " .. tostring(autoselect))
print("  Merged subtitle loaded and activated (autoselect=true): OK")

-- Read merged output.
local merged = H.srt("test.en-nl.srt")
local f = assert(io.open(merged, "r"), "merged file should exist: " .. merged)
local content = f:read("*a")
f:close()

local hello_pos = content:find("Hello")
local hallo_pos = content:find("Hallo")
assert(hello_pos and hallo_pos,
    "both Hello (en) and Hallo (nl) should be present")
assert(hello_pos < hallo_pos,
    "primary (en) should appear before yellow (nl), got hello_pos=" ..
    hello_pos .. " hallo_pos=" .. hallo_pos)
print("  Primary (en) appears before yellow (nl): OK")

-- Yellow cue is wrapped in a yellow font tag.
assert(content:find('<font color="#FFFF00">Hallo</font>', 1, true),
    "yellow subtitle should be wrapped in a #FFFF00 font tag")
print("  Yellow subtitle wrapped in yellow font tag: OK")

assert(merged:find("%.en%-nl%.srt$"), "filename should be test.en-nl.srt")
print("  Output filename format: OK")

assert(H.deactivated(), "extension should unload after a successful merge")
print("  Extension unloads after merge: OK")

H.cleanup()

print("\nALL MERGE OUTPUT TESTS PASSED")
