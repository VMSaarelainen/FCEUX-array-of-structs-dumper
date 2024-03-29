--[[
Simple FCEUX-compatible Lua script to read out memory values from a one- or two-dimensional array of C structs. Tested on DeSmuMe 0.9.13.
For example, a game might have an array like enemyData[200] or tilegrid[32][64] that you want to read out while execution is paused. This 
script calculates the memory offsets of each field and reads out the corresponding bytes according to the provided definitions.
]]--

--[[ CONFIG ]]--

local endianness = 1    --Set to 0 for big endian, 1 for little endian. 
local is_2D = true           --switch between 1D and 2D modes
local write_to_file = false
local output_path = "arr_struct_reader_out.txt"
local index_style = 1     --Set to 0 for Lua-style or 1 for C-style indexing in the output. For example struct_1 vs struct_0 for the first struct. Only affects the output, not the internal logic.

-- parameters for the for-loop reading the bytes
local config1D = {
    array_start = 0x027E02B0,
    i_start = 1,
    i_end = 256
}

-- same for 2D mode
local config2D = {
    array_start = 0x027E0454,
    inner_array_length = 15,    --this specifies the length of the inner array. For example, tilegrid[32][64] corresponds to inner_array_length = 64. 
    x_start = 1,    --these specify the ranges of indices (inclusive) to read out. The y-values are applied to each iteration.
    y_start = 1,
    x_end = 4,
    y_end = 3,
}

-- Lua 5.1 didn't include a pack function yet
local function pack(...)
    return {n = select("#", ...), ...}
end

--[[
The actual struct definition goes here.
        Field format: pack("variable_name", size_in_bytes)
        Any fields named "skip" will skip the corresponding number of bytes when reading out the struct
        Note: the first entry "dummy" ensures Lua keeps the order of the table. Don't change it.
]]--
local struct = {
    [0] = pack("dummy", 0),
    pack("x_start", 2),
    pack("y_start", 2),
    pack("skip", 4),
    pack("is_invalid", 1),
    pack("skip", 10),
    pack("is_connect_to_top", 1),
    pack("is_connect_to_bottom", 1),
    pack("is_connect_to_left", 1),
    pack("is_connect_to_right", 1),
    pack("should_connect_to_top", 1),
    pack("should_connect_to_bottom", 1),
    pack("should_connect_to_left", 1),
    pack("should_connect_to_right", 1),
    pack("skip", 3)
}

--[[ CODE ]]--

local currAddress = array_start
local output = {
    [0] = ""
}

local structSize = 0
for _, v in ipairs(struct) do
    local _, size = unpack(v)
    structSize = structSize + size
end
print("Detected struct of size: " .. structSize .. " bytes")

local function read_memory_bytes(currAddress, name, size)
    ret = ""
    if name == "skip" then
        currAddress = currAddress + size --skip t bytes forward
    else
        local byte_string = ""
        if endianness == 0 then --big endian
            for addr = currAddress, currAddress + size -1 do
                byte_string = string.format("%0" .. size*2 .. "x", memory.readbyte(addr))
            end
        else    --little endian
            for addr = currAddress + size, currAddress, -1 do
                byte_string = string.format("%0" .. size*2 .. "x", memory.readbyte(addr))
            end
        end
        currAddress = currAddress + size
        ret = "  " .. name .. ": " .. byte_string
    end
    return currAddress, ret
end

--1D mode
if not is_2D then
    local currAddress = config1D["array_start"]
    for i = config1D["i_start"], config1D["i_end"] do
        output[#output +1] = "struct_" .. i-index_style .. " @ " .. string.format("%08x", currAddress)
        for _, v in ipairs(struct) do
            currAddress, str = read_memory_bytes(currAddress, unpack(v))
            output[#output +1] = str
        end
    end
--2D mode
else
    local currAddress = config2D["array_start"]
    local num_to_skip = config2D["inner_array_length"] - config2D["y_end"]

    for x = config2D["x_start"], config2D["x_end"] do
        for y = config2D["y_start"], config2D["y_end"] do
            output[#output +1] = "struct_" .. x-index_style .. "_" .. y-index_style .. " @ " .. string.format("%08x", currAddress)
            for _, v in ipairs(struct) do
                currAddress, str = read_memory_bytes(currAddress, unpack(v))
                output[#output +1] = str
            end
        end
        currAddress = currAddress + (structSize * num_to_skip)
    end
end

print("Finished dumping memory\n=======")

--output
if write_to_file then
    f = assert(io.open(output_path, "w"))
    for _, line in ipairs(output) do
        if line ~= "" then
            f:write(s .. "\n")
        end
    end
    f:flush()
    f:close()
    print("Wrote to file: " .. output_path)
else
    for _, line in ipairs(output) do
        if line ~= "" then
            print(line)
        end
    end
    print("=======")
end
