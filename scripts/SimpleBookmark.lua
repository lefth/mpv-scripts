local o = {
----------------------------USER CUSTOMIZATION SETTINGS-----------------------------------
--These settings are for users to manually change some options.
--Changes are recommended to be made in the script-opts directory. It can also be made here although not recommended.

    -- Script Settings
    auto_run_idle = false, --Runs automatically when idle and no video is loaded --idle
	bookmark_loads_last_idle = true, --When attempting to bookmark, if there is no file, it will instead jump to your last bookmarked item
    show_paths = false, --Show file paths instead of media-title
    resume_offset = -0.65, --change to 0 so that bookmark resumes from the exact position, or decrease the value so that it gives you a little preview before loading the resume point
    osd_messages = true, --true is for displaying osd messages when actions occur. Change to false will disable all osd messages generated from this script
    
    -- Logging Settings
    log_path = mp.find_config_file('.'):match('@?(.*/)'), --Change to debug.getinfo(1).source:match('@?(.*/)') for placing it in the same directory of script, OR change to mp.find_config_file('.'):match('@?(.*/)') for mpv portable_config directory OR specify the desired path in quotes, e.g.: 'C:\Users\Eisa01\Desktop\'
    log_file = 'mpvBookmark.log', --name+extension of the file that will be used to store the log data	
	date_format = '%d/%m/%y %X', --Date format in the log (see lua date formatting), e.g.:'%d/%m/%y %X' or '%d/%b/%y %X'
    bookmark_time_text = 'time=', --The text that is stored for the video time inside log file, you can also leave it blank
    file_title_logging = 'protocols', --Change between 'all', 'protocols, 'none'. This option will store the media title in log file, it is useful for websites / protocols because title cannot be parsed from links alone	
    protocols = { --add below (after a comma) any protocol you want its title to be stored in the log file. This is valid only for (file_title_logging = 'protocols')
        'https?://' ,'magnet:', 'rtmp:'
    },
    prefer_filename_over_title = 'local', --Prefers to use filename over filetitle. Select between 'local', 'protocols', 'all', and 'none'. 'local' prefer filenames for videos that are not protocols. 'protocols' will prefer filenames for protocols only. 'all' will prefer filename over filetitle for both protocols and not protocols videos. 'none' will always use filetitle instead of filename
	
    -- Boorkmark Menu Settings
    text_color = 'ffffff', --Text color for list in BGR hexadecimal
    text_scale = 50, --Font size for the text of bookmark list
    text_border = 0.7, --Black border size for the text of bookmark list
    highlight_color = 'ffbf7f', --Highlight color in BGR hexadecimal
    highlight_scale = 50, --Font size for highlighted text in bookmark list
    highlight_border = 0.7 , --Black border size for highlighted text in bookmark list
    header_text = '🔖 Bookmarks [%cursor/%total]', --Text to be shown as header for the bookmark list. %cursor shows the position of highlighted file. %total shows the total amount of bookmarked items.
    header_color = 'ffffaa', --Header color in BGR hexadecimal
    header_scale = 55, --Header text size for the bookmark list
    header_border = 0.8, --Black border size for the Header of bookmark list
    show_item_number = true, --Show the number of each bookmark item before displaying its name and values.
    slice_longfilenames = false, --Change to true or false. Slices long filenames per the amount specified below
    slice_longfilenames_amount = 55, --Amount for slicing long filenames
    time_seperator=' 🕒 ', --The seperator that will be used after title / filename for bookmarked time 
    list_show_amount = 10, --Change maximum number to show items at once
    list_sliced_prefix = '...\\h\\N\\N', --The text that indicates there are more items above. \\h\\N\\N is for new line.
    list_sliced_suffix = '...', --The text that indicates there are more items below.
	list_cursor_middle_loader = true, --False for more items to show u must reach the end. Change to true so that new items show after reaching the middle of list.
    -- Keybind Settings: to bind multiple keys separate them by a space, e.g.:'ctrl+b ctrl+x'
    bookmark_list_keybind = 'b B', --Keybind that will be used to display the bookmark list
    bookmark_save_keybind = 'ctrl+b ctrl+B', --Keybind that will be used to save the video and its time to bookmark file
	bookmark_fileonly_keybind = 'alt+b alt+B', --Keybind that will be used to save the video without time to bookmark file
    list_move_up_keybind = 'UP WHEEL_UP', --Keybind that will be used to navigate up on the bookmark list
    list_move_down_keybind = 'DOWN WHEEL_DOWN', --Keybind that will be used to navigate down on the bookmark list
    list_page_up_keybind = 'PGUP LEFT', --Keybind that will be used to go to the first item for the page shown on the bookmark list
    list_page_down_keybind = 'PGDWN RIGHT', --Keybind that will be used to go to the last item for the page shown on the bookmark list
    list_move_first_keybind = 'HOME', --Keybind that will be used to navigate to the first item on the bookmark list
    list_move_last_keybind = 'END', --Keybind that will be used to navigate to the last item on the bookmark list
    list_select_keybind = 'ENTER MBTN_MID', --Keybind that will be used to load highlighted entry from the bookmark list
    list_close_keybind = 'ESC MBTN_RIGHT', --Keybind that will be used to close the bookmark list
    list_delete_keybind = 'DEL', --Keybind that will be used to delete the highlighted entry from the bookmark list
    quickselect_0to9_keybind = true, --Keybind entries from 0 to 9 for quick selection when list is open (list_show_amount = 10 is maximum for this feature to work)	
---------------------------END OF USER CUSTOMIZATION SETTINGS---------------------
}
-- Copyright (c) 2021, Eisa AlAwadhi
-- License: BSD 2-Clause License

-- Creator: Eisa AlAwadhi
-- Project: SimpleBookmark
-- Version: 1.0

(require 'mp.options').read_options(o)
local utils = require 'mp.utils'
local msg = require 'mp.msg'
--1.0# global variables
local bookmark_log = o.log_path .. o.log_file
local selected = false --1.0# initiate the selected flag, defaults to false

local list_contents = {}
local list_start = 0
local list_cursor = 1
local list_drawn = false

local filePath, fileTitle, seekTime

function starts_protocol (tab, val)
    for index, value in ipairs(tab) do
        if (val:find(value) == 1) then
            return true
        end
    end
    return false
end

function format_time(duration)
    local total_seconds = math.floor(duration)
    local hours = (math.floor(total_seconds / 3600))
    total_seconds = (total_seconds % 3600)
    local minutes = (math.floor(total_seconds / 60))
    local seconds = (total_seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, seconds) 
end

function parse_header(string)
    return string:gsub("%%total", #list_contents)
                :gsub("%%cursor", list_cursor)
                -- undo name escape
                :gsub("%%%%", "%%")
end

function bind_keys(keys, name, func, opts)
    if not keys then
    mp.add_forced_key_binding(keys, name, func, opts)
    return
    end
    local i = 1
    for key in keys:gmatch("[^%s]+") do
    local prefix = i == 1 and '' or i
    mp.add_forced_key_binding(key, name..prefix, func, opts)
    i = i + 1
    end
end

function unbind_keys(keys, name)
    if not keys then
    mp.remove_key_binding(name)
    return
    end
    local i = 1
    for key in keys:gmatch("[^%s]+") do
    local prefix = i == 1 and '' or i
    mp.remove_key_binding(name..prefix)
    i = i + 1
    end
end

function list_move_up()
    select(-1)
end

function list_move_down()
    select(1)
end

function list_move_first()
    select(1-list_cursor)
end

function list_move_last()
    select(#list_contents-list_cursor)
end

function list_page_up()
    select(list_start+1 - list_cursor) --1.0# Go to the first seen entry
end

function list_page_down()
	if o.list_cursor_middle_loader then
		select(o.list_show_amount + list_start - list_cursor) --1.0# Move to the last shown entry
	else
		if o.list_show_amount > list_cursor then--1.0# At the begining move to 10
			select(o.list_show_amount - list_cursor)
		elseif #list_contents-list_cursor >= o.list_show_amount then --1.0# If the remaining is larger or equal to page value then move the amount number
			select(o.list_show_amount)
		else --1.0# if the desired amount, does not exist just go to end
			select(#list_contents-list_cursor)
		end
	end
end

function list_select()
    load(list_cursor)
end

function list_delete()
    delete()
    list_contents = read_log_table()
    if not list_contents or not list_contents[1] then
        unbind()
        return
    end
	if list_cursor ~= #list_contents+1 then --1.0# needed if statement to specially handle the deleting last item
		select(0)
	else
		select(-1)
	end
end

function list_refresh()
	if list_drawn then
		list_contents = read_log_table()
		if not list_contents or not list_contents[1] then
			unbind()
			return
		end
		select(0)
	end
end

function esc_string(str)
    return str:gsub("([%p])", "%%%1")
end

function get_path()
    local path = mp.get_property('path')
	local title = mp.get_property('media-title'):gsub("\"", "")
	
	if starts_protocol(o.protocols, path) and o.prefer_filename_over_title == 'protocols' then
		title = mp.get_property('filename'):gsub("\"", "")
	elseif not starts_protocol(o.protocols, path) and o.prefer_filename_over_title == 'local' then
		title = mp.get_property('filename'):gsub("\"", "")
	elseif o.prefer_filename_over_title == 'all' then
		title = mp.get_property('filename'):gsub("\"", "")
	end
	
    if not path then return end
    return path, title
end

function unbind()
    unbind_keys(o.list_move_up_keybind, "move-up")
    unbind_keys(o.list_move_down_keybind, "move-down")
    unbind_keys(o.list_move_first_keybind, "move-first")
    unbind_keys(o.list_move_last_keybind, "move-last")
    unbind_keys(o.list_page_up_keybind, "page-up")
    unbind_keys(o.list_page_down_keybind, "page-down")
    unbind_keys(o.list_select_keybind, "list-select")
    unbind_keys(o.list_delete_keybind, "list-delete")
    unbind_keys(o.list_close_keybind, "list-close")
	if o.quickselect_0to9_keybind and o.list_show_amount <= 10 then
		mp.remove_key_binding("recent-1")
		mp.remove_key_binding("recent-2")
		mp.remove_key_binding("recent-3")
		mp.remove_key_binding("recent-4")
		mp.remove_key_binding("recent-5")
		mp.remove_key_binding("recent-6")
		mp.remove_key_binding("recent-7")
		mp.remove_key_binding("recent-8")
		mp.remove_key_binding("recent-9")
		mp.remove_key_binding("recent-0")
	end
    mp.set_osd_ass(0, 0, "")
    list_drawn = false
    list_cursor = 1
    list_start = 0
end

function read_log(func)
    local f = io.open(bookmark_log, "r")
    if not f then return end
    list_contents = {}
    for line in f:lines() do
        table.insert(list_contents, (func(line)))
    end
    f:close()
    return list_contents
end

function read_log_table()
    return read_log(function(line)
        local p, t, d, n, e
        if line:match("^.-\"(.-)\"") then --#1.0 If there is a title, then match the parameters after title
            n, p, t = line:match("^.-\"(.-)\" | (.*) | (.*)$") --#1.0 Get the name, path, and time
        else
            p, t = line:match("[(.*)%]]%s(.*) | (.*)$") --1.0# Get the content thats square brackets and until time reached
            d, n, e = p:match("^(.-)([^\\/]-)%.([^\\/%.]-)%.?$")--1.0# Finds directory, name, and extension (I only need name). I might need rest in the future
        end
        return {found_path = p, found_time = t, found_name = n}
    end)
end

-- Write path to log on file end
-- removing duplicates along the way
function write_log(delete, file_only)
    if not filePath then return end
    if not delete then --1.0#When using delete, get the time of the choice selected, otherwise seekTime will be updated when logging
        seekTime = (mp.get_property_number('time-pos') or 0)
    end
	if file_only then --1.0# Set time to 0 if saving time is not required
		seekTime = 0
	end
	if seekTime < 0 then seekTime = 0 end --Handle if time became negative or something
    local content = read_log(function(line)
        if line:find(esc_string(filePath)..'(.*)'..esc_string(o.bookmark_time_text)..math.floor(seekTime)) then --1.0# if it finds the filePath and the time, then do not bookmark it so we avoid duplicates
            return nil
        else
            return line
        end
    end)
    f = io.open(bookmark_log, "w+")
    if content then
        for i=1, #content do
            f:write(("%s\n"):format(content[i]))
        end
    end
    if not delete then
        if o.file_title_logging == 'all' then
            f:write(("[%s] \"%s\" | %s | %s\n"):format(os.date(o.date_format), fileTitle, filePath, o.bookmark_time_text..tostring(seekTime)))
        elseif o.file_title_logging == 'protocols' and (starts_protocol(o.protocols, filePath)) then
            f:write(("[%s] \"%s\" | %s | %s\n"):format(os.date(o.date_format), fileTitle, filePath, o.bookmark_time_text..tostring(seekTime)))
        elseif o.file_title_logging == 'protocols' and not (starts_protocol(o.protocols, filePath)) then
            f:write(("[%s] %s | %s\n"):format(os.date(o.date_format), filePath, o.bookmark_time_text..tostring(seekTime)))
        else
            f:write(("[%s] %s | %s\n"):format(os.date(o.date_format), filePath, o.bookmark_time_text..tostring(seekTime)))
        end
    end
    f:close()
end

-- Display list on OSD and terminal
function draw_list()
    --1.0# font and color options for text, highlighted text, and header 
	local key = 0--for 0to9 quickselect
    local osd_msg = ''
    local osd_text = string.format("{\\fscx%f}{\\fscy%f}{\\bord%f}{\\1c&H%s}", o.text_scale, o.text_scale, o.text_border, o.text_color)
    local osd_highlight = string.format("{\\fscx%f}{\\fscy%f}{\\bord%f}{\\1c&H%s}", o.highlight_scale, o.highlight_scale, o.highlight_border, o.highlight_color)
    local osd_header = string.format("{\\fscx%f}{\\fscy%f}{\\bord%f}{\\1c&H%s}", o.header_scale, o.header_scale,o.header_border, o.header_color)
    local osd_msg_end = "{\\1c&HFFFFFF}"
	
    if o.header_text ~= '' then --1.0# 
        osd_msg = osd_msg..osd_header..parse_header(o.header_text).."\\h\\N\\N"..osd_msg_end
    end
    
    local osd_key = ''--1.0#Parameters for optional stuff so that if the optional value is not defined, it wont append osd_key

    if o.list_cursor_middle_loader then --1.0# To start showing items from middle
		list_start = list_cursor - math.floor(o.list_show_amount/2)
	else --1.0# Else it will start showing after reaching the bottom
		list_start = list_cursor - o.list_show_amount
	end
    local showall = false
    local showrest = false
    if list_start<0 then list_start=0 end
    if #list_contents <= o.list_show_amount then
        list_start=0
        showall=true
    end
    if list_start > math.max(#list_contents-o.list_show_amount-1, 0) then
        list_start=#list_contents-o.list_show_amount
        showrest=true
    end
    if list_start > 0 and not showall then 
        osd_msg = osd_msg..o.list_sliced_prefix..osd_msg_end 
    end
    for i=list_start,list_start+o.list_show_amount-1,1 do
        if i == #list_contents then break end
        --1.0#My Stuff before outputting text
        local parsed_logtime = string.match(list_contents[#list_contents-i].found_time, esc_string(o.bookmark_time_text)..'(.*)')--1.0# To parse time from log file to numbers using its variable
        if o.show_paths then
            p = list_contents[#list_contents-i].found_path or list_contents[#list_contents-i].found_name or ""
        else
            p = list_contents[#list_contents-i].found_name or list_contents[#list_contents-i].found_path or ""
        end

        if o.slice_longfilenames and p:len()>o.slice_longfilenames_amount then --1.0# slices long names as per setting
            p = p:sub(1, o.slice_longfilenames_amount).."..."
        end

        if o.quickselect_0to9_keybind and o.list_show_amount <= 10 then --1.0# Only show 0-9 keybinds if enabled
			key = 1 + key
			if key == 10 then key = 0 end
            osd_key = '('..key..')  '
        end

        if o.show_item_number then
            osd_index = (i+1)..'. '
        end
        --1.0# End of my Stuff before outputting text
        if i+1 == list_cursor then
			if tonumber(parsed_logtime) > 0 then
				osd_msg = osd_msg..osd_highlight..osd_key..osd_index..p..o.time_seperator..format_time(parsed_logtime)..'\\h\\N\\N'..osd_msg_end
			else 
				osd_msg = osd_msg..osd_highlight..osd_key..osd_index..p..'\\h\\N\\N'..osd_msg_end
			end
        else
			if tonumber(parsed_logtime) > 0 then
				osd_msg = osd_msg..osd_text..osd_key..osd_index..p..o.time_seperator..format_time(parsed_logtime)..'\\h\\N\\N'..osd_msg_end
			else
				osd_msg = osd_msg..osd_text..osd_key..osd_index..p..'\\h\\N\\N'..osd_msg_end
			end
        end
        if i == list_start+o.list_show_amount-1 and not showall and not showrest then
            osd_msg = osd_msg..o.list_sliced_suffix
        end
    end
    mp.set_osd_ass(0, 0, osd_msg)
end

-- Handle up/down keys
function select(pos)    
    local list_cursor_temp = list_cursor + pos --1.0#Gets the cursor position
    if list_cursor_temp > 0 and list_cursor_temp <= #list_contents then 
        list_cursor = list_cursor_temp
    end
    draw_list()
end

-- Delete selected entry from the log
function delete()
    local playing_path = filePath
    filePath = list_contents[#list_contents-list_cursor+1].found_path
    local parsed_logtime = string.match(list_contents[#list_contents-list_cursor+1].found_time, esc_string(o.bookmark_time_text)..'(.*)')--1.0# To parse time from log file to numbers using its variable
    seekTime = tonumber(parsed_logtime)
    if not filePath and not seekTime then
        msg.info("Failed to delete")
        return
    end
    write_log(true, false)
    msg.info("Deleted \""..filePath.."\" | "..format_time(seekTime))
    filePath = playing_path
end

-- Load file and remove binds
function load(list_cursor)
    unbind()
    local parsed_logtime = string.match(list_contents[#list_contents-list_cursor+1].found_time, esc_string(o.bookmark_time_text)..'(.*)')--1.0# To parse time from log file to numbers using its variable
    seekTime = tonumber(parsed_logtime) + o.resume_offset
    if (seekTime < 0) then
        seekTime = 0
    end
    mp.commandv('loadfile', list_contents[#list_contents-list_cursor+1].found_path)
    selected = true --1.0# to only resume when a file is selected
end

-- Display list and add keybinds
function display_list()
    if list_drawn then
        unbind()
        return
    end
    list_contents = read_log_table()
    if not list_contents or not list_contents[1] then
		msg.info("Bookmark file is empty")
		if o.osd_messages == true then
			mp.osd_message("Bookmark Empty")
		end
        return
    end
    draw_list()
    list_drawn = true

    bind_keys(o.list_move_up_keybind, "move-up", list_move_up, 'repeatable')
    bind_keys(o.list_move_down_keybind, "move-down", list_move_down, 'repeatable')
    bind_keys(o.list_move_first_keybind, "move-first", list_move_first, 'repeatable')
    bind_keys(o.list_move_last_keybind, "move-last", list_move_last, 'repeatable')
	bind_keys(o.list_page_up_keybind, "page-up", list_page_up, 'repeatable')
    bind_keys(o.list_page_down_keybind, "page-down", list_page_down, 'repeatable')
    bind_keys(o.list_select_keybind, "list-select", list_select)
    bind_keys(o.list_delete_keybind, "list-delete", list_delete)
    bind_keys(o.list_close_keybind, "list-close", unbind)
    if o.quickselect_0to9_keybind and o.list_show_amount <= 10 then --1.0# Only show 0-9 keybinds if enabled
        mp.add_forced_key_binding("1", "recent-1", function() load(list_start+1) end)
        mp.add_forced_key_binding("2", "recent-2", function() load(list_start+2) end)
        mp.add_forced_key_binding("3", "recent-3", function() load(list_start+3) end)
        mp.add_forced_key_binding("4", "recent-4", function() load(list_start+4) end)
        mp.add_forced_key_binding("5", "recent-5", function() load(list_start+5) end)
        mp.add_forced_key_binding("6", "recent-6", function() load(list_start+6) end)
        mp.add_forced_key_binding("7", "recent-7", function() load(list_start+7) end)
        mp.add_forced_key_binding("8", "recent-8", function() load(list_start+8) end)
        mp.add_forced_key_binding("9", "recent-9", function() load(list_start+9) end)
        mp.add_forced_key_binding("0", "recent-0", function() load(list_start+10) end)
    end
end

function bookmark_save()
    if filePath ~= nil then
        write_log(false, false)
		if list_drawn then
			list_refresh()
		end
		if o.osd_messages == true then
			mp.osd_message('Bookmarked:\n'..fileTitle..o.time_seperator..format_time(seekTime))
		end
        msg.info('Added the below to bookmarks\n'..fileTitle..o.time_seperator..format_time(seekTime))
    elseif filePath == nil and o.bookmark_loads_last_idle then
		    list_contents = read_log_table()
			if not list_contents or not list_contents[1] then
				msg.info("Bookmark file is empty")
				if o.osd_messages == true then
					mp.osd_message("Bookmark Empty")
				end
				return
			end
			load(1)
			if o.osd_messages == true then
				mp.osd_message('Loaded Last Bookmark File:\n'..list_contents[#list_contents].found_name..o.time_seperator..format_time(seekTime))
			end
			msg.info('Loaded the last bookmarked file shown below into mpv:\n'..list_contents[#list_contents].found_name..o.time_seperator..format_time(seekTime))
	else
        if o.osd_messages == true then
            mp.osd_message('Failed to Bookmark\nNo Video Found')
        end
        msg.info("Failed to bookmark, no video found")
    end
end

function bookmark_fileonly_save()
    if filePath ~= nil then
        write_log(false, true)
		if list_drawn then
			list_refresh()
		end
		if o.osd_messages == true then
			mp.osd_message('Bookmarked File Only:\n'..fileTitle)
		end
        msg.info('Added the below to bookmarks\n'..fileTitle)
	elseif filePath == nil and o.bookmark_loads_last_idle then
		list_contents = read_log_table()
		if not list_contents or not list_contents[1] then
			msg.info("Bookmark file is empty")
			if o.osd_messages == true then
				mp.osd_message("Bookmark Empty")
			end
			return
		end
		load(1)
		if o.osd_messages == true then
			mp.osd_message('Loaded Last Bookmark File:\n'..list_contents[#list_contents].found_name..o.time_seperator..format_time(seekTime))
		end
		msg.info('Loaded the last bookmarked file shown below into mpv:\n'..list_contents[#list_contents].found_name..o.time_seperator..format_time(seekTime))
    else
        if o.osd_messages == true then
            mp.osd_message('Failed to Bookmark\nNo Video Found')
        end
        msg.info("Failed to bookmark, no video found")
    end
end

if o.auto_run_idle then
    mp.observe_property("idle-active", "bool", function(_, v)
        if v then display_list() end
    end)
end

mp.register_event("file-loaded", function()
    unbind()
    filePath, fileTitle = get_path()
    if (selected == true and seekTime ~= nil) then --1.0# After selecting bookmark, if there is seekTime then go to it
        mp.commandv('seek', seekTime, 'absolute', 'exact')
        selected = false --1.0# Reset the selected flag
    end
end)

bind_keys(o.bookmark_list_keybind, 'bookmark-list', display_list)
bind_keys(o.bookmark_save_keybind, 'bookmark-save', bookmark_save)
bind_keys(o.bookmark_fileonly_keybind, 'bookmark-fileonly', bookmark_fileonly_save)