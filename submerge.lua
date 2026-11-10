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

-- Extension state. Declared before the lifecycle functions so that
-- deactivate() closes over the real locals rather than globals.
local dlg = nil
local subtitle_files = {}
local video_path = nil
local video_dir = nil
local video_stem = nil
local status_label = nil

-- Dropdown widget references. In VLC 3.x, get_value() is a widget method,
-- not a dialog method.
local first_dd_widget = nil
local second_dd_widget = nil

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
            -- Windows `dir /b` prints bare filenames; `find` already prints
            -- paths relative to (or including) the scanned directory.
            if is_windows() and not line:match("^[/\\]?[%a]:[/\\]") then
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

    -- Optional region suffix, e.g. "en-US" or "en_US".
    local region = rest:match("^[-_]([%a][%a])")
    if region then
        tag = tag .. "-" .. region
        rest = rest:sub(4)
    end

    -- Anything left must be a separator-led suffix (e.g. ".forced").
    if rest ~= "" and not rest:match("^[%.%-_][%w%.%-_]*$") then
        return nil
    end

    return tag:lower()
end

-- Common language code aliases (3-letter and 2-letter forms).
-- canonical: tag -> canonical language id
local lang_canonical = {
    eng = "en", en = "en",
    dut = "nl", nl = "nl",
    ger = "de", de = "de",
}

-- Returns true if tag a and tag b refer to the same language.
local function same_lang(a, b)
    if a == b then return true end
    return (lang_canonical[a] or a) == (lang_canonical[b] or b)
end

-- Returns true when tag is the English language in any accepted form.
local function is_english(tag)
    return same_lang(tag, "en")
end

-- Returns true when tag looks like the combination "en-nl" produced by a
-- previous merge (two different known languages joined by '-' or '_').
-- This keeps merged output files out of the source dropdowns.
local function is_merged_tag(tag)
    local a, b = tag:match("^([%a]+)[-_]([%a]+)$")
    if not a or not b then return false end
    local ca, cb = lang_canonical[a], lang_canonical[b]
    return ca ~= nil and cb ~= nil and ca ~= cb
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

                if tag and not is_merged_tag(tag) then
                    subtitle_files[#subtitle_files + 1] = {
                        path = path,
                        tag = tag
                    }
                end
            end
        end
    end

    table.sort(subtitle_files, function(a, b)
        -- English first; otherwise sort by tag then path.
        local a_eng, b_eng = is_english(a.tag), is_english(b.tag)
        if a_eng ~= b_eng then return a_eng end
        if a.tag ~= b.tag then return a.tag < b.tag end
        return a.path:lower() < b.path:lower()
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
        order = order + 1
        cue.order = order
        cues[#cues + 1] = cue
    end
    for _, cue in ipairs(second_cues) do
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

-- One-line status log at the bottom of the dialog.
-- Prefixes every message with "STATUS: ". VLC 3.x dropdowns don't expose
-- change callbacks, so we log merge/refresh/error events here. VLC 3.x
-- dialogs do not have a dedicated statusbar component, so a label at the
-- bottom of the dialog is used instead.
local function log(message, color)
    if not status_label then return end

    if color then
        status_label:set_text(
            'STATUS: <font color="' .. color .. '">' .. message .. '</font>'
        )
    else
        status_label:set_text("STATUS: " .. message)
    end
end

-- Reads the selected entry id from a dropdown widget, or nil.
--
-- Each dropdown entry MUST be added with a unique id (its index in
-- subtitle_files). VLC's Qt SyncSelection() marks entries selected by
-- comparing ids; with duplicate ids every entry is marked selected and
-- get_value() always returns the first one. get_value() returns (id, text).
local function dropdown_value(widget)
    if not widget or type(widget.get_value) ~= "function" then
        return nil
    end

    local id = widget:get_value()
    if type(id) == "number" and id >= 1 then
        return id
    end
    return nil
end

-- Returns the subtitle entry with the given dropdown id (1-based), or nil.
local function find_by_id(id)
    if type(id) ~= "number" or id < 1 then return nil end
    return subtitle_files[id]
end

-- Resolves the two subtitle files chosen in the dropdowns, falling back to
-- sensible defaults (first file for primary, first different language for
-- secondary) when nothing (or something invalid) is selected.
local function resolve_selected()
    local first = find_by_id(dropdown_value(first_dd_widget))
                  or subtitle_files[1]

    if not first then return nil, nil end

    local second = find_by_id(dropdown_value(second_dd_widget))

    if not second then
        for _, sub in ipairs(subtitle_files) do
            if not same_lang(sub.tag, first.tag) then
                second = sub
                break
            end
        end
    end

    -- If every file is the same language, fall back to the second file.
    if not second and #subtitle_files >= 2 then
        second = subtitle_files[2]
    end

    -- Never merge a file with itself.
    if second and second.path == first.path then
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

        -- Close the extension once the merged subtitle is active. This is
        -- asynchronous in VLC, so the rest of this function still runs.
        if vlc.deactivate then
            vlc.deactivate()
        end
    else
        log("created " .. output_name ..
           " but VLC could not load it automatically.", "#00CC00")
    end
end

-- Asks the user whether to overwrite or skip an existing merged file.
-- VLC 3 allows only one dialog per extension, so the main dialog is
-- replaced by the prompt instead of opening a second window.
local function confirm_overwrite(first, second, output_path, output_name)
    if dlg then
        dlg:delete()
    end

    dlg = vlc.dialog("File Already Exists")
    status_label = nil

    dlg:add_label("The merged file already exists:", 1, 1, 3, 1)
    dlg:add_label(output_path, 1, 2, 3, 1)
    dlg:add_label("Overwrite it or skip this merge?", 1, 3, 3, 1)

    dlg:add_button("Overwrite", function()
        -- Restore the main dialog first so the merge result is logged there.
        refresh_dialog()
        do_merge(first, second, output_path, output_name)
    end, 1, 4, 1, 1)

    dlg:add_button("Skip", function()
        refresh_dialog()
        log("merge skipped: file already exists", "#FF6666")
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

        if not first.tag or first.tag == "" or
           not second.tag or second.tag == "" then
            log("error: could not read language tags from subtitle files.",
                "#FF6666")
            return
        end

        if same_lang(first.tag, second.tag) then
            log("both files have the same language tag.", "#FF6666")
            return
        end

        local output_name = video_stem .. "." ..
                            first.tag .. "-" .. second.tag .. ".srt"
        local output_path = path_join(video_dir, output_name)

        -- Ask before overwriting an existing merged file.
        local existing = io.open(output_path, "r")
        if existing then
            existing:close()
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

    local row = 1

    local function add_label(text, width)
        local widget = dlg:add_label(text, 1, row, width or 3, 1)
        row = row + 1
        return widget
    end

    local function add_refresh_button()
        dlg:add_button("Refresh", refresh_dialog, 1, row, 1, 1)
        row = row + 1
    end

    if not get_current_video() then
        add_label("No local video is currently playing.")
        add_label("Open a local video file, then click Refresh.")
        add_refresh_button()
        status_label = add_label("STATUS: refreshed: no video playing")
        return
    end

    scan_subtitles()

    add_label("Video: " .. basename(video_path))

    if #subtitle_files < 2 then
        add_label("Number of subtitle files found: " .. #subtitle_files)
        add_label("Select 2 files to merge! (NOTE: original files will not be modified)")
        add_label("Need at least 2 matching SRT files to merge.")
        add_label("Expected naming: video-name.<language>.srt")
        add_label("Example: movie.eng.srt and movie.fra.srt")
        add_refresh_button()
        status_label = add_label(
            "STATUS: refreshed: " .. #subtitle_files ..
            " subtitle file(s) found"
        )
        return
    end

    add_label("Number of subtitle files found: " .. #subtitle_files)
    add_label("Select 2 files to merge! (NOTE: original files will not be modified)")

    -- Stacked vertically: label, dropdown, label, dropdown.
    -- The second argument is the entry id, which must be unique: VLC's Qt
    -- UI matches selections by id.
    add_label("First language:", 4)
    first_dd_widget = dlg:add_dropdown("first_sub", 1, row, 4, 1)
    for i, sub in ipairs(subtitle_files) do
        first_dd_widget:add_value(sub.tag, i)
    end
    row = row + 1

    add_label("Second language (yellow)", 4)
    second_dd_widget = dlg:add_dropdown("second_sub", 1, row, 4, 1)
    for i = #subtitle_files, 1, -1 do
        second_dd_widget:add_value(subtitle_files[i].tag, i)
    end
    row = row + 1

    add_label("(note: the original files will not be harmed!)")

    dlg:add_button("Merge and load", merge_selected, 1, row, 2, 1)
    dlg:add_button("Refresh", refresh_dialog, 3, row, 2, 1)
    row = row + 1

    status_label = add_label(
        "STATUS: refreshed: " .. #subtitle_files .. " subtitle file(s) found",
        4
    )
end

-- Auto-refresh the dialog when the playing video changes.
function input_changed()
    refresh_dialog()
end
