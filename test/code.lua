-- local v = StringArray.new()
-- v:push("Hi")
-- v:push("Hi")
-- print(v:getLengthTimesThisNumber(40))
local arr = StringArray.new()
table.insert(arr, "a")
table.insert(arr, "b")
table.insert(arr, "c")
arr:push("d")

for i=1, #arr do
    print(i, arr[i])
end

local class = TestClass.new(arr)
print(#class.array)
class.array = nil