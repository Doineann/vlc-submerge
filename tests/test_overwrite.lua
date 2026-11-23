-- test_overwrite.lua
-- Tests: existing merged output triggers an Overwrite/Skip prompt;
--        Skip leaves the file untouched; Overwrite replaces it.

local H = dofile("test/helpers.lua")

local function read_file(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

local function has_text(dlg, needle)
    for _, lbl in ipairs(dlg.labels) do
        if lbl.text:find(needle, 1, true) then return true end
    end
    return false
end

H.reset_tmp()
H.write(H.srt("test.en.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hello"))
H.write(H.srt("test.nl.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hallo"))

-- Pre-create the merged output so the prompt is triggered.
local output = H.srt("test.en-nl.srt")
local SENTINEL = "SENTINEL: existing merged file\n"
H.write(output, SENTINEL)

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

local main = H.dlg()
main.dropdowns.first_sub.selected = "en"
main.dropdowns.second_sub.selected = "nl"

-- Trigger the prompt. Only one dialog may exist at a time, so the main
-- dialog is closed before the prompt is created.
local ok, err = H.click(main, "Merge and load")
assert(ok, "merge_selected should not error: " .. tostring(err))
assert(not loaded, "nothing should be loaded before the user chooses")

local prompt = H.dlg()
assert(prompt ~= main, "an overwrite prompt dialog should be shown")
assert(main.deleted, "main dialog must be closed before showing the prompt")
assert(H.button(prompt, "Overwrite"), "prompt should offer Overwrite")
assert(H.button(prompt, "Skip"), "prompt should offer Skip")
assert(read_file(output) == SENTINEL, "file must be untouched while prompting")
print("  Existing output triggers Overwrite/Skip prompt: OK")

-- Skip: keep the existing file, load nothing.
ok, err = H.click(prompt, "Skip")
assert(ok, "Skip should not error: " .. tostring(err))
assert(prompt.deleted, "prompt should close after Skip")

local after_skip = H.dlg()
assert(after_skip ~= prompt, "Skip should restore the main dialog")
assert(has_text(after_skip, "Number of subtitle files found: 2"),
    "merged output must not be scanned as a source subtitle")
assert(read_file(output) == SENTINEL, "Skip must leave the file unchanged")
assert(not loaded, "Skip must not load the merged subtitle")
assert(has_text(after_skip, "merge skipped: file already exists"),
    "Skip should be logged in the status line")
print("  Skip leaves the file untouched and logs the skip: OK")

-- Overwrite: replace the file and load it.
ok, err = H.click(after_skip, "Merge and load")
assert(ok, "second merge_selected should not error: " .. tostring(err))
assert(after_skip.deleted, "main dialog must close again before the prompt")

prompt = H.dlg()
assert(prompt ~= after_skip, "prompt should be shown again on the second attempt")
ok, err = H.click(prompt, "Overwrite")
assert(ok, "Overwrite should not error: " .. tostring(err))
assert(prompt.deleted, "prompt should close after Overwrite")

local after_overwrite = H.dlg()
assert(after_overwrite ~= prompt, "Overwrite should restore the main dialog")
local content = read_file(output)
assert(not content:find("SENTINEL", 1, true), "Overwrite should replace the file")
assert(content:find("Hello", 1, true) and content:find("Hallo", 1, true),
    "Overwrite should write both subtitles")
assert(loaded and loaded:find("test%.en%-nl%.srt$"),
    "Overwrite should load the merged subtitle, got: " .. tostring(loaded))
assert(has_text(after_overwrite, "merged and loaded"),
    "Overwrite should log the merge result")
print("  Overwrite replaces the file and loads it: OK")

H.cleanup()

print("\nALL OVERWRITE TESTS PASSED")
