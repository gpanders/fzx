local uv = vim.loop
local api = vim.api
local fzx = require('fzx')
local f = fzx.new()

vim.cmd('enew')
local buf = api.nvim_get_current_buf()
vim.bo.buftype = 'nofile'
vim.bo.undolevels = -1
vim.bo.undofile = false
vim.bo.swapfile = false
vim.opt_local.number = false
vim.opt_local.relativenumber = false

vim.cmd('new')
vim.cmd('resize 1')
local prompt = api.nvim_get_current_buf()
vim.bo.buftype = 'nofile'
vim.bo.undolevels = -1
vim.bo.undofile = false
vim.bo.swapfile = false
vim.opt_local.number = false
vim.opt_local.relativenumber = false

local pending = false
local poll = assert(uv.new_poll(f:fd()))
poll:start('r', function(err)
  assert(not err, err)
  if not f:load() or pending then
    return
  end
  pending = true
  vim.schedule(function()
    -- TODO: use window size
    api.nvim_buf_set_lines(buf, 0, -1, false, f:results(60))
    pending = false
  end)
end)

f:start()
local lines = vim.fn.readfile(vim.env.HOME .. '/repos/neovim/src/nvim/main.c')
if false then
  coroutine.resume(coroutine.create(function()
    local co = coroutine.running()
    for _, line in ipairs(lines) do
      f:push(line)
      f:commit()
      vim.defer_fn(function()
        coroutine.resume(co)
      end, 100)
      coroutine.yield()
    end
  end))
else
  f:push(lines)
  f:commit()
end

api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
  buffer = prompt,
  callback = function()
    local line = api.nvim_buf_get_lines(prompt, 0, 1, false)[1]
    f:query(line)
  end,
})
vim.cmd('startinsert')
