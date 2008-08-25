---------------------------------------------------------------------------
-- Wicked widgets for the awesome window manager
---------------------------------------------------------------------------
-- Lucas de Vries <lucas@glacicle.com>
-- Licensed under the WTFPL
-- Version: v1.0pre-awe3.0rc4
---------------------------------------------------------------------------

-- Require libs
require("awful")

---- {{{ Grab environment
local ipairs = ipairs
local pairs = pairs
local print = print
local type = type
local tonumber = tonumber
local tostring = tostring
local math = math
local table = table
local awful = awful
local os = os
local io = io
local string = string

-- Grab C API
local capi =
{
    awesome = awesome,
    screen = screen,
    client = client,
    mouse = mouse,
    button = button,
    titlebar = titlebar,
    widget = widget,
    hooks = hooks,
    keygrabber = keygrabber
}

-- }}}

-- Wicked: Widgets for the awesome window manager
module("wicked")

---- {{{ Initialise variables
local registered = {}
local widget_cache = {}

-- Initialise function tables
widgets = {}
helper = {}

local nets = {}
local cpu_total = {}
local cpu_active = {}
local cpu_usage = {}

-- }}}

---- {{{ Helper functions
---- {{{ Format a string with args
function helper.format(format, args)
    -- TODO: Find a more efficient way to do this

    -- Format a string
    for var,val in pairs(args) do
        format = string.gsub(format, '$'..var, val)
    end

    -- Return formatted string
    return format
end
-- }}}

---- {{{ Convert amount of bytes to string
function helper.bytes_to_string(bytes, sec)
    if bytes == nil or tonumber(bytes) == nil then
        return ''
    end

    bytes = tonumber(bytes)

    signs = {}
    signs[1] = 'b'
    signs[2] = 'KiB'
    signs[3] = 'MiB'
    signs[4] = 'GiB'
    signs[5] = 'TiB'

    sign = 1

    while bytes/1024 > 1 and signs[sign+1] ~= nil do
        bytes = bytes/1024
        sign = sign+1
    end

    bytes = bytes*10
    bytes = math.floor(bytes)/10

    if sec then
        return tostring(bytes)..signs[sign]
    else
        return tostring(bytes)..signs[sign]..'ps'
    end
end
-- }}}

---- {{{ Split by whitespace
function helper.splitbywhitespace(str)
    values = {}
    start = 1
    splitstart, splitend = string.find(str, ' ', start)
    
    while splitstart do
        m = string.sub(str, start, splitstart-1)
        if m:gsub(' ','') ~= '' then
            table.insert(values, m)
        end

        start = splitend+1
        splitstart, splitend = string.find(str, ' ', start)
    end

    m = string.sub(str, start)
    if m:gsub(' ','') ~= '' then
        table.insert(values, m)
    end

    return values
end
-- }}}

-- }}}

---- {{{ Widget types

---- {{{ MPD widget type
function widgets.mpd()
    ---- Get data from mpc
    local nowplaying_file = io.popen('mpc')
    local nowplaying = nowplaying_file:read()

    -- Check that it's not nil
    if nowplaying == nil then
        return {''}
    end

    -- Close the command
    nowplaying_file:close()
    
    -- Escape
    nowplaying = awful.escape(nowplaying)

    -- Return it
    return {nowplaying}
end

widget_cache[widgets.mpd] = {}
-- }}}

---- {{{ CPU widget type
function widgets.cpu()
    -- Calculate CPU usage for all available CPUs / cores and return the
    -- usage

    -- Perform a new measurement
    ---- Get /proc/stat
    local cpu_lines = {}
    local cpu_usage_file = io.open('/proc/stat')
    for line in cpu_usage_file:lines() do
        if string.sub(line, 1, 3) == 'cpu' then
            table.insert(cpu_lines, helper.splitbywhitespace(line))
        end
    end
    cpu_usage_file:close()

    ---- Ensure tables are initialized correctly
    while #cpu_total < #cpu_lines do
        table.insert(cpu_total, 0)
    end
    while #cpu_active < #cpu_lines do
        table.insert(cpu_active, 0)
    end
    while #cpu_usage < #cpu_lines do
        table.insert(cpu_usage, 0)
    end

    ---- Setup tables
    total_new     = {}
    active_new    = {}
    diff_total    = {}
    diff_active   = {}

    for i,v in ipairs(cpu_lines) do
        ---- Calculate totals
        total_new[i]    = v[2] + v[3] + v[4] + v[5]
        active_new[i]   = v[2] + v[3] + v[4]
    
        ---- Calculate percentage
        diff_total[i]   = total_new[i]  - cpu_total[i]
        diff_active[i]  = active_new[i] - cpu_active[i]
        cpu_usage[i]    = math.floor(diff_active[i] / diff_total[i] * 100)

        ---- Store totals
        cpu_total[i]    = total_new[i]
        cpu_active[i]   = active_new[i]
    end

    return cpu_usage
end

widget_cache[widgets.cpu] = {}
-- }}}

---- {{{ Memory widget type
function widgets.mem()
    -- Return MEM usage values
    local f = io.open('/proc/meminfo')

    ---- Get data
    for line in f:lines() do
        line = helper.splitbywhitespace(line)

        if line[1] == 'MemTotal:' then
            mem_total = math.floor(line[2]/1024)
        elseif line[1] == 'MemFree:' then
            free = math.floor(line[2]/1024)
        elseif line[1] == 'Buffers:' then
            buffers = math.floor(line[2]/1024)
        elseif line[1] == 'Cached:' then
            cached = math.floor(line[2]/1024)
        end
    end
    f:close()

    ---- Calculate percentage
    mem_free=free+buffers+cached
    mem_inuse=mem_total-mem_free
    mem_usepercent = math.floor(mem_inuse/mem_total*100)

    return {mem_usepercent, mem_inuse, mem_total, mem_free}
end

widget_cache[widgets.mem] = {}
-- }}}

---- {{{ Swap widget type
function widgets.swap()
    -- Return SWAP usage values
    local f = io.open('/proc/meminfo')

    ---- Get data
    for line in f:lines() do
        line = helper.splitbywhitespace(line)

        if line[1] == 'SwapTotal:' then
            swap_total = math.floor(line[2]/1024)
        elseif line[1] == 'SwapFree:' then
            free = math.floor(line[2]/1024)
        elseif line[1] == 'SwapCached:' then
            cached = math.floor(line[2]/1024)
        end
    end
    f:close()

    ---- Calculate percentage
    swap_free=free+cached
    swap_inuse=swap_total-swap_free
    swap_usepercent = math.floor(swap_inuse/swap_total*100)

    return {swap_usepercent, swap_inuse, swap_total, swap_free}
end

widget_cache[widgets.swap] = {}
-- }}}

---- {{{ Date widget type
function widgets.date(format)
    -- Get format
    if format == nil then
        return os.date()
    else
        return os.date(format)
    end
end
-- }}}

---- {{{ Filesystem widget type
function widgets.fs()
    local f = io.popen('df -h')
    local args = {}

    for line in f:lines() do
        vars = helper.splitbywhitespace(line)
        
        if vars[1] ~= 'Filesystem' then
            args['{'..vars[6]..' size}'] = vars[2]
            args['{'..vars[6]..' used}'] = vars[3]
            args['{'..vars[6]..' avail}'] = vars[4]
            args['{'..vars[6]..' usep}'] = vars[5]:gsub('%%','')
        end
    end

    f:close()
    return args
end
-- }}}

---- {{{ Net widget type
function widgets.net()
    local f = io.open('/proc/net/dev')
    args = {}

    for line in f:lines() do
        line = helper.splitbywhitespace(line)

        local p = line[1]:find(':')
        if p ~= nil then
            name = line[1]:sub(0,p-1)
            line[1] = line[1]:sub(p+1)

            if tonumber(line[1]) == nil then
                line[1] = line[2]
                line[9] = line[10]
            end

            args['{'..name..' rx}'] = helper.bytes_to_string(line[1])
            args['{'..name..' tx}'] = helper.bytes_to_string(line[9])

            args['{'..name..' rx_b}'] = math.floor(line[1]*10)/10
            args['{'..name..' tx_b}'] = math.floor(line[9]*10)/10
            
            args['{'..name..' rx_kb}'] = math.floor(line[1]/1024*10)/10
            args['{'..name..' tx_kb}'] = math.floor(line[9]/1024*10)/10

            args['{'..name..' rx_mb}'] = math.floor(line[1]/1024/1024*10)/10
            args['{'..name..' tx_mb}'] = math.floor(line[9]/1024/1024*10)/10

            args['{'..name..' rx_gb}'] = math.floor(line[1]/1024/1024/1024*10)/10
            args['{'..name..' tx_gb}'] = math.floor(line[9]/1024/1024/1024*10)/10

            if nets[name] == nil then 
                nets[name] = {}
                args['{'..name..' down}'] = 'n/a'
                args['{'..name..' up}'] = 'n/a'
                
                args['{'..name..' down_b}'] = 0
                args['{'..name..' up_b}'] = 0

                args['{'..name..' down_kb}'] = 0
                args['{'..name..' up_kb}'] = 0

                args['{'..name..' down_mb}'] = 0
                args['{'..name..' up_mb}'] = 0

                args['{'..name..' down_gb}'] = 0
                args['{'..name..' up_gb}'] = 0
            else
                down = (line[1]-nets[name][1])/info['timer']
                up = (line[9]-nets[name][2])/info['timer']

                args['{'..name..' down}'] = helper.bytes_to_string(down)
                args['{'..name..' up}'] = helper.bytes_to_string(up)

                args['{'..name..' down_b}'] = math.floor(down*10)/10
                args['{'..name..' up_b}'] = math.floor(up*10)/10

                args['{'..name..' down_kb}'] = math.floor(down/1024*10)/10
                args['{'..name..' up_kb}'] = math.floor(up/1024*10)/10

                args['{'..name..' down_mb}'] = math.floor(down/1024/1024*10)/10
                args['{'..name..' up_mb}'] = math.floor(up/1024/1024*10)/10

                args['{'..name..' down_gb}'] = math.floor(down/1024/1024/1024*10)/10
                args['{'..name..' up_gb}'] = math.floor(up/1024/1024/1024*10)/10
            end

            nets[name][1] = line[1]
            nets[name][2] = line[9]
        end
    end

    f:close()
    return args
end
-- }}}

-- For backwards compatibility: custom function
widgets["function"] = function ()
    return {}
end

-- }}}

---- {{{ Main functions
---- {{{ Register widget
function register(widget, wtype, format, timer, field)
    local reg = {}
    local widget = widget
    
    -- Set properties
    reg.type = wtype
    reg.format = format
    reg.timer = timer
    reg.field = field

    -- Allow using a string widget type
    if type(reg.type) == "string" then
        reg.type = widgets[reg.type]
    end

    -- Put widget in table
    registered[widget] = reg

    -- Start timer
    awful.hooks.timer.register(timer, function ()
        update(widget)
    end)
end
-- }}}

---- {{{ Update widget
function update(widget)
    -- Get information
    local reg = registered[widget]

    -- Check if there are any equal widgets
    if reg == nil then
        for w, i in pairs(registered) do
            if w == widget then
                update(w)
            end
        end

        return
    end

    local t = os.time()
    local data = {}

    -- Check if we have output chached for this widget,
    -- newer than last widget update.
    if widget_cache[reg.type] ~= nil then
        local c = widget_cache[reg.type]

        if c.time == nil or c.time <= t-reg.timer then
            c.time = t
            c.data = reg.type(reg.format)
        end
        
        data = c.data
    else
        data = reg.type(reg.format)
    end
    
    if type(reg.format) == "string" then
        data = helper.format(reg.format, data)
    elseif type(reg.format) == "function" then
        data = reg.format(widget, data)
    end
    
    if reg.field == nil then
        widget.text = data
    elseif widget.plot_data_add ~= nil then
        widget:plot_data_add(reg.field, tonumber(data))
    elseif widget.bar_data_add ~= nil then
        widget:bar_data_add(reg.field, tonumber(data))
    end

    return data
end

-- }}}

-- }}}

-- vim: set filetype=lua fdm=marker tabstop=4 shiftwidth=4 nu:
