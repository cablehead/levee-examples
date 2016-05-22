local levee = require("levee")
local p = levee.p

local h = levee.Hub()

local err, serve = h.stream:listen(9000, "0.0.0.0")

local users = {}


local function message(who, to_me, to_others)
    for name, other in pairs(users) do
        if other == who then
            other:send(to_me .. "\r\n")
        else
            other:send(to_others .. "\r\n")
        end
    end
end


local User_mt = {}
User_mt.__index = User_mt


function User_mt:send(s)
    self.sender:send(s)
end


function User_mt:connect(conn)
    assert(not self.conn)
    self.conn = conn
    self.h:spawn(function()
        for message in self.recver do
            if not self.conn then break end
            local err = self.conn:send(message)
            if err then return end
        end
        self.conn = nil
    end)
end


local function User(h, name)
    local self = setmetatable({h=h, name=name}, User_mt)
    self.sender, self.recver = h:queue()
    return self
end


local function connection(h, conn)
    local stream = conn:stream()
    conn:send("Hi, who are you? ")
    local err, name = p.line.stream(stream, "\r\n")
    if err then return err end

    if not users[name] then users[name] = User(h, name) end
    local user = users[name]
    user:connect(conn)

    message(user, ("Welcome %s!"):format(name), ("%s has joined."):format(name))

    while true do
        local err, line = p.line.stream(stream, "\r\n")
        message(user, ("you said: %s"):format(line), ("%s said: %s"):format(name, line))
        if err then
            user.conn = nil
            return err
        end
    end
end

for conn in serve do
    h:spawn(function()
        connection(h, conn)
        conn:close()
    end)
end
