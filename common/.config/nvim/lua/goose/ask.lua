-- Ask an LLM about the current buffer (normal mode) or the visual selection.
--
-- <A-q> opens a one-line prompt float. <CR> sends the question and opens a
-- markdown response float; a spinner runs in its title while the backend
-- streams tokens into it. The text being asked about is sent as a fenced
-- ```<filetype> block, the same shape <C-y> yanks.
--
-- Backends (M.config.backend, or :AskBackend <name> at runtime):
--   claude  `claude -p` in --safe-mode (no hooks, CLAUDE.md, MCP; OAuth still
--           works, unlike --bare) with stream-json output. Only text deltas
--           are shown; thinking blocks are dropped.
--   vlm     ~/.local/bin/vlm, the private llama.cpp client. Streams raw text.
--           The server has a 4096-token context; vlm refuses over-budget
--           prompts before generating and the refusal lands in the window.
--
-- Response window keys: q / <Esc> close (kills a running job), <C-c> cancel
-- but keep the text, <C-y> yanks the answer as a markdown block (remap.lua).

local M = {}

M.config = {
  backend = 'claude',
  system_prompt = table.concat({
    'You are a terse assistant embedded in a text editor.',
    'The user shows you a piece of text and asks a question about it.',
    'Answer the question briefly in plain markdown, leading with the answer.',
    'Do not restate the text or the question. Use a fenced code block only when quoting code.',
  }, ' '),
  claude = { model = 'sonnet', effort = 'low' },
  vlm = { max_tokens = 512 },
  -- Response float size as a fraction of the editor.
  width = 0.62,
  height = 0.55,
}

local SPINNER = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

-- ---------------------------------------------------------------------------
-- Backends: { cmd = {...}, parse = function(chunk) -> text | nil }
-- parse receives raw stdout chunks and returns the text to show, if any.
-- ---------------------------------------------------------------------------

-- Adapts a per-line function to raw chunks, which may split lines anywhere.
local function each_line(extract)
  local pending = ''
  return function(chunk)
    pending = pending .. chunk
    local out = {}
    for line in pending:gmatch('(.-)\n') do
      out[#out + 1] = extract(line)
    end
    pending = pending:match('[^\n]*$')
    if #out == 0 then return nil end
    return table.concat(out)
  end
end

local backends = {}

function backends.vlm(system_prompt)
  return {
    cmd = {
      'vlm', '--no-stats',
      '--max-tokens', tostring(M.config.vlm.max_tokens),
      '--system', system_prompt,
    },
    parse = function(chunk) return chunk end,
  }
end

function backends.claude(system_prompt)
  return {
    cmd = {
      'claude', '-p', '--safe-mode',
      '--output-format', 'stream-json', '--include-partial-messages', '--verbose',
      '--tools', '',
      '--model', M.config.claude.model,
      '--effort', M.config.claude.effort,
      '--system-prompt', system_prompt,
    },
    parse = each_line(function(line)
      local ok, ev = pcall(vim.json.decode, line)
      if not ok or type(ev) ~= 'table' then return '' end
      if ev.type == 'result' and ev.is_error then
        return '\n\n**error:** ' .. tostring(ev.result or ev.subtype)
      end
      local delta = ev.type == 'stream_event' and ev.event and ev.event.delta
      if delta and delta.type == 'text_delta' then return delta.text end
      return ''
    end),
  }
end

-- ---------------------------------------------------------------------------
-- Prompt text
-- ---------------------------------------------------------------------------

local function user_prompt(subject, question)
  local what = subject.scope == 'selection' and 'Selected text from ' or 'Whole buffer '
  return table.concat({
    what .. subject.name .. ':',
    '',
    '```' .. subject.filetype,
    table.concat(subject.lines, '\n'),
    '```',
    '',
    'Question: ' .. question,
  }, '\n')
end

-- ---------------------------------------------------------------------------
-- Floating windows
-- ---------------------------------------------------------------------------

-- Opens a centered, bordered scratch float and returns buf, win.
-- opts: width, height (cells), row (optional), title, footer
local function open_float(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  local rows = vim.o.lines - vim.o.cmdheight
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = opts.width,
    height = opts.height,
    col = math.floor((vim.o.columns - opts.width) / 2),
    row = opts.row or math.floor((rows - opts.height) / 2) - 1,
    style = 'minimal',
    border = 'rounded',
    title = opts.title, title_pos = 'left',
    footer = opts.footer, footer_pos = 'right',
  })
  -- One cell of left padding, the same trick as float_padding.lua.
  local wo = vim.wo[win]
  wo.numberwidth = 1
  wo.statuscolumn = ' '
  wo.winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle'
  return buf, win
end

local function set_title(win, title, footer)
  if not vim.api.nvim_win_is_valid(win) then return end
  vim.api.nvim_win_set_config(win, { title = title, title_pos = 'left', footer = footer, footer_pos = 'right' })
end

-- ---------------------------------------------------------------------------
-- Response session: one in-flight question at a time
-- ---------------------------------------------------------------------------

local current = nil

-- Stops the spinner and the job. Idempotent; the window is left alone.
local function stop(session)
  if session.stopped then return end
  session.stopped = true
  session.timer:stop()
  session.timer:close()
  if not session.exited then session.job:kill(15) end
end

-- Appends streamed text at the end of the buffer. The first chunk replaces
-- the "thinking…" placeholder line.
local function append(session, text)
  local buf, win = session.buf, session.win
  local last = vim.api.nvim_buf_line_count(buf) - 1
  local at_bottom = vim.api.nvim_win_get_cursor(win)[1] - 1 == last
  local lines = vim.split(text, '\n', { plain = true })

  vim.bo[buf].modifiable = true
  if not session.received then
    session.received = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    local col = #vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1]
    vim.api.nvim_buf_set_text(buf, last, col, last, col, lines)
  end
  vim.bo[buf].modifiable = false

  -- Follow the stream unless the user has scrolled up to read.
  if at_bottom then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

local function on_exit(session, code, stderr)
  session.exited = true
  stop(session)
  if not vim.api.nvim_win_is_valid(session.win) then return end
  if code == 0 then
    set_title(session.win, ' ✓ ' .. session.label .. ' ', ' q close ')
    return
  end
  local msg = vim.trim(stderr)
  if msg ~= '' then
    local sep = session.received and '\n\n' or ''
    append(session, sep .. '**' .. session.label .. ' failed (exit ' .. code .. '):**\n```\n' .. msg .. '\n```')
  end
  set_title(session.win, ' ✗ ' .. session.label .. ' (exit ' .. code .. ') ', ' q close ')
end

local function run(subject, question, backend_name)
  if vim.fn.executable(backend_name) ~= 1 then
    vim.notify('goose.ask: `' .. backend_name .. '` is not on PATH', vim.log.levels.ERROR)
    return
  end
  if current and vim.api.nvim_win_is_valid(current.win) then
    vim.api.nvim_win_close(current.win, true)
  end

  local rows = vim.o.lines - vim.o.cmdheight
  local buf, win = open_float({
    width = math.max(40, math.floor(vim.o.columns * M.config.width)),
    height = math.max(3, math.floor(rows * M.config.height)),
    title = ' ' .. SPINNER[1] .. ' ' .. backend_name .. ' ',
    footer = ' <C-c> cancel · q close ',
  })
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false
  local wo = vim.wo[win]
  wo.wrap, wo.linebreak, wo.breakindent, wo.conceallevel = true, true, true, 2

  local session = { buf = buf, win = win, label = backend_name, timer = vim.uv.new_timer() }
  current = session

  local backend = backends[backend_name](M.config.system_prompt)
  local stderr = {}
  session.job = vim.system(backend.cmd, {
    stdin = user_prompt(subject, question),
    text = true,
    stdout = function(_, chunk)
      local text = chunk and backend.parse(chunk)
      if not text or text == '' then return end
      vim.schedule(function()
        if not session.stopped then append(session, text) end
      end)
    end,
    stderr = function(_, chunk)
      if chunk then stderr[#stderr + 1] = chunk end
    end,
  }, function(result)
    vim.schedule(function()
      if not session.stopped then on_exit(session, result.code, table.concat(stderr)) end
    end)
  end)

  -- Spinner in the title, plus a placeholder line until the first token.
  local tick = 0
  session.timer:start(0, 80, vim.schedule_wrap(function()
    if session.stopped then return end
    tick = tick % #SPINNER + 1
    set_title(win, ' ' .. SPINNER[tick] .. ' ' .. backend_name .. ' ', ' <C-c> cancel · q close ')
    if not session.received then
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { SPINNER[tick] .. ' thinking…' })
      vim.bo[buf].modifiable = false
    end
  end))

  local function map(lhs, rhs)
    vim.keymap.set('n', lhs, rhs, { buffer = buf, nowait = true, silent = true })
  end
  map('q', function() vim.api.nvim_win_close(win, true) end)
  map('<Esc>', function() vim.api.nvim_win_close(win, true) end)
  map('<C-c>', function()
    if session.exited then return end
    stop(session)
    set_title(win, ' ■ ' .. backend_name .. ' (cancelled) ', ' q close ')
  end)
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function() stop(session) end,
  })
  return session
end

-- ---------------------------------------------------------------------------
-- Prompt float
-- ---------------------------------------------------------------------------

local function open_prompt(subject, backend_name)
  local n = #subject.lines
  local scope = subject.scope == 'selection'
    and (n .. ' selected line' .. (n == 1 and '' or 's'))
    or ('whole buffer, ' .. n .. ' lines')
  local buf, win = open_float({
    width = math.max(50, math.floor(vim.o.columns * 0.5)),
    height = 1,
    row = math.floor((vim.o.lines - vim.o.cmdheight) / 3),
    title = ' Ask ' .. backend_name .. ' ',
    footer = ' ' .. scope .. ' · <CR> send · <Esc> cancel ',
  })
  vim.b[buf].completion = false -- blink.cmp off in the prompt

  local function close()
    vim.cmd.stopinsert() -- so the next window is entered in normal mode
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  local function submit()
    local question = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
    close()
    if question == '' then return end
    vim.schedule(function() run(subject, question, backend_name) end)
  end

  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set({ 'i', 'n' }, '<CR>', submit, opts)
  vim.keymap.set('i', '<C-c>', close, opts)
  vim.keymap.set('n', '<Esc>', close, opts)
  vim.keymap.set('n', 'q', close, opts)
  vim.api.nvim_create_autocmd('WinLeave', { buffer = buf, once = true, callback = close })
  vim.cmd.startinsert()
end

-- ---------------------------------------------------------------------------
-- Public API and mappings
-- ---------------------------------------------------------------------------

local function subject(scope, lines)
  local name = vim.api.nvim_buf_get_name(0)
  return {
    scope = scope,
    name = name == '' and '[No Name]' or vim.fn.fnamemodify(name, ':~:.'),
    filetype = vim.bo.filetype,
    lines = lines,
  }
end

function M.ask()
  open_prompt(subject('buffer', vim.api.nvim_buf_get_lines(0, 0, -1, false)), M.config.backend)
end

function M.ask_selection()
  local lines = vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = vim.fn.mode() })
  local s = subject('selection', lines)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
  vim.schedule(function() open_prompt(s, M.config.backend) end)
end

function M.set_backend(name)
  if not backends[name] then
    vim.notify('goose.ask: unknown backend ' .. tostring(name), vim.log.levels.ERROR)
    return
  end
  M.config.backend = name
  vim.notify('goose.ask backend: ' .. name)
end

M.backends = backends
M._run = run -- exposed for headless tests

vim.api.nvim_create_user_command('AskBackend', function(cmd) M.set_backend(cmd.args) end, {
  nargs = 1,
  complete = function() return vim.tbl_keys(backends) end,
})

-- The writing view (<A-w> in markdown.lua) used <A-q> to tear itself down.
-- It sets laststatus=0, which nothing else does, so keep that behaviour only
-- while the writing view is up and give <A-q> to the ask prompt otherwise.
vim.keymap.set('n', '<A-q>', function()
  if vim.o.laststatus == 0 then
    vim.cmd('wincmd w | q | wincmd w | q')
    return
  end
  M.ask()
end, { desc = 'Ask an LLM about the buffer (or close the writing view)' })

vim.keymap.set('x', '<A-q>', M.ask_selection, { desc = 'Ask an LLM about the selection' })

return M
