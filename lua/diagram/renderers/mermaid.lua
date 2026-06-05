---@class MermaidOptions
---@field theme? string              -- 主题: default, dark, forest, neutral (通过 configFile 实现)
---@field scale? number              -- 【已废弃】mmdr 不支持 scale，请使用 width/height
---@field width? number              -- 图片宽度，默认 1200
---@field height? number             -- 图片高度，默认 800
---@field outputFormat? string       -- 输出格式: svg 或 png，默认 svg
---@field configFile? string         -- Mermaid 配置 JSON 文件路径
---@field backgroundColor? string    -- 背景色，需写入 configFile
---@field nodeSpacing? number        -- 节点间距
---@field rankSpacing? number        -- 层级间距
---@field cli_args? string[]         -- 额外的 CLI 参数

---@type table<string, string>

---@class Renderer<MermaidOptions>
local M = {
  id = "mermaid",
}

-- fs cache - 使用 svg 后缀
local cache_dir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/diagram-cache/mermaid")
vim.fn.mkdir(cache_dir, "p")

---@param source string
---@param options MermaidOptions
---@return table|nil
M.render = function(source, options)
  -- 默认输出格式为 svg
  local output_format = (options.outputFormat or "svg"):lower()
  if output_format ~= "svg" and output_format ~= "png" then
    output_format = "svg"
  end

  local hash = vim.fn.sha256(M.id .. ":" .. source .. ":" .. output_format)
  local path = vim.fn.resolve(cache_dir .. "/" .. hash .. "." .. output_format)

  if vim.fn.filereadable(path) == 1 then return { file_path = path } end

  if not vim.fn.executable("mmdr") then
    vim.notify("mmdr not found in PATH. Please install mmdr (cargo install mmdr) to use mermaid diagrams.", vim.log.levels.ERROR, { title = "Diagram.nvim" })
    return nil
  end

  local tmpsource = vim.fn.tempname()
  vim.fn.writefile(vim.split(source, "\n"), tmpsource)

  local command_parts = { "mmdr" }

  -- 添加自定义 CLI 参数
  if options.cli_args and #options.cli_args > 0 then
    vim.list_extend(command_parts, options.cli_args)
  end

  -- 基础参数：输入、输出、输出格式
  vim.list_extend(command_parts, {
    "-i", tmpsource,
    "-o", path,
    "-e", output_format,
  })

  -- 配置文件（用于主题、背景色等高级配置）
  if options.configFile then
    vim.list_extend(command_parts, { "-c", options.configFile })
  end

  -- 尺寸参数
  if options.width then
    vim.list_extend(command_parts, { "-w", tostring(options.width) })
  end
  if options.height then
    vim.list_extend(command_parts, { "-H", tostring(options.height) })
  end

  -- 间距参数
  if options.nodeSpacing then
    vim.list_extend(command_parts, { "--nodeSpacing", tostring(options.nodeSpacing) })
  end
  if options.rankSpacing then
    vim.list_extend(command_parts, { "--rankSpacing", tostring(options.rankSpacing) })
  end

  -- scale 已废弃，给出警告
  if options.scale then
    vim.notify("Mermaid: 'scale' option is not supported by mmdr. Use width/height instead.", vim.log.levels.WARN, { title = "Diagram.nvim" })
  end

  -- theme 和 background 已废弃
  if options.theme or options.backgroundColor then
    vim.notify(
      "Mermaid: 'theme' and 'background' options are not directly supported by mmdr.\n"
      .. "Please use a config JSON file with -c option.\n"
      .. "Example config: { \"theme\": \"dark\", \"themeVariables\": { \"background\": \"#1e1e2e\" } }",
      vim.log.levels.WARN,
      { title = "Diagram.nvim" }
    )
  end

  local command = table.concat(command_parts, " ")

  local job_id = vim.fn.jobstart(command, {
    on_stdout = function(job_id, data, event) end,
    on_stderr = function(job_id, data, event)
      local error_msg = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if error_msg ~= "" then
        vim.notify("Failed to render mermaid diagram:\n" .. error_msg, vim.log.levels.ERROR, { title = "Diagram.nvim" })
      end
    end,
    on_exit = function(job_id, exit_code, event)
      -- 可选：处理退出
    end,
  })

  return { file_path = path, job_id = job_id }
end

return M
