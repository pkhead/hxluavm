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
-- arr[1] = "Hi"
-- print(arr[1])
-- arr[2] = "foo"
-- arr[3] = "bar"
-- -- print(arr[4])
-- print(#arr)