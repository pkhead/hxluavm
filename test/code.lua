-- local inst = TestClass.new(3, "hi")
-- print(inst.b)
local function print_array_field(inst)
    for i=1, inst.array_field.length do
        print(i, inst.array_field:get(i))
    end
end

local arr = FloatArray.new()

local inst = TestClass.new(10, "foobar", arr)
print("TestClass.new")
print("int_field", inst.int_field)
print("string_field", inst.string_field)
print("array_field")
print_array_field(inst)

arr:push(1.2)
arr:push(1.4)
inst.int_field = 8
inst.string_field = "hello, world"

print("after modify")
print("int_field", inst.int_field)
print("string_field", inst.string_field)

print("array_field")
print_array_field(inst)