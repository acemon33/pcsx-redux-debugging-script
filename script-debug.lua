local bit = require("bit")

local breakpoint_list = {}
local breakpoint_data_list = {}
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

  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = PCSX.addBreakpoint(address, type_, bytes, name, function(address, w, c) PCSX.pauseEmulator() end)
  counter = counter + 1
end

  local opcode = bit.rshift(code, 26)
  local t = storeOpcodes[opcode]
  if t == nil then
      return false, nil
  end
  local offsett = bit.band(code, 0xffff)
  return true, offsett
end
  local opcode = bit.rshift(code, 26)
  local t = loadOpcodes[opcode]
  if t == nil then
      return false, nil
  end
  local offsett = bit.band(code, 0xffff)
  return true, offsett
end
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
  local mem = PCSX.getMemPtr()
  local pointer = mem + address - 0x80000000
  pointer = ffi.cast('uint32_t*', pointer)
  return pointer[0]
end
  local mem = PCSX.getMemPtr()
  local pointer = mem + address - 0x80000000
  pointer = ffi.cast('uint16_t*', pointer)
  return pointer[0]
end
  local value = PCSX.getMemPtr()[(address - 0x80000000)]
  if bytes == 2 then value = get_2_byte_from_memory(address)
  elseif bytes == 1 then value = get_4_byte_from_memory(address)
  end
  return value
end
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
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = PCSX.addBreakpoint(address, 'Write', bytes, name, break_point_exec_on_write_change_fun)
  counter = counter + 1
end

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
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = breakpoint_read_write_equality_fun(address, type_, bytes, name, value, equality)
  counter = counter + 1
end

  return PCSX.addBreakpoint(exe_address, 'Exec', 4, name, function(address, w, c)
    if is_equality_true(get_register_value(register), value, equality) then
      PCSX.pauseEmulator()
    end
  end)
end
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = breakpoint_exec_register_equality_fun(address, name, register, equality, value)
  counter = counter + 1
end

--[[
local table_what_instruction_access = {}
function what_ins_access_base(a, n, r)
    if a < 1 then return end
    if a < 0x80000000 then a = a + 0x80000000 end
    break_point_list[counter] = PCSX.addBreakpoint(a, 'Exec', 1, n,
        function(address, width, cause)
          PCSX.pauseEmulator()
          local regs = get_register_value(r)
          local str = string.format('%x', regs)
          table_what_instruction_access[str] = regs
          PCSX.resumeEmulator()
        end
      )
    counter = counter + 1
end
function what_ins_access(a, r)
    what_ins_access_base(a, '', r)
end

local table_what_access_this = {}
function what_access_this_base(a, n)
    if a < 1 then return end
    if a < 0x80000000 then a = a + 0x80000000 end
    break_point_list[counter] = PCSX.addBreakpoint(a, 'Read', 1, n,
        function(address, width, cause)
          PCSX.pauseEmulator()
          local str = string.format('%x - R', PCSX.getRegisters().pc)
          table_what_access_this[str] = PCSX.getRegisters().pc
          PCSX.resumeEmulator()
        end
      )
    counter = counter + 1
    break_point_list[counter] = PCSX.addBreakpoint(a, 'Write', 1, n,
        function(address, width, cause)
          PCSX.pauseEmulator()
          local str = string.format('%x - W', PCSX.getRegisters().pc)
          table_what_access_this[str] = PCSX.getRegisters().pc
          PCSX.resumeEmulator()
        end
      )
    counter = counter + 1
end
function what_access_this(a)
    what_access_this_base(a, '')
end

function break_point_register(a, r, v)
    if a < 1 then return end
    if a < 0x80000000 then a = a + 0x80000000 end
    break_point_list[counter] = PCSX.addBreakpoint(a, 'Exec', 1, r,
        function(address, width, cause)
          local regs = get_register_value(r)
          if regs == v then PCSX.pauseEmulator() end
        end
      )
    counter = counter + 1
end
function bpreg(a, r, v, t, b)
    break_point_register(a, r, v)
end

function break_point_memory(a, v)
    if a < 1 then return end
    if a < 0x80000000 then a = a + 0x80000000 end
    break_point_list[counter] = PCSX.addBreakpoint(a, t, b, '' .. v,
        function(address, width, cause)
          local memory = PCSX.getMemPtr()[a - 0x80000000]
          if memory == v then PCSX.pauseEmulator() end
        end
      )
    counter = counter + 1
end

test02_breakpoints = {}
test02_arrange = {}
test02_counter = {}
test02_total = 0
function test01(a, r)
  if a < 1 then return end
    if a < 0x80000000 then a = a + 0x80000000 end
    table.insert(test02_breakpoints, PCSX.addBreakpoint(a, 'Exec', 1, r,
        function(address, width, cause)
          local regs = get_register_value(r)
          if test02_counter[regs] == nil then
            test02_counter[regs] = 1
            test02_total = test02_total + 1
            test02_arrange[test02_total] = regs
          else
            test02_counter[regs] = test02_counter[regs] + 1
          end
        end
      ))
end
local ji = ''
local ji2 = 1
]]

local break_point_label = ''
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
local read_write_equality_addr_val_str = '0'
local read_write_equality_hex = false
--
local exec_register_equality_addr = 0
local exec_register_equality_addr_str = ''
local exec_register_equality_reg = 0x01
local exec_register_equality_reg_str = 'at'
local exec_register_equality = 0
local exec_register_equality_str = '=='
local exec_register_equality_val = 0
local exec_register_equality_val_str = '0'
local exec_register_equality_hex = true
function DrawImguiFrame()
  local window = imgui.Begin('Debug Script', true)
  if not window then imgui.End() return end

  imgui.TextUnformatted('Label:    ')
  imgui.SameLine()
  local ccc, bbb = imgui.extra.InputText('##break-point-label', break_point_label)
  if ccc then break_point_label = bbb end

  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(70)
  ccc, bbb = imgui.extra.InputText('##exec-address', exec_addr_str)
  if ccc then
    ccc = tonumber(bbb, 16)
    if ccc then
      exec_addr = ccc
      exec_addr_str = string.format('%08x', ccc)
    end
  end
  imgui.SameLine()
  if imgui.Button('Exec##exec') then breakpoint(exec_addr, break_point_label, 'Exec', 1) end

  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  ccc, bbb = imgui.extra.InputText('##read-write-change-address', read_write_change_addr_str)
  if ccc then
    ccc = tonumber(bbb, 16)
    if (ccc) then
      read_write_change_addr = ccc
      read_write_change_addr_str = string.format('%08x', ccc)
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
  if imgui.Button('Read##read-write-change1') then breakpoint(read_write_change_addr, break_point_label, 'Read', read_write_change_bytes) end
  imgui.SameLine()
  if imgui.Button('Write##read-write-change2') then breakpoint(read_write_change_addr, break_point_label, 'Write', read_write_change_bytes) end
  imgui.SameLine()
  if imgui.Button('Write Change##read-write-change2') then breakpoint_on_write_change(read_write_change_addr, break_point_label, read_write_change_bytes) end

  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  ccc, bbb = imgui.extra.InputText('##read-write-equality', read_write_equality_addr_str)
  if ccc then
    ccc = tonumber(bbb, 16)
    if (ccc) then
      read_write_equality_addr = ccc
      read_write_equality_addr_str = string.format('%08x', ccc)
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
  ccc, bbb = imgui.Checkbox('Hex##read-write-equality-hex', read_write_equality_hex)
  if ccc then
    read_write_equality_hex = bbb
    if (bbb) then read_write_equality_addr_val_str = string.format('0x%x', read_write_equality_addr_val)
    else read_write_equality_addr_val_str = string.format('%d', read_write_equality_addr_val) end
  end
  imgui.SameLine()
  imgui.SetNextItemWidth(50)
  ccc, bbb = imgui.extra.InputText('##read-write-equality-value', read_write_equality_addr_val_str)
  if ccc then
    local base = 10
    local base_format = '%d'
    if read_write_equality_hex then
      base = 16
      base_format = '0x%x'
    end
    ccc = tonumber(bbb, base)
    if (ccc) then
      read_write_equality_addr_val = ccc
      read_write_equality_addr_val_str = string.format(base_format, ccc)
    end
  end
  imgui.SameLine()
  if imgui.Button('Read##read-write-equality1') then breakpoint_read_write_equality(read_write_equality_addr, 'Read', read_write_equality_bytes, break_point_label, read_write_equality_addr_val, read_write_equality) end
  imgui.SameLine()
  if imgui.Button('Write##read-write-equality2') then breakpoint_read_write_equality(read_write_equality_addr, 'Write', read_write_equality_bytes, break_point_label, read_write_equality_addr_val, read_write_equality) end

  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  ccc, bbb = imgui.extra.InputText('##exec-register-equality-address', exec_register_equality_addr_str)
  if ccc then
    ccc = tonumber(bbb, 16)
    if (ccc) then
      exec_register_equality_addr = ccc
      exec_register_equality_addr_str = string.format('%08x', ccc)
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
  ccc, bbb = imgui.Checkbox('Hex##exec-register-equality-hex', exec_register_equality_hex)
  if ccc then
    exec_register_equality_hex = bbb
    if (bbb) then exec_register_equality_val_str = string.format('0x%x', exec_register_equality_val)
    else exec_register_equality_val_str = string.format('%d', exec_register_equality_val) end
  end
  imgui.SameLine()
  imgui.SetNextItemWidth(50)
  ccc, bbb = imgui.extra.InputText('##exec-register-equality-value', exec_register_equality_val_str)
  if ccc then
    local base = 10
    local base_format = '%d'
    if exec_register_equality_hex then
      base = 16
      base_format = '0x%x'
    end
    ccc = tonumber(bbb, base)
    if (ccc) then
      exec_register_equality_val = ccc
      exec_register_equality_val_str = string.format(base_format, ccc)
    end
  end
  imgui.SameLine()
  if imgui.Button('Exec on Register##exec-register-equality-button') then breakpoint_exec_register_equality(exec_register_equality_addr, break_point_label, exec_register_equality_reg, exec_register_equality, exec_register_equality_val) end

  imgui.End()
end
print('Debugging Script is Loaded')
