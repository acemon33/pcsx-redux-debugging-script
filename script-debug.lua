local break_point_list = {}
local memory1 = ffi.cast('uint8_t*', PCSX.getMemPtr())
local memory2 = PCSX.getMemPtr()
local counter = 0

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

function break_point_exec(a, n, t, b)
    if a < 1 then return end
    if a < 0x80000000 then a = a + 0x80000000 end
    break_point_list[counter] = PCSX.addBreakpoint(a, t, b, n, function(a, w, c) PCSX.pauseEmulator() end)
    counter = counter + 1
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
--local ji = ''
--local ji2 = 1

break_point_label = ''
--
exec_addr = 0
exec_addr_str = '0'
--
read_write_change_addr = 0
read_write_change_addr_str = '0'
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
  if imgui.Button('Exec##exec') then print('exec: ', exec_addr_str) end
  
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
  if imgui.Button('Read##read-write-change1') then print('Read: ', read_write_change_addr_str) end
  imgui.SameLine()
  if imgui.Button('Write##read-write-change2') then print('Write: ', read_write_change_addr_str) end
  imgui.SameLine()
  if imgui.Button('Write Change##read-write-change3') then print('Write Change: ', read_write_change_addr_str) end
  
  imgui.End()
end
print('Debugging Script is Loaded')
