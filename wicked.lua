-- 'Wicked' lua library, require it in .awesomerc.lua to create dynamic widgets
-- Author: Lucas `GGLucas` de Vries [lucasdevries@gmail.com]

-- Get package name
local P = {}
if _REQUIREDNAME == nil then
    wicked = P
else
    _G[_REQUIREDNAME] = P
end

-- Grab environment
local ipairs = ipairs
local pairs = pairs
local print = print
local type = type
local tonumber = tonumber
local tostring = tostring
local math = math
local table = table
local awful = awful
local awesome = awesome
local client = client
local tag = tag
local mouse = mouse
local os = os
local io = io
local string = string
local hooks = hooks

-- Init variables
local widgets = {}
local nextid = 1
local cpu_total = 0
local cpu_active = 0
local Started = 0
local nets = {}

-- Reset environment
setfenv(1, P)

function register(widget, type, format, timer, field)
    -- Register a new widget into wicked
    if timer == nil then
        timer = 1
    end

    if field == nil then
        field = 'text'
    end

    widgets[nextid] = {
        widget = widget,
        type = type,
        timer = timer,
        count = timer,
        format = format,
        field = field
    }

    -- Incement ID
    nextid = nextid+1

    -- Check if the wicked main loop has started yet
    if Started == 0 then
        -- Start the main loop
        start()
        Started = 1
    end
end

function start(interval)
    -- Start the wicked main loop
    if interval == nil then
        interval = 1
    end

    hooks.timer(interval, main)
end

function main()
    -- Run all the widget timers and check if we should update them
    for id, vals in pairs(widgets) do
        widgets[id]['count'] = widgets[id]['count']+1

        if widgets[id]['count'] >= widgets[id]['timer'] then
            update(id)
            widgets[id]['count'] = 0
        end
    end
end

function format(format, widget, args)
    -- Format a string with the given arguments
    for var,val in pairs(args) do
        format = string.gsub(format, '$'..var, val)
    end

    return format
end

function splitbywhitespace(str)
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

function update(id)
    -- Update a specific widget
    local info = widgets[id]
    local args = {}
    local func = nil

    if info['type']:lower() == 'mem' then
        args = get_mem()
    end

    if info['type']:lower() == 'mpd' then
        args = get_mpd()
    end
    
    if info['type']:lower() == 'fs' then
        args = get_fs()
    end

    if info['type']:lower() == 'cpu' then
        args = get_cpu()
    end

    if info['type']:lower() == 'net' then
        args = get_net(info)
    end

    if info['type']:lower() == 'date' then
        if info['format'] ~= nil then
            args = {info['format']}
        end
        func = get_time
    end

    if type(info['format']) == 'function' then
        func = info['format']
    end

    if type(func) == 'function' then
        output = func(info['widget'], args)
    else
        output = format(info['format'], info['widget'], args)
    end

    if output == nil then
        output = ''
    end

    info['widget']:set(info['field'], output)
end



function get_cpu()
    -- Return CPU usage percentage
    ---- Get /proc/stat
    local cpu_usage_file = io.open('/proc/stat')
    local cpu_usage = cpu_usage_file:read()
    cpu_usage_file:close()
    cpu_usage = splitbywhitespace(cpu_usage)

    ---- Calculate totals
    total_new = cpu_usage[2]+cpu_usage[3]+cpu_usage[4]+cpu_usage[5]
    active_new = cpu_usage[2]+cpu_usage[3]+cpu_usage[4]
    
    ---- Calculate percentage
    diff_total = total_new-cpu_total
    diff_active = active_new-cpu_active
    usage_percent = math.floor(diff_active/diff_total*100)

    ---- Store totals
    cpu_total = total_new
    cpu_active = active_new

    ---- Check if extra zero is needed
    if tonumber(usage_percent) < 10 then
       usage_percent = '0'..usage_percent
    end

    return {usage_percent}
end

function get_mpd()
    -- Return MPD currently playing song
    ---- Get data from mpc
    local nowplaying_file = io.popen('mpc')
    local nowplaying = nowplaying_file:read()
    nowplaying_file:close()
    
    nowplaying = nowplaying:gsub('&', '&amp;')

    -- Return it
    return {nowplaying}
end

function get_mem()
    -- Return MEM usage values
    ---- Get data
    local mem_usage_file = io.popen('free -m')
    mem_usage_file:read() mem_usage_file:read()
    local mem_usage = mem_usage_file:read()
    mem_usage_file:close()

    ---- Split data
    mem_usage = splitbywhitespace(mem_usage)
    
    ---- Calculate percentage
    mem_total = mem_usage[3]+mem_usage[4]
    mem_inuse = mem_usage[3]
    mem_free = mem_usage[4]
    mem_usepercent = math.floor(mem_inuse/mem_total*100)

    ---- Add zeroes
    if tonumber(mem_usepercent) < 10 then
        mem_usepercent = '0'..mem_usepercent
    end

    if tonumber(mem_inuse) < 1000 then
        mem_inuse = '0'..mem_inuse
    end

    return {mem_usepercent, mem_inuse, mem_total, mem_free}
end

function get_time(widget, args)
    -- Return a `date` processed format
    -- Get format
    local f
    
    if args[1] == nil then
        f = io.popen('date')
    else
        args[1] = args[1]:gsub('"', '\\"')
        f = io.popen('date +"'..args[1]..'"')
    end

    local date = f:read()
    f:close()

    -- Return it
    return date
end

function get_fs()
    local f = io.popen('df -h')
    local args = {}

    for line in f:lines() do
        vars = splitbywhitespace(line)
        
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

function get_net(info)
    local f = io.open('/proc/net/dev')
    args = {}

    for line in f:lines() do
        line = splitbywhitespace(line)

        local p = line[1]:find(':')
        if p ~= nil then
            name = line[1]:sub(0,p-1)
            line[1] = line[1]:sub(p+1)

            if tonumber(line[1]) == nil then
                line[1] = line[2]
                line[9] = line[10]
            end

            args['{'..name..' rx}'] = bytes_to_string(line[1])
            args['{'..name..' tx}'] = bytes_to_string(line[9])

            args['{'..name..' rx_b}'] = line[1]
            args['{'..name..' tx_b}'] = line[9]
            
            args['{'..name..' rx_kb}'] = line[1]/1024
            args['{'..name..' tx_kb}'] = line[9]/1024

            args['{'..name..' rx_mb}'] = line[1]/1024/1024
            args['{'..name..' tx_mb}'] = line[9]/1024/1024

            args['{'..name..' rx_gb}'] = line[1]/1024/1024/1024
            args['{'..name..' tx_gb}'] = line[9]/1024/1024/1024

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

                args['{'..name..' down}'] = bytes_to_string(down)
                args['{'..name..' up}'] = bytes_to_string(up)

                args['{'..name..' down_b}'] = down
                args['{'..name..' up_b}'] = up

                args['{'..name..' down_kb}'] = down/1024
                args['{'..name..' up_kb}'] = up/1024

                args['{'..name..' down_mb}'] = down/1024/1024
                args['{'..name..' up_mb}'] = up/1024/1024

                args['{'..name..' down_gb}'] = down/1024/1024/1024
                args['{'..name..' up_gb}'] = up/1024/1024/1024
            end

            nets[name][1] = line[1]
            nets[name][2] = line[9]
        end
    end

    f:close()
    return args
end

function bytes_to_string(bytes, sec)
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

-- Build function list
P.register = register
return P
