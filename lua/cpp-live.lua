local M = {}

local config = nil

local defaults = {
    debounce = 0,

    filetypes = {"cpp"},

    output = {
        max_lines = 1000,
        window_config = { split = "right", width = 42, win = 0 },

        open = function(config) end,
        close = function(output) end,

        append = function(output, data, config) end,
        clear = function(output) end
    },

    process = {
        jobify = true,

        kill = function(process) process:kill(9) end,
        done = function(obj, exe, file) --[[ if arg.code == 0 then deploy(exe, to_prod) end ]] end
    },

    enable = function() return true end
}

defaults.output.open = function(config)
    local buffer = vim.api.nvim_create_buf(true, true);
    local window = vim.api.nvim_open_win(buffer, false, config.output.window_config)
    return { buffer = buffer, window = window }
end

defaults.output.close = function(output)
    vim.api.nvim_win_close(output.window, true)
end

defaults.output.append = function(output, data, config)
    local buffer = output.buffer
    vim.schedule(function()
        if vim.api.nvim_buf_line_count(buffer) < config.output.max_lines then
            local last_line = vim.api.nvim_buf_get_lines(buffer, -2, -1, false)[1]
            local lines = vim.split(data:gsub('\r\n', '\n'), "\n")
            lines[1] = last_line .. lines[1]
            vim.api.nvim_buf_set_lines(buffer, -2, -1, false, lines)
        end
    end)
end

defaults.output.clear = function(output)
    vim.schedule(function() 
        vim.api.nvim_buf_set_lines(output.buffer, 0, -1, false, {}) 
    end)
end

local function error_on_error(...)
    local ok, second = ...
    if ok then
        return select(2, ...)
    else
        error(second)
    end
end

local function coroutine_resume(...)
    return error_on_error(coroutine.resume(...))
end

local function send_abort(c)
    local ignore = coroutine.resume(c, "abort")
end

local function wait_if(f, ...)
    while true do
        local p = { coroutine.yield(...) }
        local m = unpack(p)
        if m == "abort" then error(m) end
        if f(unpack(p)) then
            return unpack(p)
        end
    end
end

local function wait_any(...)
    return wait_if(function(...) return true end, ...)
end

local function wait_event(a, ...)
    return select(2, wait_if(function(m, ...) return m == a end, ...))
end

local function wait_any_timeout(timeout, ...)
    local me = coroutine.running()

    local timer = vim.defer_fn(function()
        coroutine_resume(me, "timeout")
    end, timeout)

    local result = { wait_any(...) }

    if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
    end

    return unpack(result)
end

local function wait_text_changed()
    return wait_event("text_changed")
end

local function send_text_changed(c, args)
    coroutine_resume(c, "text_changed", args.buf, args.file)
end

local function wait_first_keystroke()
    return wait_text_changed()
end

local function wait_last_keystroke(timeout)
    while true do
        if wait_any_timeout(timeout) == "timeout" then return end
    end
end

local function save_all_buffers()
    vim.cmd("silent! wa")
end

local function get_jobify_ps1(root)
    return vim.fs.joinpath(root, "script", "jobify.ps1")
end

local is_windows = jit.os:find("Windows")
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

local function get_command(jobify, exe, file)
    if type(jobify) == 'boolean' then
        return (is_windows and jobify) and 
                    {
                        "PowerShell.exe", 
                        "-ExecutionPolicy", "Bypass", 
                        "-File", get_jobify_ps1(root), 
                        exe, file
                    } or {
                        exe, file
                    }
    elseif type(jobify) == 'table' then
        local result = { exe, file }
        for i = 1, #jobify do
            table.insert(result, i, jobify[i])
        end
        return result
    elseif type(jobify) == 'function' then
        return jobify(exe, file)
    end
    error("Invalid jobify type")
end

local function start_process(exe, file, output)
    local o = function(err, data) config.output.append(output, (err or "") .. (data or ""), config) end
    local done = function(obj) config.process.done(obj, exe, file) end
    return vim.system(get_command(config.process.jobify, exe, file), {
        stdout = o,
        stderr = o,
        text = true
    }, done)
end

local function has_file(d, n)
    return vim.fn.filereadable(vim.fs.joinpath(d, n)) == 1
end

local function find_in_parents(p, n)
    return vim.iter(vim.fs.parents(p)):find(function(d) return has_file(d, n) end) -- Parlez-vous français ?
end

local function find_nearest(p, n)
    local d = find_in_parents(p, n)
    return d and vim.fs.joinpath(d, n) or nil
end

local function get_executable_name()
    return "c++live." .. (is_windows and "bat" or "sh")
end

local function find_nearest_executable(a)
    return find_nearest(a, get_executable_name())
end

local function get_buffer_filetype(a)
    return vim.bo[a].filetype
end

local function is_type_supported(buffer)
    return vim.list_contains(config.filetypes, get_buffer_filetype(buffer))
end

local function watch_buffer_changes()

    local output = config.output.open(config)

    local process = nil

    while true do
        local buffer, file = wait_first_keystroke()

        local exe = 
            is_type_supported(buffer) and 
            find_nearest_executable(file) or nil

        if exe then
            if process then
                config.process.kill(process)
                process:wait() -- 🤞
            end


            wait_last_keystroke(config.debounce)


            save_all_buffers()

            config.output.clear(output)

            process = start_process(exe, file, output)
        end
    end

    config.output.close(output)
end

local function merge_config(a, b)
    return vim.tbl_deep_extend("force", a or {}, b or {})
end

function M.setup(cfg)
    config = merge_config(defaults, cfg)
end

local function need_setup()
    if config then
    else
        M.setup()
    end
end

local function is_running(c)
    return c and coroutine.status(c) ~= "dead"
end

local main_coroutine = nil

local function is_main_coroutine_running()
    return is_running(main_coroutine)
end

function M.start()
    if is_main_coroutine_running() then
        return
    end

    need_setup()

    main_coroutine = coroutine.create(watch_buffer_changes)
    coroutine_resume(main_coroutine)

    local group = vim.api.nvim_create_augroup("cpp-live-ag", {
        clear = true
    })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = "cpp-live-ag",
        callback = function(args)
            if is_main_coroutine_running() then
                if config.enable() then
                    send_text_changed(main_coroutine, args)
                end
            else
                vim.api.nvim_del_augroup_by_id(group)
            end
        end
    })
end

function M.stop()
    if is_main_coroutine_running() then
        send_abort(main_coroutine)
    end
end

return M
