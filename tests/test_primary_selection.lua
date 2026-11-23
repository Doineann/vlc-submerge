-- test_primary_selection.lua
-- Tests: the user's chosen first language is respected (English is only a
--        default), and the chosen primary is written before the yellow text.

local H = dofile("test/helpers.lua")

local function read_file(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

H.reset_tmp()
H.write(H.srt("test.en.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hello"))
H.write(H.srt("test.de.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hallo"))

local loaded
H.setup({
    video = H.video_uri(),
    add_subtitle = function(path)
        loaded = path
        return true
    end,
})
H.load()
activate()

-- Simulate the user choosing German as primary and English as secondary.
local dlg = H.dlg()
dlg.dropdowns.first_sub.selected = "de"
dlg.dropdowns.second_sub.selected = "en"

local ok, err = H.click(dlg, "Merge and load")
assert(ok, "merge_selected should not error: " .. tostring(err))

assert(loaded and loaded:find("test%.de%-en%.srt$"),
    "selection should produce test.de-en.srt, got: " .. tostring(loaded))
print("  Non-English selection used as primary: OK -> de-en")

local content = read_file(H.srt("test.de-en.srt"))
local hallo_pos = content:find("Hallo", 1, true)
local hello_pos = content:find("Hello", 1, true)

assert(hallo_pos and hello_pos, "both cues should be present")
assert(hallo_pos < hello_pos,
    "selected primary (de) must come before yellow (en)")
assert(content:find('<font color="#FFFF00">Hello</font>', 1, true),
    "secondary English should be wrapped in yellow")
assert(not content:find('<font color="#FFFF00">Hallo</font>', 1, true),
    "primary German must not be yellow")
print("  Primary German precedes yellow English: OK")

assert(H.deactivated(), "extension should unload after a successful merge")
print("  Extension unloads after merge: OK")

H.cleanup()

print("\nALL PRIMARY SELECTION TESTS PASSED")
