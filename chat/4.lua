local levee = require("levee")
local p = levee.p

local h = levee.Hub()

local err, serve = h.stream:listen(9000, "0.0.0.0")


local conns = {}


local function message(who, to_me, to_others)
    for other_conn, other_name in pairs(conns) do
        if other_name then
            if who == other_name then
                other_conn:send(to_me .. "\r\n")
            else
                other_conn:send(to_others .. "\r\n")
            end
        end
    end
end


for conn in serve do
    conns[conn] = false

    h:spawn(function()
        local stream = conn:stream()
        conn:send("Hi, who are you? ")

        local err, name = p.line.stream(stream, "\r\n")
        if err then goto __close end
        conns[conn] = name
        message(name, ("Welcome %s!"):format(name), ("%s has joined."):format(name))

        while true do
            local err, line = p.line.stream(stream, "\r\n")
            message(name, ("you said: %s"):format(line), ("%s said: %s"):format(name, line))
            if err then goto __close end
        end

        ::__close::
        print("done")
        conn:close()
        conns[conn] = nil
    end)
end
