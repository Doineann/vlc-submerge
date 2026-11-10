-- test_edge_cases.lua
-- Tests: no video playing, fewer than 2 subtitle files

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

vlc.player = { add_slave = function() return false end }

-- Test 1: No video playing
print("  Test 1: No video playing")
vlc.input = { item = function() return nil end }
local chunk = assert(loadfile("submerge.lua"))
chunk()
local ok, err = pcall(function() activate() end)
assert(ok, "activate should not error: " .. tostring(err))
assert(_G.test_dlg, "dialog should exist")
assert(#_G.test_dlg.buttons == 1, "should have 1 button (Refresh)")
assert(#_G.test_dlg.dropdowns == 0, "should have 0 dropdowns")
print("    No video: dialog shows message + Refresh button: OK")

-- Test 2: Video playing but 0 subtitle files
print("  Test 2: Video with 0 subtitle files")
vlc.input = { item = function() return { uri = function() return "file:///home/ray/Desktop/submerge/test.mkv" end } end }
chunk = assert(loadfile("submerge.lua"))
chunk()
ok, err = pcall(function() activate() end)
assert(ok, "activate should not error: " .. tostring(err))
assert(#_G.test_dlg.dropdowns == 0, "should have 0 dropdowns when <2 subtitles")
print("    0 subtitles: no dropdowns, shows requirement message: OK")

-- Test 3: Video playing with 1 subtitle file
local f = io.open("/home/ray/Desktop/submerge/test.en.srt", "w")
f:write("1\n00:00:01,000 --> 00:00:05,000\nHello\n\n")
f:close()

chunk = assert(loadfile("submerge.lua"))
chunk()
ok, err = pcall(function() activate() end)
assert(ok, "activate should not error: " .. tostring(err))
assert(#_G.test_dlg.dropdowns == 0, "should have 0 dropdowns when only 1 subtitle")
print("    1 subtitle: no dropdowns, shows requirement message: OK")

os.remove("/home/ray/Desktop/submerge/test.en.srt")

-- Test 4: Video playing with 2+ subtitles -> dropdowns appear
local f = io.open("/home/ray/Desktop/submerge/test.en.srt", "w")
f:write("1\n00:00:01,000 --> 00:00:05,000\nHello\n\n")
f:close()
local f = io.open("/home/ray/Desktop/submerge/test.nl.srt", "w")
f:write("1\n00:00:01,000 --> 00:00:05,000\nHallo\n\n")
f:close()

chunk = assert(loadfile("submerge.lua"))
chunk()
ok, err = pcall(function() activate() end)
assert(ok, "activate should not error: " .. tostring(err))
-- Both dropdowns should exist when 2+ subtitles found
assert(_G.test_dlg.dropdowns.first_sub, "first_sub dropdown should exist")
assert(_G.test_dlg.dropdowns.second_sub, "second_sub dropdown should exist")
print("    2+ subtitles: dropdowns appear: OK")

os.remove("/home/ray/Desktop/submerge/test.en.srt")
os.remove("/home/ray/Desktop/submerge/test.nl.srt")

print("\nALL EDGE CASE TESTS PASSED")
