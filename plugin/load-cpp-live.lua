local function add(n, f) vim.api.nvim_create_user_command("CppLive" .. n, f, {}) end

add("Start",  function() require("cpp-live").start()  end)
add("Stop",   function() require("cpp-live").stop()   end)
