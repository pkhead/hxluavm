---@class Stream
---@field popchar fun(self:Stream):integer Pops one character, returning its code.
---@field readchar fun(self:Stream):integer Peeks one character, returning its code.
---@field read fun(self:Stream, count:integer):string Read contents without moving the cursor.
---@field pop fun(self:Stream, count:integer):string Read contents and advance the cursor.
---@field eof fun(self:Stream):boolean
---@field skip fun(self:Stream, count:integer) Advance the cursor without reading contents.

---@class StringStream: Stream
---@field _str string
---@field _idx integer
local StringStream = {}
StringStream.__index = StringStream

function StringStream.new(str)
    local self = setmetatable({}, StringStream)
    self._str = str
    self._idx = 1

    return self
end

function StringStream:eof()
    return self._idx > string.len(self._str)
end

function StringStream:popchar()
    assert(not self:eof(), "eof!")
    local ch = string.byte(self._str, self._idx)
    self._idx = self._idx + 1
    return ch
end

function StringStream:readchar()
    assert(not self:eof(), "eof!")
    local ch = string.byte(self._str, self._idx)
    return ch
end

---@param count integer
function StringStream:pop(count)
    assert(not self:eof(), "eof!")
    local ret = string.sub(self._str, self._idx, self._idx + count - 1)
    self._idx = self._idx + string.len(ret)
    return ret
end

---@param count integer
function StringStream:read(count)
    assert(not self:eof(), "eof!")
    return string.sub(self._str, self._idx, self._idx + count - 1)
end

function StringStream:skip(count)
    assert(not self:eof(), "eof!")
    self._idx = self._idx + count
end

return StringStream