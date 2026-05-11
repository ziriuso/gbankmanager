local M = {}

function M.equal(expected, actual, message)
    if expected ~= actual then
        error((message or "values differ") .. string.format(" | expected=%s actual=%s", tostring(expected), tostring(actual)))
    end
end

function M.truthy(value, message)
    if not value then
        error(message or "expected truthy value")
    end
end

return M
