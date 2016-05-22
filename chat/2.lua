local levee = require("levee")
local p = levee.p

local h = levee.Hub()

local err, serve = h.stream:listen(9000)

for conn in serve do
    h:spawn(function()
        local stream = conn:stream()
        while true do
            local err, line = p.line.stream(stream, "\r\n")
            if err then break end
            conn:send(line.."\r\n")
        end
        conn:close()
    end)
end
