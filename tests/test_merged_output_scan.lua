-- test_merged_output_scan.lua
-- Tests: merge output is excluded from the source dropdowns for any language
--        pair, not only the en/nl/de aliases.

local H = dofile("test/helpers.lua")

local function has_text(dlg, needle)
    for _, lbl in ipairs(dlg.labels) do
        if lbl.text:find(needle, 1, true) then return true end
    end
    return false
end

local function entry_texts(widget)
    local texts = {}
    for _, entry in ipairs(widget.entries) do
        texts[#texts + 1] = entry.text
    end
    return texts
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

H.reset_tmp()
H.write(H.srt("test.fr.srt"), H.cue("00:00:01,000", "00:00:05,000", "Bonjour"))
H.write(H.srt("test.es.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hola"))
-- Simulate a previous merge of fr and es.
H.write(H.srt("test.fr-es.srt"),
    H.cue("00:00:01,000", "00:00:05,000", "Bonjour"))

H.setup({ video = H.video_uri() })
H.load()
activate()

local dlg = H.dlg()
assert(has_text(dlg, "Number of subtitle files found: 2"),
    "merged fr-es output must not be scanned as a source subtitle")

local first = entry_texts(dlg.dropdowns.first_sub)
local second = entry_texts(dlg.dropdowns.second_sub)

assert(#first == 2, "first dropdown should list 2 languages, got " .. #first)
assert(contains(first, "fr") and contains(first, "es"),
    "source languages fr and es should be listed")
assert(not contains(first, "fr-es"),
    "merged fr-es output must not appear as a language")
assert(not contains(second, "fr-es"),
    "merged fr-es output must not appear in the second dropdown")
print("  Non-en/nl/de merged output excluded from dropdowns: OK")

H.cleanup()

print("\nALL MERGED OUTPUT SCAN TESTS PASSED")
