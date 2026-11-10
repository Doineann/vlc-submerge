--[[
  Name:        SubMerge
  Description: Merge two external language-specific SRT subtitle files.
  Author:      Doineann
  Version:     1.3
  License:     GPL

  VLC 3.x Lua extension.

  Scans external SRT files associated with the currently playing local video.
  The two selected files are merged chronologically. The second language
  is wrapped in an SRT-compatible yellow font tag.

  No directories are created. Source subtitle files are never modified.
--]]


function descriptor()
    return {
        title = "SubMerge",
        version = "1.3",
        author = "Doineann",
        shortdesc = "SubMerge",
        description = "Scan, merge and load language-tagged external SRT files.",
        capabilities = { "input-listener" },
        license = "GPL"
    }
end

function activate()
    refresh_dialog()
end

function deactivate()
    if dlg then
        dlg:delete()
        dlg = nil
    end

    status_label = nil
end

local dlg = nil
local subtitle_files = {}
local video_path = nil
local video_dir = nil
local video_stem = nil
local status_label = nil

-- Widget references for reading dropdown values (get_value is a widget method,
-- not a dialog method, in VLC 3.x Lua).
local first_dd_widget = nil
local second_dd_widget = nil

local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

local function path_join(a, b)
    local sep = is_windows() and "\\" or "/"
    if a:sub(-1) == "/" or a:sub(-1) == "\\" then
        return a .. b
    end
    return a .. sep .. b
end

local function basename(path)
    return path:match("([^/\\]+)$") or path
end

local function dirname(path)
    return path:match("^(.*)[/\\][^/\\]+$") or "."
end

local function strip_extension(name)
    return name:gsub("%.[^%.]+$", "")
end

local function shell_quote(s)
    if is_windows() then
        return '"' .. s:gsub('"', '\\"') .. '"'
    end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function uri_decode(s)
    s = s:gsub("^file://", "")
    s = s:gsub("^localhost", "")
    s = s:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)

    if is_windows() and s:match("^/[A-Za-z]:") then
        s = s:sub(2)
    end
    return s
end

local function uri_encode_path(path)
    local p = path:gsub("\\", "/")
    p = p:gsub("([^%w%-%._~/:])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)

    if p:match("^[A-Za-z]:/") then
        return "file:///" .. p
    end
    if p:sub(1, 1) == "/" then
        return "file://" .. p
    end
    return "file://" .. p
end

local function get_current_video()
    local item = vlc.input.item()
    if not item then return false end

    local uri = item:uri()
    if not uri or not uri:match("^file://") then
        return false
    end

    video_path = uri_decode(uri)
    video_dir = dirname(video_path)
    video_stem = strip_extension(basename(video_path))
    return true
end

local function list_srt_files(dir)
    local results = {}
    local command

    if is_windows() then
        command = 'dir /b /a-d ' .. shell_quote(path_join(dir, "*.srt")) ..
                  ' 2>NUL'
    else
        command = 'find ' .. shell_quote(dir) ..
                  ' -maxdepth 1 -type f -iname "*.srt" -print 2>/dev/null'
    end

    local pipe = io.popen(command)
    if not pipe then return results end

    for line in pipe:lines() do
        line = line:gsub("[\r\n]+$", "")
        if line ~= "" then
            if is_windows() and not line:match("^[/\\]?[%a]:[/\\]") then
                line = path_join(dir, line)
            elseif not is_windows() and line:sub(1, 1) ~= "/" then
                line = path_join(dir, line)
            end
            results[#results + 1] = line
        end
    end

    pipe:close()
    return results
end

local function directory_exists(path)
    local command

    if is_windows() then
        command = 'if exist ' .. shell_quote(path_join(path, ".")) ..
                  ' (exit 0) else (exit 1)'
    else
        command = 'test -d ' .. shell_quote(path)
    end

    local ok = os.execute(command)
    return ok == true or ok == 0
end

local function get_scan_directories()
    local dirs = { video_dir }

    local names = {
        "Subs", "subs", "SUBS",
        "Subtitles", "subtitles", "SUBTITLES",
        "Subtitle", "subtitle",
        "Sub", "sub"
    }

    local seen = { [video_dir:lower()] = true }

    for _, name in ipairs(names) do
        local dir = path_join(video_dir, name)

        if not seen[dir:lower()] and directory_exists(dir) then
            dirs[#dirs + 1] = dir
            seen[dir:lower()] = true
        end
    end

    return dirs
end

local function escape_pattern(s)
    return (s:gsub("([^%w])", "%%%1"))
end

local function get_language_tag(path)
    local filename = basename(path)
    local stem = escape_pattern(video_stem)

    local tail = filename:match("^" .. stem .. "%.(.+)%.srt$")
    if not tail then return nil end

    local tag = tail:match("^([%a][%a][%a]?)")
    if not tag then return nil end

    local rest = tail:sub(#tag + 1)
    local region = rest:match("^[-_]([%a][%a])")

    if region then
        tag = tag .. "-" .. region
        rest = rest:sub(4)
    elseif rest ~= "" and not rest:match("^[%.%-_]") then
        return nil
    end

    if rest ~= "" and not rest:match("^[%.%-_][%w%.%-_]*$") then
        return nil
    end

    return tag:lower()
end

local function scan_subtitles()
    subtitle_files = {}
    local seen = {}

    for _, dir in ipairs(get_scan_directories()) do
        for _, path in ipairs(list_srt_files(dir)) do
            local key = path:lower()

            if not seen[key] then
                seen[key] = true

                local tag = get_language_tag(path)

                if tag then
                    subtitle_files[#subtitle_files + 1] = {
                        path = path,
                        tag = tag,
                        label = tag
                    }
                end
            end
        end
    end

    table.sort(subtitle_files, function(a, b)
        -- English first
        local a_eng = (a.tag == "eng" or a.tag == "en")
        local b_eng = (b.tag == "eng" or b.tag == "en")
        if a_eng and not b_eng then return true end
        if not a_eng and b_eng then return false end
        if a.tag == b.tag then
            return a.path:lower() < b.path:lower()
        end
        return a.tag < b.tag
    end)
end

local function parse_time(value)
    local h, m, s, ms = value:match(
        "^(%d%d):(%d%d):(%d%d),(%d%d%d)$"
    )

    if not h then return nil end

    return (((tonumber(h) * 60 + tonumber(m)) * 60) +
            tonumber(s)) * 1000 + tonumber(ms)
end

local function format_time(ms)
    local h = math.floor(ms / 3600000)
    ms = ms - h * 3600000

    local m = math.floor(ms / 60000)
    ms = ms - m * 60000

    local s = math.floor(ms / 1000)
    local milli = ms - s * 1000

    return string.format("%02d:%02d:%02d,%03d", h, m, s, milli)
end

local function read_srt(path, color_yellow)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end

    local content = f:read("*a")
    f:close()

    content = content:gsub("^\239\187\191", "")
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
    content = content .. "\n\n"

    local cues = {}

    for block in content:gmatch("(.-)\n%s*\n") do
        local lines = {}

        for line in (block .. "\n"):gmatch("(.-)\n") do
            if line ~= "" then
                lines[#lines + 1] = line
            end
        end

        local timing_line

        for i, line in ipairs(lines) do
            if line:find("%d%d:%d%d:%d%d,%d%d%d%s*%-%->") then
                timing_line = i
                break
            end
        end

        if timing_line then
            local start_s, end_s = lines[timing_line]:match(
                "(%d%d:%d%d:%d%d,%d%d%d)%s*%-%->%s*(%d%d:%d%d:%d%d,%d%d%d)"
            )

            local start_ms = start_s and parse_time(start_s)
            local end_ms = end_s and parse_time(end_s)

            if start_ms and end_ms and end_ms >= start_ms then
                local text_lines = {}

                for i = timing_line + 1, #lines do
                    text_lines[#text_lines + 1] = lines[i]
                end

                if #text_lines > 0 then
                    local cue_text = table.concat(text_lines, "\n")

                    if color_yellow then
                        cue_text = '<font color="#FFFF00">' ..
                                   cue_text .. '</font>'
                    end

                    cues[#cues + 1] = {
                        start_ms = start_ms,
                        end_ms = end_ms,
                        text = cue_text
                    }
                end
            end
        end
    end

    return cues
end

local function merge_subtitles(first, second, output_path)
    local first_cues, err = read_srt(first.path, false)
    if not first_cues then return false, err end

    local second_cues, err2 = read_srt(second.path, true)
    if not second_cues then return false, err2 end

    local cues = {}

    -- Add primary cues first, yellow cues second. At equal timestamps the
    -- insertion order decides, so yellow ends up after the primary cue in
    -- the output file.
    local order = 0
    for _, cue in ipairs(first_cues) do
        cue.yellow = false
        order = order + 1
        cue.order = order
        cues[#cues + 1] = cue
    end
    for _, cue in ipairs(second_cues) do
        cue.yellow = true
        order = order + 1
        cue.order = order
        cues[#cues + 1] = cue
    end

    table.sort(cues, function(a, b)
        if a.start_ms == b.start_ms then
            -- Same start time: insertion order decides (primary first).
            return a.order < b.order
        end
        return a.start_ms < b.start_ms
    end)

    local f, write_err = io.open(output_path, "wb")
    if not f then return false, write_err end

    for i, cue in ipairs(cues) do
        f:write(tostring(i), "\n")
        f:write(format_time(cue.start_ms), " --> ",
                format_time(cue.end_ms), "\n")
        f:write(cue.text, "\n\n")
    end

    f:close()
    return true
end

local function set_status(message, color)
    if status_label then
        if color then
            status_label:set_text('<font color="' .. color .. '">' .. message .. '</font>')
        else
            status_label:set_text(message)
        end
    elseif dlg then
        status_label = dlg:add_label(message, 1, 100, 3, 1)
    end
end

-- One-line status log at the bottom of the dialog.
-- Prefixes every message with "STATUS: ". VLC 3.x dropdowns don't expose
-- change callbacks, so we log merge/refresh/error events here. VLC 3.x
-- dialogs do not have a dedicated statusbar component, so a label at the
-- bottom of the dialog is used instead.
local function log(message, color)
    if status_label then
        if color then
            status_label:set_text("STATUS: <font color=\"" .. color .. "\">" .. message .. "</font>")
        else
            status_label:set_text("STATUS: " .. message)
        end
    end
end

-- Common language code aliases (3-letter and 2-letter forms).
local lang_aliases = {
    eng = {"eng", "en"},
    en  = {"eng", "en"},
    dut = {"dut", "nl"},
    nl  = {"dut", "nl"},
    ger = {"ger", "de"},
    de  = {"ger", "de"},
}

-- Returns true if tag a and tag b refer to the same language.
local function same_lang(a, b)
    if a == b then return true end
    for _, ta in ipairs(lang_aliases[a] or {a}) do
        for _, tb in ipairs(lang_aliases[b] or {b}) do
            if ta == tb then return true end
        end
    end
    return false
end

-- Returns the preferred default language tag order (English first for display
-- in the first dropdown only — does NOT force auto-selection during merge).
local function preferred_order()
    local order = {"eng", "en", "dut", "nl", "ger", "de"}
    local result = {}
    for _, preferred in ipairs(order) do
        for _, sub in ipairs(subtitle_files) do
            if same_lang(sub.tag, preferred) then
                table.insert(result, sub)
            end
        end
    end
    -- Append any remaining languages not in the preferred list.
    for _, sub in ipairs(subtitle_files) do
        local found = false
        for _, r in ipairs(result) do
            if r.path == sub.path then found = true; break end
        end
        if not found then table.insert(result, sub) end
    end
    return result
end

-- VLC dropdown widgets expose get_value() as a widget method (not a dialog
-- method). Store widget references and call :get_value() on them.
local function resolve_selected()
    local first_label = nil
    local second_label = nil

    -- Try to read dropdown values via widget:get_value()
    if first_dd_widget and type(first_dd_widget.get_value) == "function" then
        first_label = first_dd_widget:get_value()
    end
    if second_dd_widget and type(second_dd_widget.get_value) == "function" then
        second_label = second_dd_widget:get_value()
    end

    local first, second

    -- Resolve first: use selected label, or default to subtitle_files[1].
    if type(first_label) == "string" and first_label ~= "" then
        for _, sub in ipairs(subtitle_files) do
            if sub.label == first_label then
                first = sub
                break
            end
        end
    end
    if not first then
        first = subtitle_files[1]
    end

    -- Resolve second: use selected label, or default to first subtitle with a
    -- different language than the first.
    if type(second_label) == "string" and second_label ~= "" then
        for _, sub in ipairs(subtitle_files) do
            if sub.label == second_label then
                second = sub
                break
            end
        end
    end
    if not second then
        -- Pick first file with a different language than 'first'.
        for _, sub in ipairs(subtitle_files) do
            if not same_lang(sub.tag, first.tag) then
                second = sub
                break
            end
        end
    end
    -- Fallback: if all tags are the same language, just pick the second file.
    if not second and #subtitle_files >= 2 then
        second = subtitle_files[2]
    end

    -- Safety: never merge a file with itself.
    if second and first and second.path == first.path then
        second = nil
        for _, sub in ipairs(subtitle_files) do
            if sub.path ~= first.path then
                second = sub
                break
            end
        end
    end

    return first, second
end

-- Merges two subtitle files and loads the result into VLC.
local function do_merge(first, second, output_path, output_name)
    local ok2, err2 = merge_subtitles(first, second, output_path)

    if not ok2 then
        log("merge failed: " .. tostring(err2), "#FF6666")
        return
    end

    local loaded = false

    -- VLC 3.x: vlc.input.add_subtitle(path, autoselect) expects a plain
    -- file path (NOT a file:// URI). The second argument makes VLC
    -- switch to the new track immediately; it defaults to false, which
    -- would leave the subtitle loaded but inactive.
    if vlc.input and vlc.input.add_subtitle then
        loaded = vlc.input.add_subtitle(output_path, true)
    elseif vlc.player and vlc.player.add_slave then
        loaded = vlc.player.add_slave(
            "subtitle", uri_encode_path(output_path), true
        )
    end

    if loaded then
        log("merged and loaded: " .. output_name, "#00CC00")
    else
        log("created " .. output_name ..
           " but VLC could not load it automatically.", "#00CC00")
    end
end

-- Asks the user whether to overwrite an existing merged file.
local function confirm_overwrite(first, second, output_path, output_name)
    local ov_dlg = vlc.dialog("File Already Exists")

    ov_dlg:add_label("The merged file already exists:", 1, 1, 3, 1)
    ov_dlg:add_label(output_path, 1, 2, 3, 1)
    ov_dlg:add_label("Overwrite it?", 1, 3, 3, 1)

    ov_dlg:add_button("Overwrite", function()
        ov_dlg:delete()
        do_merge(first, second, output_path, output_name)
    end, 1, 4, 1, 1)
    ov_dlg:add_button("Cancel", function()
        ov_dlg:delete()
        log("merge cancelled: file already exists", "#FF6666")
    end, 2, 4, 1, 1)
end

local function merge_selected()
    local ok, err = pcall(function()
        if not get_current_video() then
            log("no local video is currently playing.", "#FF6666")
            return
        end

        local first, second = resolve_selected()

        if not first or not second then
            log("select two subtitle files.", "#FF6666")
            return
        end

        if first.path == second.path then
            log("select two different subtitle files.", "#FF6666")
            return
        end

        if same_lang(first.tag, second.tag) then
            log("both files have the same language tag.", "#FF6666")
            return
        end

        if not first.tag or first.tag == "" or not second.tag or second.tag == "" then
            log("error: could not read language tags from subtitle files.", "#FF6666")
            return
        end

        local output_name = video_stem .. "." ..
                            first.tag .. "-" .. second.tag .. ".srt"

        local output_path = path_join(video_dir, output_name)

        -- Check if merged file already exists; if so, ask user before overwriting.
        local f = io.open(output_path, "r")
        if f then
            f:close()
            confirm_overwrite(first, second, output_path, output_name)
        else
            do_merge(first, second, output_path, output_name)
        end
    end)

    if not ok then
        log("unexpected error: " .. tostring(err), "#FF6666")
    end
end

function refresh_dialog()
    if dlg then
        dlg:delete()
    end

    dlg = vlc.dialog("SubMerge")
    status_label = nil
    first_dd_widget = nil
    second_dd_widget = nil

    if not get_current_video() then
        dlg:add_label("No local video is currently playing.", 1, 1, 3, 1)
        dlg:add_label("Open a local video file, then click Refresh.", 1, 2, 3, 1)
        dlg:add_button("Refresh", refresh_dialog, 1, 3, 1, 1)
        status_label = dlg:add_label("STATUS: refreshed: no video playing", 1, 4, 3, 1)
        return
    end

    scan_subtitles()

    dlg:add_label("Video: " .. basename(video_path), 1, 1, 3, 1)

    if #subtitle_files < 2 then
        dlg:add_label("Number of subtitle files found: " .. #subtitle_files, 1, 2, 3, 1)
        dlg:add_label("Select 2 files to merge! (NOTE: original files will not be modified)", 1, 3, 3, 1)
        dlg:add_label("Need at least 2 matching SRT files to merge.", 1, 4, 3, 1)
        dlg:add_label("Expected naming: video-name.<language>.srt", 1, 5, 3, 1)
        dlg:add_label("Example: movie.eng.srt and movie.fra.srt", 1, 6, 3, 1)
        dlg:add_button("Refresh", refresh_dialog, 1, 7, 1, 1)
        status_label = dlg:add_label("STATUS: refreshed: " .. #subtitle_files .. " subtitle file(s) found", 1, 8, 3, 1)
        return
    end

    local row = 2

    dlg:add_label("Number of subtitle files found: " .. #subtitle_files, 1, row, 3, 1)
    row = row + 1

    dlg:add_label("Select 2 files to merge! (NOTE: original files will not be modified)", 1, row, 3, 1)
    row = row + 1

    -- Stacked vertically: label, dropdown, label, dropdown.
    dlg:add_label("First language:", 1, row, 4, 1)
    row = row + 1

    local first_dd = dlg:add_dropdown("first_sub", 1, row, 4, 1)
    first_dd_widget = first_dd
    for _, sub in ipairs(subtitle_files) do
        first_dd:add_value(sub.label)
    end
    row = row + 1

    dlg:add_label("Second language (yellow)", 1, row, 4, 1)
    row = row + 1

    local second_dd = dlg:add_dropdown("second_sub", 1, row, 4, 1)
    second_dd_widget = second_dd
    for i = #subtitle_files, 1, -1 do
        second_dd:add_value(subtitle_files[i].label)
    end
    row = row + 1

    -- Note between dropdowns and Merge button.
    dlg:add_label("(note: the original files will not be harmed!)", 1, row, 3, 1)
    row = row + 1

    dlg:add_button("Merge and load", merge_selected, 1, row, 2, 1)
    dlg:add_button("Refresh", refresh_dialog, 3, row, 2, 1)
    row = row + 1

    status_label = dlg:add_label(
        "STATUS: refreshed: " .. #subtitle_files .. " subtitle file(s) found",
        1, row, 4, 1
    )
end

-- Auto-refresh the dialog when the playing video changes.
function input_changed()
    refresh_dialog()
end
