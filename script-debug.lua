local bit = require("bit")

local breakpoint_list = {}
local breakpoint_data_list = {}
local counter = 0


function break_point_exec(address, name, type_, bytes)
  print(string.format('0x%x', address), name, type_, bytes)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  breakpoint_list[counter] = PCSX.addBreakpoint(address, type_, bytes, name, function(address, w, c) PCSX.pauseEmulator() end)
  counter = counter + 1
end

function createBreakpointWithArg(address, type_, bytes, name, myArg)
  return PCSX.addBreakpoint(address, type_, bytes, name, function(address, w, c)
    PCSX.pauseEmulator()
  end)
end

storeOpcodes = {
    [0x28] = 'STORE', -- sb
    [0x29] = 'STORE', -- sh
    [0x2a] = 'STORE', -- swl
    [0x2b] = 'STORE', -- sw
    [0x2e] = 'STORE', -- swr
    [0x3a] = 'STORE', -- swc2
}
function isStore(code)
  opcode = bit.rshift(code, 26)
  local t = storeOpcodes[opcode]
  if t == nil then
      return false, nil
  end
  offsett = bit.band(code, 0xffff)
  return true, offsett
end
function get_register_value_from_bits(b)
  if b == 0x01 then return PCSX.getRegisters().GPR.n.at
  elseif b == 0x02 then return PCSX.getRegisters().GPR.n.v0
  elseif b == 0x03 then return PCSX.getRegisters().GPR.n.v1
  elseif b == 0x04 then return PCSX.getRegisters().GPR.n.a0
  elseif b == 0x05 then return PCSX.getRegisters().GPR.n.a1
  elseif b == 0x06 then return PCSX.getRegisters().GPR.n.a2
  elseif b == 0x07 then return PCSX.getRegisters().GPR.n.a3
  elseif b == 0x08 then return PCSX.getRegisters().GPR.n.t0
  elseif b == 0x09 then return PCSX.getRegisters().GPR.n.t1
  elseif b == 0x0a then return PCSX.getRegisters().GPR.n.t2
  elseif b == 0x0b then return PCSX.getRegisters().GPR.n.t3
  elseif b == 0x0c then return PCSX.getRegisters().GPR.n.t4
  elseif b == 0x0d then return PCSX.getRegisters().GPR.n.t5
  elseif b == 0x0e then return PCSX.getRegisters().GPR.n.t6
  elseif b == 0x0f then return PCSX.getRegisters().GPR.n.t7
  elseif b == 0x10 then return PCSX.getRegisters().GPR.n.s0
  elseif b == 0x11 then return PCSX.getRegisters().GPR.n.s1
  elseif b == 0x12 then return PCSX.getRegisters().GPR.n.s2
  elseif b == 0x13 then return PCSX.getRegisters().GPR.n.s3
  elseif b == 0x14 then return PCSX.getRegisters().GPR.n.s4
  elseif b == 0x15 then return PCSX.getRegisters().GPR.n.s5
  elseif b == 0x16 then return PCSX.getRegisters().GPR.n.s6
  elseif b == 0x17 then return PCSX.getRegisters().GPR.n.s7
  elseif b == 0x18 then return PCSX.getRegisters().GPR.n.t8
  elseif b == 0x19 then return PCSX.getRegisters().GPR.n.t9
  elseif b == 0x1c then return PCSX.getRegisters().GPR.n.gp
  elseif b == 0x1d then return PCSX.getRegisters().GPR.n.sp
  elseif b == 0x1f then return PCSX.getRegisters().GPR.n.ra
  end
end
function get_4_byte_from_memory(address)
  local mem = PCSX.getMemPtr()
  local pointer = mem + address - 0x80000000
  pointer = ffi.cast('uint32_t*', pointer)
  return pointer[0]
end
function get_2_byte_from_memory(address)
  local mem = PCSX.getMemPtr()
  local pointer = mem + address - 0x80000000
  pointer = ffi.cast('uint16_t*', pointer)
  return pointer[0]
end
function break_point_exec_on_write_change_fun(address, bytes, label)
  code = get_4_byte_from_memory(PCSX.getRegisters().pc)
  isStoreCode, offset = isStore(code)
  if isStoreCode then
    address = get_register_value_from_bits(bit.band(bit.rshift(code, 21), 0x1f)) + offset
    new_value = get_register_value_from_bits(bit.band(bit.rshift(code, 16), 0x1f))
    
    local old_value = PCSX.getMemPtr()[(address - 0x80000000)]
    if bytes == 2 then old_value = get_2_byte_from_memory(address)
    elseif bytes == 1 then old_value = get_4_byte_from_memory(address)
    end

    if old_value ~= new_value then
      PCSX.pauseEmulator()
    end
  end
end
function break_point_exec_on_write_change(address, name, bytes)
  breakpoint_list[counter] = PCSX.addBreakpoint(address, 'Write', bytes, name, break_point_exec_on_write_change_fun)
  counter = counter + 1
end

--[[
function get_register_value(r)
    local regs = 0xBAADF00D
    if r == 's0' then regs = PCSX.getRegisters().GPR.n.s0
    elseif r == 's1' then regs = PCSX.getRegisters().GPR.n.s1
    elseif r == 's2' then regs = PCSX.getRegisters().GPR.n.s2
    elseif r == 's3' then regs = PCSX.getRegisters().GPR.n.s3
    elseif r == 's4' then regs = PCSX.getRegisters().GPR.n.s4
    elseif r == 's5' then regs = PCSX.getRegisters().GPR.n.s5
    elseif r == 's6' then regs = PCSX.getRegisters().GPR.n.s6
    elseif r == 's7' then regs = PCSX.getRegisters().GPR.n.s7
    elseif r == 't0' then regs = PCSX.getRegisters().GPR.n.t0
    elseif r == 't1' then regs = PCSX.getRegisters().GPR.n.t1
    elseif r == 't2' then regs = PCSX.getRegisters().GPR.n.t2
    elseif r == 't3' then regs = PCSX.getRegisters().GPR.n.t3
    elseif r == 't4' then regs = PCSX.getRegisters().GPR.n.t4
    elseif r == 't5' then regs = PCSX.getRegisters().GPR.n.t5
    elseif r == 't6' then regs = PCSX.getRegisters().GPR.n.t6
    elseif r == 't7' then regs = PCSX.getRegisters().GPR.n.t7
    elseif r == 't8' then regs = PCSX.getRegisters().GPR.n.t8
    elseif r == 't9' then regs = PCSX.getRegisters().GPR.n.t9
    elseif r == 'at' then regs = PCSX.getRegisters().GPR.n.at
    elseif r == 'v0' then regs = PCSX.getRegisters().GPR.n.v0
    elseif r == 'v1' then regs = PCSX.getRegisters().GPR.n.v1
    elseif r == 'a0' then regs = PCSX.getRegisters().GPR.n.a0
    elseif r == 'a1' then regs = PCSX.getRegisters().GPR.n.a1
    elseif r == 'a2' then regs = PCSX.getRegisters().GPR.n.a2
    elseif r == 'a3' then regs = PCSX.getRegisters().GPR.n.a3
    end
    return regs
end

function bpe(a, n)
    break_point_exec(a, n, 'Exec', 1)
end
function bpr(a, n)
    break_point_exec(a, n, 'Read', 1)
end
function bpw(a, n)
    break_point_exec(a, n, 'Write', 1)
end
function bpr2(a, n)
    break_point_exec(a, n, 'Read', 2)
end
function bpw2(a, n)
    break_point_exec(a, n, 'Write', 2)
end
function bpr4(a, n)
    break_point_exec(a, n, 'Read', 4)
end
function bpw4(a, n)
    break_point_exec(a, n, 'Write', 4)
end

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

local registers = {'at', 'v0', 'v1', 'a0', 'a1', 'a2', 'a3',
    't0', 't1', 't2', 't3', 't4', 't5', 't6', 't7', 't8', 't9',
    's0', 's1', 's2', 's3', 's4', 's5', 's6', 's7'
}
local reg = registers[1]

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
function bpmemr(a, v)
    break_point_memory(a, v, 'Read', 1)
end
function bpmemw(a, v)
    break_point_memory(a, v, 'Write', 1)
end
function bpmemr2(a, v)
    break_point_memory(a, v, 'Read', 2)
end
function bpmemw2(a, v)
    break_point_memory(a, v, 'Write', 2)
end
function bpmemr4(a, v)
    break_point_memory(a, v, 'Read', 4)
end
function bpmemw4(a, v)
    break_point_memory(a, v, 'Write', 4)
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


break_point_label = ''
byte_list = { ['4 Bytes'] = 4, ['2 Byte'] = 2, ['Byte'] = 1 }
equality_list = { [0] = '==', [1] = '!=', [2] = '>', [3] = '>=', [4] = '<', [5] = '<=' }
--
exec_addr = 0
exec_addr_str = '0'
--
read_write_change_addr = 0
read_write_change_addr_str = '0'
read_write_change_bytes = 1
read_write_change_bytes_str = 'Byte'
--
read_write_equality_addr = 0
read_write_equality_addr_str = '0'
read_write_equality_equality = 0
read_write_equality_str = '=='
read_write_equality_bytes = 1
read_write_equality_bytes_str = 'Byte'
read_write_equality_addr_val = 0
read_write_equality_addr_val_str = '0'
function DrawImguiFrame()
  local window = imgui.Begin('Debug Script', true)
  if not window then imgui.End() return end
    
  imgui.TextUnformatted('Name:')
  imgui.SameLine()
  local ccc, bbb = imgui.extra.InputText('##break-point-label', break_point_label)
  if ccc then break_point_label = bbb end
  
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  ccc, bbb = imgui.extra.InputText('##exec-address', exec_addr_str)
  if ccc then
    ccc = tonumber(bbb, 16)
    if ccc then
      exec_addr = ccc
      exec_addr_str = string.format('0x%08x', ccc)
    end
  end
  imgui.SameLine()
  if imgui.Button('Exec##exec') then break_point_exec(exec_addr, break_point_label, 'Exec', 1) end
  
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  ccc, bbb = imgui.extra.InputText('##read-write-change-address', read_write_change_addr_str)
  if ccc then
    ccc = tonumber(bbb, 16)
    if (ccc) then
      read_write_change_addr = ccc
      read_write_change_addr_str = string.format('0x%08x', ccc)
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##read-write-change-bytes', read_write_change_bytes_str , function()
    for k, v in pairs(byte_list) do
      if imgui.Selectable(k) then
        read_write_change_bytes = v
        read_write_change_bytes_str = k
      end
    end
  end)
  imgui.SameLine()
  if imgui.Button('Read##read-write-change1') then break_point_exec(read_write_change_addr, break_point_label, 'Read', read_write_change_bytes) end
  imgui.SameLine()
  if imgui.Button('Write##read-write-change2') then break_point_exec(read_write_change_addr, break_point_label, 'Write', read_write_change_bytes) end
  imgui.SameLine()
  if imgui.Button('Write Change##read-write-change2') then break_point_exec_on_write_change(read_write_change_addr, break_point_label, read_write_change_bytes) end
  
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  ccc, bbb = imgui.extra.InputText('##read-write-equality', read_write_equality_addr_str)
  if ccc then
    ccc = tonumber(bbb, 16)
    if (ccc) then
      read_write_equality_addr = ccc
      read_write_equality_addr_str = string.format('0x%08x', ccc)
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##read-write-equality-bytes', read_write_equality_bytes_str , function()
    for k, v in pairs(byte_list) do
      if imgui.Selectable(k) then
        read_write_equality_bytes = v
        read_write_equality_bytes_str = k
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('Value:')
  imgui.SameLine()
  imgui.SetNextItemWidth(50)
  ccc, bbb = imgui.extra.InputText('##read-write-equality-value', read_write_equality_addr_val_str)
  if ccc then
    ccc = tonumber(bbb)
    if (ccc) then
      read_write_equality_addr_val = ccc
      read_write_equality_addr_val_str = string.format('%d', ccc)
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##read-write-equality-value-equality', read_write_equality_str , function()
    for k, v in pairs(equality_list) do
      if imgui.Selectable(v) then
        read_write_equality = k
        read_write_equality_str = v
      end
    end
  end)
  imgui.SameLine()
  if imgui.Button('Read##read-write-equality1') then print('1') end
  imgui.SameLine()
  if imgui.Button('Write##read-write-equality2') then print('2') end

  imgui.End()
end
print('Debugging Script is Loaded')
