-- test_merge_output.lua
-- Tests: cue ordering (primary before yellow), output filename format, file creation

vlc = {}

local widget_mt = {}
widget_mt.__index = {
    add_value = function(self, text, id) table.insert(self.values, text) end,
    get_value = function(self) return self.selected end,
    set_text = function(self, text) self.text = text end,
    set_checked = function(self, bool) end,
    delete = function(self) end
}

local dialog_mt = {}
dialog_mt.__index = {
    add_label = function(self, text, x, y, w, h)
        table.insert(self.labels, {text=text,x=x,y=y,w=w,h=h})
        return { set_text = function(s, t) self.labels[#self.labels].text = t end }
    end,
    add_button = function(self, text, func, x, y, w, h)
        table.insert(self.buttons, {text=text, fn=func})
    end,
    add_dropdown = function(self, name, x, y, w, h)
        local widget = { name = name, values = {}, selected = nil }
        setmetatable(widget, widget_mt)
        self.dropdowns[name] = widget
        return widget
    end,
    add_text_input = function(self, text) end,
    add_check_box = function(self, text, checked) end,
    add_image = function(self, filename) end,
    del_widget = function(self, widget) end,
    get_value = function(self, name)
        local widget = self.dropdowns[name]
        return widget and widget.selected or nil
    end,
    delete = function(self) end
}

function vlc.dialog(title)
    local d = { labels = {}, buttons = {}, dropdowns = {} }
    _G.test_dlg = d
    return setmetatable(d, dialog_mt)
end

local video_path = "/home/ray/Desktop/submerge/test.mkv"
local loaded_path = nil
local autoselect = nil
vlc.input = { item = function() return { uri = function() return "file://" .. video_path end } end }
vlc.input.add_subtitle = function(path, auto)
    loaded_path = path
    autoselect = auto
    return true
end
vlc.player = { add_slave = function(kind, path, forced) loaded_path = path; return true end }

-- Clean up any leftover test files
for _, f in ipairs({".en.srt", ".nl.srt", ".en-nl.srt", ".nl-en.srt"}) do
    os.remove(video_path:gsub("%.mkv$", f))
end

-- Create SRT files with identical timing to test yellow-first ordering
local f = io.open(video_path:gsub("%.mkv$", ".en.srt"), "w")
f:write("1\n00:00:01,000 --> 00:00:05,000\nHello\n\n")
f:write("2\n00:00:06,000 --> 00:00:10,000\nWorld\n\n")
f:close()

local f = io.open(video_path:gsub("%.mkv$", ".nl.srt"), "w")
f:write("1\n00:00:01,000 --> 00:00:05,000\nHallo\n\n")
f:write("2\n00:00:06,000 --> 00:00:10,000\nWereld\n\n")
f:close()

local chunk = assert(loadfile("submerge.lua"))
chunk()
activate()

-- Manually select en first, nl second
local dlg = _G.test_dlg
dlg.dropdowns.first_sub.selected = "en"
dlg.dropdowns.second_sub.selected = "nl"

-- Call merge
for _, b in ipairs(dlg.buttons) do
    if b.text == "Merge and load" then
        local ok, err = pcall(b.fn)
        assert(ok, "merge_selected should not error: " .. tostring(err))
        break
    end
end

-- Verify the merged file was loaded AND activated (autoselect = true)
assert(loaded_path, "merged subtitle should be loaded")
assert(loaded_path:find("%.en%-nl%.srt$"),
    "loaded path should be the merged file, got: " .. tostring(loaded_path))
assert(autoselect == true,
    "add_subtitle must be called with autoselect=true to activate the track, got: " .. tostring(autoselect))
print("  Merged subtitle loaded and activated (autoselect=true): OK")

-- Read merged file
local merged = video_path:gsub("%.mkv$", ".en-nl.srt")
local f = io.open(merged, "r")
assert(f, "merged file should exist: " .. merged)
local content = f:read("*a")
f:close()

-- Verify primary (en) comes first, yellow (nl) second in the file
local hallo_pos = content:find("Hallo")
local hello_pos = content:find("Hello")
assert(hallo_pos, "Hallo (nl, yellow) should be in merged file")
assert(hello_pos, "Hello (en, primary) should be in merged file")
assert(hello_pos < hallo_pos, "Primary (en) should appear before yellow (nl) in merged file, got hello_pos=" .. hello_pos .. " hallo_pos=" .. hallo_pos)
print("  Primary (en) appears before yellow (nl): OK")

-- Verify filename format
assert(merged:find("%.en%-nl%.srt$"), "filename should be test.en-nl.srt")
print("  Output filename format: OK")

-- Cleanup
os.remove(video_path:gsub("%.mkv$", ".en.srt"))
os.remove(video_path:gsub("%.mkv$", ".nl.srt"))
os.remove(merged)

print("\nALL MERGE OUTPUT TESTS PASSED")
