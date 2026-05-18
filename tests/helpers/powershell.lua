local M = {}

local function shell_quote(value)
    return tostring(value):gsub("'", "''")
end

local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

function M.path_separator()
    return package.config:sub(1, 1)
end

function M.executable()
    local override = os.getenv("GBANKMANAGER_TEST_POWERSHELL")
    if type(override) == "string" and override ~= "" then
        return override
    end

    if is_windows() then
        return "powershell"
    end

    return "pwsh"
end

function M.shell_quote(value)
    return shell_quote(value)
end

function M.argument(value)
    return string.format('"%s"', tostring(value):gsub('"', '\\"'))
end

function M.command_argument(value)
    if is_windows() then
        return M.argument(value)
    end

    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function M.single_quote(value)
    return "'" .. shell_quote(value) .. "'"
end

function M.normalize_host_path(value)
    local normalized = tostring(value or "")
    return (normalized:gsub("[/\\]", M.path_separator()))
end

function M.absolute_path(path)
    local handle = io.popen(string.format("%s -NoProfile -Command \"[System.IO.Path]::GetFullPath('%s')\"", M.executable(), shell_quote(path)))
    return handle
end

function M.ensure_directory(path)
    return os.execute(string.format("%s -NoProfile -ExecutionPolicy Bypass -Command \"New-Item -ItemType Directory -Force -Path '%s' | Out-Null\"", M.executable(), shell_quote(path)))
end

function M.remove_path_if_exists(path)
    return os.execute(string.format("%s -NoProfile -ExecutionPolicy Bypass -Command \"if (Test-Path -LiteralPath '%s') { Remove-Item -LiteralPath '%s' -Force }\"", M.executable(), shell_quote(path), shell_quote(path)))
end

function M.json_query_command(path, expression)
    local commandText = string.format(
        "$data = Get-Content -LiteralPath '%s' -Raw | ConvertFrom-Json; $value = %s; if ($value -is [DateTimeOffset]) { [Console]::Out.Write($value.ToUniversalTime().ToString(\"yyyy-MM-ddTHH:mm:ss.fff''Z''\")) } elseif ($value -is [DateTime]) { [Console]::Out.Write(([DateTimeOffset]$value).ToUniversalTime().ToString(\"yyyy-MM-ddTHH:mm:ss.fff''Z''\")) } elseif ($null -ne $value) { [Console]::Out.Write($value) }",
        shell_quote(path),
        expression
    )

    return string.format(
        "%s -NoProfile -ExecutionPolicy Bypass -Command %s",
        M.executable(),
        M.command_argument(commandText)
    )
end

return M
