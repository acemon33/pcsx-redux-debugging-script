local bit = require("bit")

local debugger = {}
local breakpoint_list = {}
local counter = 0

local storeOpcodes = {
    [0x28] = 'STORE', -- sb
    [0x29] = 'STORE', -- sh
    [0x2a] = 'STORE', -- swl
    [0x2b] = 'STORE', -- sw
    [0x2e] = 'STORE', -- swr
    [0x3a] = 'STORE', -- swc2
}
local loadOpcodes = {
    [0x20] = 'LOAD', -- lb
    [0x24] = 'LOAD', -- lbu
    [0x21] = 'LOAD', -- lh
    [0x25] = 'LOAD', -- lhu
    [0x23] = 'LOAD', -- lw
    [0x22] = 'LOAD', -- lwl
    [0x26] = 'LOAD', -- lwr
}

local color = {
  blue = 0xffD94545,
  green = 0xff00A64B,
  orange = 0xff02ABE2,
  red = 0xff6666ff,
  pink = 0xffF066FF,
}

function debugger:breakpoint(address, name, type_, bytes)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = PCSX.addBreakpoint(address, type_, bytes, name, function(address, w, c) PCSX.pauseEmulator() end)
  counter = counter + 1
end

local function isStore(code)
  local opcode = bit.rshift(code, 26)
  local t = storeOpcodes[opcode]
  if t == nil then
      return false, nil
  end
  local offsett = bit.band(code, 0xffff)
  return true, offsett
end
local function isLoad(code)
  local opcode = bit.rshift(code, 26)
  local t = loadOpcodes[opcode]
  if t == nil then
      return false, nil
  end
  local offsett = bit.band(code, 0xffff)
  return true, offsett
end
local function get_register_value(register)
  if register == 0x01 then return PCSX.getRegisters().GPR.n.at
  elseif register == 0x02 then return PCSX.getRegisters().GPR.n.v0
  elseif register == 0x03 then return PCSX.getRegisters().GPR.n.v1
  elseif register == 0x04 then return PCSX.getRegisters().GPR.n.a0
  elseif register == 0x05 then return PCSX.getRegisters().GPR.n.a1
  elseif register == 0x06 then return PCSX.getRegisters().GPR.n.a2
  elseif register == 0x07 then return PCSX.getRegisters().GPR.n.a3
  elseif register == 0x08 then return PCSX.getRegisters().GPR.n.t0
  elseif register == 0x09 then return PCSX.getRegisters().GPR.n.t1
  elseif register == 0x0a then return PCSX.getRegisters().GPR.n.t2
  elseif register == 0x0b then return PCSX.getRegisters().GPR.n.t3
  elseif register == 0x0c then return PCSX.getRegisters().GPR.n.t4
  elseif register == 0x0d then return PCSX.getRegisters().GPR.n.t5
  elseif register == 0x0e then return PCSX.getRegisters().GPR.n.t6
  elseif register == 0x0f then return PCSX.getRegisters().GPR.n.t7
  elseif register == 0x10 then return PCSX.getRegisters().GPR.n.s0
  elseif register == 0x11 then return PCSX.getRegisters().GPR.n.s1
  elseif register == 0x12 then return PCSX.getRegisters().GPR.n.s2
  elseif register == 0x13 then return PCSX.getRegisters().GPR.n.s3
  elseif register == 0x14 then return PCSX.getRegisters().GPR.n.s4
  elseif register == 0x15 then return PCSX.getRegisters().GPR.n.s5
  elseif register == 0x16 then return PCSX.getRegisters().GPR.n.s6
  elseif register == 0x17 then return PCSX.getRegisters().GPR.n.s7
  elseif register == 0x18 then return PCSX.getRegisters().GPR.n.t8
  elseif register == 0x19 then return PCSX.getRegisters().GPR.n.t9
  elseif register == 0x1c then return PCSX.getRegisters().GPR.n.gp
  elseif register == 0x1d then return PCSX.getRegisters().GPR.n.sp
  elseif register == 0x1f then return PCSX.getRegisters().GPR.n.ra
  end
end
local function get_4_byte_from_memory(address)
  local mem = PCSX.getMemPtr()
  local pointer = mem + address - 0x80000000
  pointer = ffi.cast('uint32_t*', pointer)
  return pointer[0]
end
local function get_2_byte_from_memory(address)
  local mem = PCSX.getMemPtr()
  local pointer = mem + address - 0x80000000
  pointer = ffi.cast('uint16_t*', pointer)
  return pointer[0]
end
local function read_value_from_memory(address, bytes)
  local value = PCSX.getMemPtr()[(address - 0x80000000)]
  if bytes == 2 then value = get_2_byte_from_memory(address)
  elseif bytes == 1 then value = get_4_byte_from_memory(address)
  end
  return value
end
local function is_equality_true(mem_value, value, equality)
  local bool = false
  if equality == 0 then bool = mem_value == value
  elseif equality == 1 then bool = mem_value ~= value
  elseif equality == 2 then bool = mem_value > value
  elseif equality == 3 then bool = mem_value >= value
  elseif equality == 4 then bool = mem_value < value
  elseif equality == 5 then bool = mem_value <= value
  end
  return bool
end

function debugger:breakpoint_on_write_change_fun(address, bytes, label)
  local code = get_4_byte_from_memory(PCSX.getRegisters().pc)
  local isStoreCode, offset = isStore(code)
  if isStoreCode then
    local address = get_register_value(bit.band(bit.rshift(code, 21), 0x1f)) + offset
    local new_value = get_register_value(bit.band(bit.rshift(code, 16), 0x1f))
    local old_value = read_value_from_memory(address, bytes);

    if old_value ~= new_value then
      PCSX.pauseEmulator()
    end
  end
end
function debugger:breakpoint_on_write_change(address, name, bytes)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = PCSX.addBreakpoint(address, 'Write', bytes, name, breakpoint_on_write_change_fun)
  counter = counter + 1
end

function debugger:breakpoint_read_write_equality_fun(exe_address, type_, bytes, name, value, equality)
  return PCSX.addBreakpoint(exe_address, type_, bytes, name, function(address, w, c)
    local code = get_4_byte_from_memory(PCSX.getRegisters().pc)
    local bool, offset = isLoad(code)
    if bool then
      local address = get_register_value(bit.band(bit.rshift(code, 21), 0x1f)) + offset
      local mem_value = read_value_from_memory(address, bytes)

      if is_equality_true(mem_value, value, equality) then
        PCSX.pauseEmulator()
      end
    end
  end)
end
function debugger:breakpoint_read_write_equality(address, type_, bytes, name, value, equality)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = debugger:breakpoint_read_write_equality_fun(address, type_, bytes, name, value, equality)
  counter = counter + 1
end

function debugger:breakpoint_exec_register_equality_fun(exe_address, name, register, equality, value)
  return PCSX.addBreakpoint(exe_address, 'Exec', 4, name, function(address, w, c)
    if is_equality_true(get_register_value(register), value, equality) then
      PCSX.pauseEmulator()
    end
  end)
end
function debugger:breakpoint_exec_register_equality(address, name, register, equality, value)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = debugger:breakpoint_exec_register_equality_fun(address, name, register, equality, value)
  counter = counter + 1
end

function debugger:breakpoint_read_write_pc_equality_fun(exe_address, type_, bytes, name, pc, equality)
  return PCSX.addBreakpoint(exe_address, type_, bytes, name, function(address, w, c)
    if is_equality_true(PCSX.getRegisters().pc, pc, equality) then
      PCSX.pauseEmulator()
    end
  end)
end
function debugger:breakpoint_read_write_pc_equality(address, type_, bytes, name, pc, equality)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = debugger:breakpoint_read_write_pc_equality_fun(address, type_, bytes, name, pc, equality)
  counter = counter + 1
end

function debugger:breakpoint_exec_memory_equality_fun(mem_address, bytes, name, value, equality, pc)
  return PCSX.addBreakpoint(pc, 'Exec', bytes, name, function(address, w, c)
    local mem_value = read_value_from_memory(mem_address, bytes)
    if is_equality_true(mem_value, value, equality) then
      PCSX.pauseEmulator()
    end
  end)
end
function debugger:breakpoint_exec_memory_equality(address, bytes, name, value, equality, pc)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = debugger:breakpoint_exec_memory_equality_fun(address, bytes, name, value, equality, pc)
  counter = counter + 1
end

function debugger:breakpoint_what_instruction_accesses_fun(address, name, data)
  return PCSX.addBreakpoint(address, 'Exec', 4, name, function(address, w, c)
    local code = get_4_byte_from_memory(PCSX.getRegisters().pc)
    local bool, offset = isLoad(code)
    if bool then
      local mem_address = get_register_value(bit.band(bit.rshift(code, 21), 0x1f)) + offset
      if data[mem_address] == nil then data[mem_address] = { address = mem_address, count = 0, type = 'R' } end
      data[mem_address].count = data[mem_address].count + 1
    end
    bool, offset = isStore(code)
    if bool then
      local mem_address = get_register_value(bit.band(bit.rshift(code, 21), 0x1f)) + offset
      if data[mem_address] == nil then data[mem_address] = { address = mem_address, count = 0, type = 'W' } end
      data[mem_address].count = data[mem_address].count + 1
    end
  end)
end

local instruction_accesses_table = {}
function debugger:breakpoint_what_instruction_accesses(address, name)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  if instruction_accesses_table[address] ~= nil then return end
  instruction_accesses_table[address] = { address = address, data = {}, name = name, breakpoint = nil }
  instruction_accesses_table[address].breakpoint = debugger:breakpoint_what_instruction_accesses_fun(address, name, instruction_accesses_table[address].data)
end

function debugger:breakpoint_what_access_this_memory_fun(address, bytes, type_, name, data, symbol)
  return PCSX.addBreakpoint(address, type_, bytes, name, function(address, w, c)
    local exe_address = PCSX.getRegisters().pc
    if data[exe_address] == nil then data[exe_address] = { address = exe_address, count = 0, type = symbol } end
    data[exe_address].count = data[exe_address].count + 1
  end)
end

local access_this_memory_table = {}
function debugger:breakpoint_what_access_this_memory(address, bytes, name)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  if access_this_memory_table[address] ~= nil then return end
  access_this_memory_table[address] = { address = address, data = {}, name = name, breakpoint = nil }
  access_this_memory_table[address].read_breakpoint = debugger:breakpoint_what_access_this_memory_fun(address, bytes, 'Read', name, access_this_memory_table[address].data, 'R')
  access_this_memory_table[address].write_breakpoint = debugger:breakpoint_what_access_this_memory_fun(address, bytes, 'Write', name, access_this_memory_table[address].data, 'W')
end


local breakpoint_label = ''
local byte_list = {
  { name = 'Byte'   , value = 1 },
  { name = '2 Byte' , value = 2 },
  { name = '4 Bytes', value = 4 },
}
local equality_list = {
  { name = '==', value = 0 },
  { name = '!=', value = 1 },
  { name = '>' , value = 2 },
  { name = '>=', value = 3 },
  { name = '<' , value = 4 },
  { name = '<=', value = 5 },
}
local register_list = {
  { name = 'at', value = 0x01 },
  { name = 'v0', value = 0x02 },
  { name = 'v1', value = 0x03 },
  { name = 'a0', value = 0x04 },
  { name = 'a1', value = 0x05 },
  { name = 'a2', value = 0x06 },
  { name = 'a3', value = 0x07 },
  { name = 't0', value = 0x08 },
  { name = 't1', value = 0x09 },
  { name = 't2', value = 0x0a },
  { name = 't3', value = 0x0b },
  { name = 't4', value = 0x0c },
  { name = 't5', value = 0x0d },
  { name = 't6', value = 0x0e },
  { name = 't7', value = 0x0f },
  { name = 's0', value = 0x10 },
  { name = 's1', value = 0x11 },
  { name = 's2', value = 0x12 },
  { name = 's3', value = 0x13 },
  { name = 's4', value = 0x14 },
  { name = 's5', value = 0x15 },
  { name = 's6', value = 0x16 },
  { name = 's7', value = 0x17 },
  { name = 't8', value = 0x18 },
  { name = 't9', value = 0x19 },
}
--
local exec_addr = 0
local exec_addr_str = ''
--
local read_write_change_addr = 0
local read_write_change_addr_str = ''
local read_write_change_bytes = 1
local read_write_change_bytes_str = 'Byte'
--
local read_write_equality_addr = 0
local read_write_equality_addr_str = ''
local read_write_equality = 0
local read_write_equality_str = '=='
local read_write_equality_bytes = 1
local read_write_equality_bytes_str = 'Byte'
local read_write_equality_addr_val = 0
local read_write_equality_addr_val_str = ''
local read_write_equality_hex = false
--
local exec_register_equality_addr = 0
local exec_register_equality_addr_str = ''
local exec_register_equality_reg = 0x01
local exec_register_equality_reg_str = 'at'
local exec_register_equality = 0
local exec_register_equality_str = '=='
local exec_register_equality_val = 0
local exec_register_equality_val_str = ''
local exec_register_equality_hex = true
--
local read_write_pc_addr = 0
local read_write_pc_addr_str = ''
local read_write_pc_equality = 0
local read_write_pc_equality_str = '=='
local read_write_pc_bytes = 1
local read_write_pc_bytes_str = 'Byte'
local read_write_pc_val = 0
local read_write_pc_val_str = ''
--
local exec_memory_addr = 0
local exec_memory_addr_str = ''
local exec_memory_bytes = 1
local exec_memory_bytes_str = 'Byte'
local exec_memory_val = 0
local exec_memory_val_str = ''
local exec_memory_val_hex = false
local exec_memory_equality = 0
local exec_memory_equality_str = '=='
local exec_memory_pc = 0
local exec_memory_pc_str = ''
--
local instruction_accesses_addr = 0
local instruction_accesses_addr_str = ''
local remove_instruction_accesses_table = {}
--
local access_this_memory_addr = 0
local access_this_memory_addr_str = ''
local access_this_memory_bytes = 1
local access_this_memory_bytes_str = 'Byte'
local remove_access_this_memory_table = {}

function DrawImguiFrame()
  local bool, value = imgui.Begin('Debugging Script', true)
  if not bool then imgui.End() return end
  if not value then return end

  -- 0th Row
  imgui.TextUnformatted('Label:    ')
  imgui.SameLine()
  bool, value = imgui.extra.InputText('##break-point-label', breakpoint_label)
  if bool then breakpoint_label = value end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(breakpoint_label) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then breakpoint_label = imgui.GetClipboardText() end
  end

  -- 1th Row
  imgui.Separator() imgui.TextUnformatted('|1| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##exec-address', exec_addr_str)
  if bool then
    bool = tonumber(value, 16)
    if bool then
      exec_addr = bool
      exec_addr_str = string.format('%08x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(exec_addr_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        exec_addr = value
        exec_addr_str = string.format('%x', exec_addr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.orange)
  if imgui.Button('Exec##exec-button', 70, 22) then debugger:breakpoint(exec_addr, breakpoint_label, 'Exec', 1) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()

  -- 2nd Row
  imgui.Separator() imgui.TextUnformatted('|2| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##read-write-change-address', read_write_change_addr_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      read_write_change_addr = bool
      read_write_change_addr_str = string.format('%08x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(read_write_change_addr_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        read_write_change_addr = value
        read_write_change_addr_str = string.format('%x', read_write_change_addr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##read-write-change-bytes', read_write_change_bytes_str , function()
    for k, v in pairs(byte_list) do
      if imgui.Selectable(v.name) then
        read_write_change_bytes = v.value
        read_write_change_bytes_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.blue)
  if imgui.Button('Read##read-write-change1-button', 70, 22) then debugger:breakpoint(read_write_change_addr, breakpoint_label, 'Read', read_write_change_bytes) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.green)
  if imgui.Button('Write##read-write-change2-button', 70, 22) then debugger:breakpoint(read_write_change_addr, breakpoint_label, 'Write', read_write_change_bytes) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.green)
  if imgui.Button('Write on Change##read-write-change2-button', 100, 22) then breakpoint_on_write_change(read_write_change_addr, breakpoint_label, read_write_change_bytes) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()

  -- 3rd Row
  imgui.Separator() imgui.TextUnformatted('|3| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##read-write-equality', read_write_equality_addr_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      read_write_equality_addr = bool
      read_write_equality_addr_str = string.format('%08x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(read_write_equality_addr_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        read_write_equality_addr = value
        read_write_equality_addr_str = string.format('%x', read_write_equality_addr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##read-write-equality-bytes', read_write_equality_bytes_str , function()
    for k, v in pairs(byte_list) do
      if imgui.Selectable(v.name) then
        read_write_equality_bytes = v.value
        read_write_equality_bytes_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##read-write-equality-value-equality', read_write_equality_str , function()
    for k, v in pairs(equality_list) do
      if imgui.Selectable(v.name) then
        read_write_equality = v.value
        read_write_equality_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('Value:')
  imgui.SameLine()
  imgui.SetNextItemWidth(65)
  bool, value = imgui.extra.InputText('##read-write-equality-value', read_write_equality_addr_val_str)
  if bool then
    local base = 10
    local base_format = '%d'
    if read_write_equality_hex then
      base = 16
      base_format = '0x%x'
    end
    bool = tonumber(value, base)
    if (bool) then
      read_write_equality_addr_val = bool
      read_write_equality_addr_val_str = string.format(base_format, bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(read_write_equality_addr_val_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      local base = 10
      local base_format = '%d'
      if read_write_equality_hex then
        base = 16
        base_format = '0x%x'
      end
      value = tonumber(imgui.GetClipboardText(), base)
      if value then
        read_write_equality_addr_val = value
        read_write_equality_addr_val_str = string.format(base_format, read_write_equality_addr_val)
      end
    end
  end
  imgui.SameLine()
  bool, value = imgui.Checkbox('Hex##read-write-equality-hex', read_write_equality_hex)
  if bool then
    read_write_equality_hex = value
    if (value) then read_write_equality_addr_val_str = string.format('0x%x', read_write_equality_addr_val)
    else read_write_equality_addr_val_str = string.format('%d', read_write_equality_addr_val) end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.blue)
  if imgui.Button('Read##read-write-equality1-button', 70, 22) then debugger:breakpoint_read_write_equality(read_write_equality_addr, 'Read', read_write_equality_bytes, breakpoint_label, read_write_equality_addr_val, read_write_equality) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.green)
  if imgui.Button('Write##read-write-equality2-button', 70, 22) then debugger:breakpoint_read_write_equality(read_write_equality_addr, 'Write', read_write_equality_bytes, breakpoint_label, read_write_equality_addr_val, read_write_equality) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()

  -- 4th Row
  imgui.Separator() imgui.TextUnformatted('|4| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##exec-register-equality-address', exec_register_equality_addr_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      exec_register_equality_addr = bool
      exec_register_equality_addr_str = string.format('%08x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(exec_register_equality_addr_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        exec_register_equality_addr = value
        exec_register_equality_addr_str = string.format('%x', exec_register_equality_addr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##exec-register-equality-reg', exec_register_equality_reg_str , function()
    for k, v in pairs(register_list) do
      if imgui.Selectable(v.name) then
        exec_register_equality_reg = v.value
        exec_register_equality_reg_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##exec-register-equality', exec_register_equality_str , function()
    for k, v in pairs(equality_list) do
      if imgui.Selectable(v.name) then
        exec_register_equality = v.value
        exec_register_equality_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('Value:')
  imgui.SameLine()
  imgui.SetNextItemWidth(65)
  bool, value = imgui.extra.InputText('##exec-register-equality-value', exec_register_equality_val_str)
  if bool then
    local base = 10
    local base_format = '%d'
    if exec_register_equality_hex then
      base = 16
      base_format = '0x%x'
    end
    bool = tonumber(value, base)
    if (bool) then
      exec_register_equality_val = bool
      exec_register_equality_val_str = string.format(base_format, bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(exec_register_equality_val_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      local base = 10
      local base_format = '%d'
      if exec_register_equality_hex then
        base = 16
        base_format = '0x%x'
      end
      value = tonumber(imgui.GetClipboardText(), base)
      if value then
        exec_register_equality_val = value
        exec_register_equality_val_str = string.format(base_format, exec_register_equality_val)
      end
    end
  end
  imgui.SameLine()
  bool, value = imgui.Checkbox('Hex##exec-register-equality-hex', exec_register_equality_hex)
  if bool then
    exec_register_equality_hex = value
    if (value) then exec_register_equality_val_str = string.format('0x%x', exec_register_equality_val)
    else exec_register_equality_val_str = string.format('%d', exec_register_equality_val) end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.orange)
  if imgui.Button('Exec##exec-register-equality-button', 70, 22) then debugger:breakpoint_exec_register_equality(exec_register_equality_addr, breakpoint_label, exec_register_equality_reg, exec_register_equality, exec_register_equality_val) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()

  -- 5th Row
  imgui.Separator() imgui.TextUnformatted('|5| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##instruction-accesses-address', instruction_accesses_addr_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      instruction_accesses_addr = bool
      instruction_accesses_addr_str = string.format('%08x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(instruction_accesses_addr_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        instruction_accesses_addr = value
        instruction_accesses_addr_str = string.format('%x', instruction_accesses_addr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.red)
  if imgui.Button('What Instruction Accesses##instruction-accesses-button', 160, 22) then debugger:breakpoint_what_instruction_accesses(instruction_accesses_addr, breakpoint_label) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()

  -- 6th Row
  imgui.Separator() imgui.TextUnformatted('|6| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##access-this-memory-address', access_this_memory_addr_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      access_this_memory_addr = bool
      access_this_memory_addr_str = string.format('%08x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(access_this_memory_addr_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        access_this_memory_addr = value
        access_this_memory_addr_str = string.format('%x', access_this_memory_addr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##access-this-memory-bytes', access_this_memory_bytes_str , function()
    for k, v in pairs(byte_list) do
      if imgui.Selectable(v.name) then
        access_this_memory_bytes = v.value
        access_this_memory_bytes_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.pink)
  if imgui.Button('What Access this Memory##access-this-memory-button', 160, 22) then debugger:breakpoint_what_access_this_memory(access_this_memory_addr, access_this_memory_bytes, breakpoint_label) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()

  -- 7th Row
  imgui.Separator() imgui.TextUnformatted('|7| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##read-write-pc', read_write_pc_addr_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      read_write_pc_addr = bool
      read_write_pc_addr_str = string.format('%08x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(read_write_pc_addr_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        read_write_pc_addr = value
        read_write_pc_addr_str = string.format('%x', read_write_pc_addr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##read-write-pc-bytes', read_write_pc_bytes_str , function()
    for k, v in pairs(byte_list) do
      if imgui.Selectable(v.name) then
        read_write_pc_bytes = v.value
        read_write_pc_bytes_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('PC:')
  imgui.SameLine()
  imgui.SetNextItemWidth(60)
  bool, value = imgui.extra.InputText('##read-write-pc-value', read_write_pc_val_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      read_write_pc_val = bool
      read_write_pc_val_str = string.format('%x', bool)
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##read-write-pc-value-equality', read_write_pc_equality_str , function()
    for k, v in pairs(equality_list) do
      if imgui.Selectable(v.name) then
        read_write_pc_equality = v.value
        read_write_pc_equality_str = v.name
      end
      if v.value == 1 then break end
    end
  end)
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.blue)
  if imgui.Button('Read##read-write-pc-1-button', 70, 22) then debugger:breakpoint_read_write_pc_equality(read_write_pc_addr, 'Read', read_write_pc_bytes, breakpoint_label, read_write_pc_val, read_write_pc_equality) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.green)
  if imgui.Button('Write##read-write-pc-2-button', 70, 22) then debugger:breakpoint_read_write_pc_equality(read_write_pc_addr, 'Write', read_write_pc_bytes, breakpoint_label, read_write_pc_val, read_write_pc_equality) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()

  -- 8th Row
  imgui.Separator() imgui.TextUnformatted('|8| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##exec-memory-address', exec_memory_addr_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      exec_memory_addr = bool
      exec_memory_addr_str = string.format('%08x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(exec_memory_addr_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        exec_memory_addr = value
        exec_memory_addr_str = string.format('%x', exec_memory_addr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##exec-memroy-bytes', exec_memory_bytes_str , function()
    for k, v in pairs(byte_list) do
      if imgui.Selectable(v.name) then
        exec_memory_bytes = v.value
        exec_memory_bytes_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##exec-memroy-equality', exec_memory_equality_str , function()
    for k, v in pairs(equality_list) do
      if imgui.Selectable(v.name) then
        exec_memory_equality = v.value
        exec_memory_equality_str = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('Value:')
  imgui.SameLine()
  imgui.SetNextItemWidth(65)
  bool, value = imgui.extra.InputText('##exec-memory-value', exec_memory_val_str)
  if bool then
    local base = 10
    local base_format = '%d'
    if exec_memory_val_hex then
      base = 16
      base_format = '0x%x'
    end
    bool = tonumber(value, base)
    if (bool) then
      exec_memory_val = bool
      exec_memory_val_str = string.format(base_format, bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(exec_memory_val_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      local base = 10
      local base_format = '%d'
      if exec_memory_val_hex then
        base = 16
        base_format = '0x%x'
      end
      value = tonumber(imgui.GetClipboardText(), base)
      if value then
        exec_memory_val = value
        exec_memory_val_str = string.format(base_format, exec_memory_val)
      end
    end
  end
  imgui.SameLine()
  bool, value = imgui.Checkbox('Hex##exec-memroy-hex', exec_memory_val_hex)
  if bool then
    exec_memory_val_hex = value
    if (value) then exec_memory_val_str = string.format('0x%x', exec_memory_val)
    else exec_memory_val_str = string.format('%d', exec_memory_val) end
  end
  imgui.SameLine()
  imgui.TextUnformatted('PC:')
  imgui.SameLine()
  imgui.SetNextItemWidth(60)
  bool, value = imgui.extra.InputText('##exec-memory-pc', exec_memory_pc_str)
  if bool then
    bool = tonumber(value, 16)
    if (bool) then
      exec_memory_pc = bool
      exec_memory_pc_str = string.format('%x', bool)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(exec_memory_pc_str) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        endexec_memory_pc = value
        exec_memory_pc_str = string.format('%x', exec_memory_pc)
      end
    end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.orange)
  if imgui.Button('Exec##exec-memory-button', 70, 22) then debugger:breakpoint_exec_memory_equality(exec_memory_addr, exec_memory_bytes, breakpoint_label, exec_memory_val, exec_memory_equality, exec_memory_pc) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.Separator()

  for k, v in pairs(instruction_accesses_table) do
    imgui.PushID('instruction_accesses_table')
    imgui.safe.Begin(string.format('Accessed addresses by %08x', v.address), function ()
      imgui.TextUnformatted("Name: ") imgui.SameLine() imgui.TextUnformatted(v.name)
      imgui.BeginTable(string.format('t%x', v.address), 4, imgui.constant.TableFlags.Borders)

      imgui.TableSetupColumn("index", imgui.constant.TableColumnFlags.WidthFixed)
      imgui.TableSetupColumn("Address", imgui.constant.TableColumnFlags.WidthFixed)
      imgui.TableSetupColumn("Count", imgui.constant.TableColumnFlags.WidthFixed)
      imgui.TableSetupColumn("Type", imgui.constant.TableColumnFlags.WidthFixed)
      imgui.TableHeadersRow()

      local i = 1
      for k1, v1 in pairs(v.data) do
        imgui.TableNextRow()
        imgui.TableNextColumn()
        imgui.TextUnformatted(i)
        imgui.TableNextColumn()
        if imgui.SmallButton(string.format('%08x##%d%d', v1.address, v.address, v1.address)) then
          imgui.SetClipboardText(string.format('%08x', v1.address))
        end
        if imgui.IsMouseClicked(imgui.constant.MouseButton.Right) and imgui.IsItemHovered() then
          PCSX.GUI.jumpToMemory(v1.address)
        end
        imgui.TableNextColumn()
        imgui.TextUnformatted(v1.count)
        imgui.TableNextColumn()
        imgui.TextUnformatted(v1.type)
        i = i + 1
      end

      imgui.EndTable()
      if imgui.Button(string.format('%08x', v.address)) then
        PCSX.GUI.jumpToPC(v.address)
			  imgui.SetClipboardText(string.format('%08x', v.address))
      end
      imgui.SameLine()
      if v.breakpoint:isEnabled() then
        if imgui.Button('Stop') then v.breakpoint:disable() end
      else
        if imgui.Button('Start') then v.breakpoint:enable() end
      end
      imgui.SameLine()
      if imgui.Button('Reset') then
        for k1, v1 in pairs(v.data) do
          v1.count = 0
        end
      end
      imgui.SameLine()
      if imgui.Button('Remove') then
        v.breakpoint:disable()
        v.breakpoint:remove()
        table.insert(remove_instruction_accesses_table, k)
      end
    end)
    imgui.PopID()
  end
  if #remove_instruction_accesses_table then
    for k, v in pairs(remove_instruction_accesses_table) do
      instruction_accesses_table[v] = nil
    end
    remove_instruction_accesses_table = {}
  end

  for k, v in pairs(access_this_memory_table) do
    imgui.PushID('access_this_memory_table')
    imgui.safe.Begin(string.format('The following instructions accessed %08x', v.address), function ()
      imgui.TextUnformatted("Name: ") imgui.SameLine() imgui.TextUnformatted(v.name)
      imgui.BeginTable(string.format('t%x', v.address), 4, imgui.constant.TableFlags.Borders)

      imgui.TableSetupColumn("index", imgui.constant.TableColumnFlags.WidthFixed)
      imgui.TableSetupColumn("Address", imgui.constant.TableColumnFlags.WidthFixed)
      imgui.TableSetupColumn("Count", imgui.constant.TableColumnFlags.WidthFixed)
      imgui.TableSetupColumn("Type", imgui.constant.TableColumnFlags.WidthFixed)
      imgui.TableHeadersRow()

      local i = 1
      for k1, v1 in pairs(v.data) do
        imgui.TableNextRow()
        imgui.TableNextColumn()
        imgui.TextUnformatted(i)
        imgui.TableNextColumn()
        if imgui.SmallButton(string.format('%08x##%d%d', v1.address, v.address, v1.address)) then
          imgui.SetClipboardText(string.format('%08x', v1.address))
        end
        if imgui.IsMouseClicked(imgui.constant.MouseButton.Right) and imgui.IsItemHovered() then
          PCSX.GUI.jumpToPC(v1.address)
        end
        imgui.TableNextColumn()
        imgui.TextUnformatted(v1.count)
        imgui.TableNextColumn()
        imgui.TextUnformatted(v1.type)
        i = i + 1
      end

      imgui.EndTable()
      if imgui.Button(string.format('%08x', v.address)) then
        PCSX.GUI.jumpToMemory(v.address)
			  imgui.SetClipboardText(string.format('%08x', v.address))
      end
      imgui.SameLine()
      if v.read_breakpoint:isEnabled() and v.write_breakpoint:isEnabled() then
        if imgui.Button('Stop') then v.read_breakpoint:disable() v.write_breakpoint:disable() end
      else
        if imgui.Button('Start') then v.read_breakpoint:enable() v.write_breakpoint:enable() end
      end
      imgui.SameLine()
      if imgui.Button('Reset') then
        for k1, v1 in pairs(v.data) do
          v1.count = 0
        end
      end
      imgui.SameLine()
      if imgui.Button('Remove') then
        v.read_breakpoint:disable()
        v.write_breakpoint:disable()
        v.read_breakpoint:remove()
        v.write_breakpoint:remove()
        table.insert(remove_access_this_memory_table, k)
      end
    end)
    imgui.PopID()
  end
  if #remove_access_this_memory_table then
    for k, v in pairs(remove_access_this_memory_table) do
      access_this_memory_table[v] = nil
    end
    remove_access_this_memory_table = {}
  end

  imgui.End()
end
print('Debugging Script is Loaded')
