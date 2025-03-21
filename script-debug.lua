local bit = require("bit")


local debugger = {
  breakpointList = {},
  counter = 0,
}
local utility = {
  storeOpcodes = {
    [0x28] = 'STORE', -- sb
    [0x29] = 'STORE', -- sh
    [0x2a] = 'STORE', -- swl
    [0x2b] = 'STORE', -- sw
    [0x2e] = 'STORE', -- swr
    [0x3a] = 'STORE', -- swc2
  },
  loadOpcodes = {
    [0x20] = 'LOAD', -- lb
    [0x24] = 'LOAD', -- lbu
    [0x21] = 'LOAD', -- lh
    [0x25] = 'LOAD', -- lhu
    [0x23] = 'LOAD', -- lw
    [0x22] = 'LOAD', -- lwl
    [0x26] = 'LOAD', -- lwr
  },
}

local color = {
  blue = 0xffD94545,
  green = 0xff00A64B,
  orange = 0xff02ABE2,
  red = 0xff6666ff,
  pink = 0xffF066FF,
}


function utility:isStore(code)
  local opcode = bit.rshift(code, 26)
  local t = utility.storeOpcodes[opcode]
  if t == nil then
      return false, nil
  end
  local offsett = bit.band(code, 0xffff)
  return true, offsett
end
function utility:isLoad(code)
  local opcode = bit.rshift(code, 26)
  local t = utility.loadOpcodes[opcode]
  if t == nil then
      return false, nil
  end
  local offsett = bit.band(code, 0xffff)
  return true, offsett
end

function utility:get_register_value(register)
  return PCSX.getRegisters().GPR.r[register]
end
function utility:get4ByteFromMemory(address)
  local mem = PCSX.getMemPtr()
  local pointer = mem + address - 0x80000000
  pointer = ffi.cast('uint32_t*', pointer)
  return pointer[0]
end
function utility:get2ByteFromMemory(address)
  local mem = PCSX.getMemPtr()
  local pointer = mem + address - 0x80000000
  pointer = ffi.cast('uint16_t*', pointer)
  return pointer[0]
end
function utility:readValueFromMemory(address, bytes)
  local value = PCSX.getMemPtr()[(address - 0x80000000)]
  if bytes == 2 then value = utility:get2ByteFromMemory(address)
  elseif bytes == 4 then value = utility:get4ByteFromMemory(address)
  end
  return value
end
function utility:isEqualityTrue(memValue, value, equality)
  local bool = false
  if equality == 0 then bool = memValue == value
  elseif equality == 1 then bool = memValue ~= value
  elseif equality == 2 then bool = memValue > value
  elseif equality == 3 then bool = memValue >= value
  elseif equality == 4 then bool = memValue < value
  elseif equality == 5 then bool = memValue <= value
  end
  return bool
end
function utility:setValueInMemory(address, value, bytes)
  local pointer = ffi.cast('uint8_t*', (PCSX.getMemPtr() + address - 0x80000000))
  if bytes == 2 then pointer = ffi.cast('uint16_t*', (PCSX.getMemPtr() + address - 0x80000000))
  elseif bytes == 4 then pointer = ffi.cast('uint32_t*', (PCSX.getMemPtr() + address - 0x80000000))
  end
  pointer[0] = value
end

function debugger:breakpoint(address, name, type_, bytes)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  debugger.breakpointList[debugger.counter] = PCSX.addBreakpoint(address, type_, bytes, name, function(address, w, c) PCSX.pauseEmulator() end)
  debugger.counter = debugger.counter + 1
end

function debugger:breakpointOnWriteChangeFun(address, bytes, label)
  local code = utility:get4ByteFromMemory(PCSX.getRegisters().pc)
  local isStoreCode, offset = utility:isStore(code)
  if isStoreCode then
    local address = utility:getRegisterValue(bit.band(bit.rshift(code, 21), 0x1f)) + offset
    local new_value = utility:getRegisterValue(bit.band(bit.rshift(code, 16), 0x1f))
    local old_value = utility:readValueFromMemory(address, bytes);

    if old_value ~= new_value then
      PCSX.pauseEmulator()
    end
  end
end
function debugger:breakpointOnWriteChange(address, name, bytes)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  debugger.breakpointList[debugger.counter] = PCSX.addBreakpoint(address, 'Write', bytes, name, debugger.breakpointOnWriteChangeFun)
  debugger.counter = debugger.counter + 1
end

function debugger:breakpointReadWriteEqualityFun(exe_address, type_, bytes, name, value, equality)
  return PCSX.addBreakpoint(exe_address, type_, bytes, name, function(address, w, c)
    local code = utility:get4ByteFromMemory(PCSX.getRegisters().pc)
    local bool, offset = utility:isLoad(code)
    if bool then
      local address = utility:getRegisterValue(bit.band(bit.rshift(code, 21), 0x1f)) + offset
      local mem_value = utility:readValueFromMemory(address, bytes)

      if utility:isEqualityTrue(mem_value, value, equality) then
        PCSX.pauseEmulator()
      end
    end
  end)
end
function debugger:breakpointReadWriteEquality(address, type_, bytes, name, value, equality)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  debugger.breakpointList[debugger.counter] = debugger:breakpointReadWriteEqualityFun(address, type_, bytes, name, value, equality)
  debugger.counter = debugger.counter + 1
end

function debugger:breakpointExecRegisterEqualityFun(exe_address, name, register, equality, value)
  return PCSX.addBreakpoint(exe_address, 'Exec', 4, name, function(address, w, c)
    if utility:isEqualityTrue(utility:getRegisterValue(register), value, equality) then
      PCSX.pauseEmulator()
    end
  end)
end
function debugger:breakpointExecRegisterEquality(address, name, register, equality, value)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  debugger.breakpointList[debugger.counter] = debugger:breakpointExecRegisterEqualityFun(address, name, register, equality, value)
  debugger.counter = debugger.counter + 1
end

function debugger:breakpointReadWritePCEqualityFun(exe_address, type_, bytes, name, pc, equality)
  return PCSX.addBreakpoint(exe_address, type_, bytes, name, function(address, w, c)
    if utility:isEqualityTrue(PCSX.getRegisters().pc, pc, equality) then
      PCSX.pauseEmulator()
    end
  end)
end
function debugger:breakpointReadWritePCEquality(address, type_, bytes, name, pc, equality)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  debugger.breakpointList[debugger.counter] = debugger:breakpointReadWritePCEqualityFun(address, type_, bytes, name, pc, equality)
  debugger.counter = debugger.counter + 1
end

function debugger:breakpointExecMemoryEqualityFun(mem_address, type_, bytes, name, value, equality, pc)
  return PCSX.addBreakpoint(mem_address, type_, bytes, name, function(address, w, c)
    if PCSX.getRegisters().pc == pc then
      local mem_value = utility:readValueFromMemory(mem_address, bytes)
      if utility:isEqualityTrue(mem_value, value, equality) then
        PCSX.pauseEmulator()
      end
    end
  end)
end
function debugger:breakpointExecMemoryEquality(address, bytes, name, value, equality, pc)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  debugger.breakpointList[debugger.counter] = debugger:breakpointExecMemoryEqualityFun(address, 'Read', bytes, name, value, equality, pc)
  debugger.counter = debugger.counter + 1
  debugger.breakpointList[debugger.counter] = debugger:breakpointExecMemoryEqualityFun(address, 'Write', bytes, name, value, equality, pc)
  debugger.counter = debugger.counter + 1
end

function debugger:breakpointWhatInstructionAccessesFun(address, name, data)
  return PCSX.addBreakpoint(address, 'Exec', 4, name, function(address, w, c)
    local code = utility:get4ByteFromMemory(PCSX.getRegisters().pc)
    local bool, offset = utility:isLoad(code)
    if bool then
      local mem_address = utility:getRegisterValue(bit.band(bit.rshift(code, 21), 0x1f)) + offset
      if data[mem_address] == nil then data[mem_address] = { address = mem_address, count = 0, type = 'R' } end
      data[mem_address].count = data[mem_address].count + 1
    end
    bool, offset = utility:isStore(code)
    if bool then
      local mem_address = utility:getRegisterValue(bit.band(bit.rshift(code, 21), 0x1f)) + offset
      if data[mem_address] == nil then data[mem_address] = { address = mem_address, count = 0, type = 'W' } end
      data[mem_address].count = data[mem_address].count + 1
    end
  end)
end

local instructionAccessesTable = {}
function debugger:breakpointWhatInstructionAccesses(address, name)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  if instructionAccessesTable[address] ~= nil then return end
  instructionAccessesTable[address] = { address = address, data = {}, name = name, breakpoint = nil }
  instructionAccessesTable[address].breakpoint = debugger:breakpointWhatInstructionAccessesFun(address, name, instructionAccessesTable[address].data)
end

function debugger:breakpointWhatAccessThisMemoryFun(address, bytes, type_, name, data, symbol)
  return PCSX.addBreakpoint(address, type_, bytes, name, function(address, w, c)
    local exe_address = PCSX.getRegisters().pc
    if data[exe_address] == nil then data[exe_address] = { address = exe_address, count = 0, type = symbol, code = utility:get4ByteFromMemory(PCSX.getRegisters().pc) } end
    data[exe_address].count = data[exe_address].count + 1
  end)
end

local accessThisMemoryTable = {}
function debugger:breakpointWhatAccessThisMemory(address, bytes, name)
  if address < 1 then return end
  if address < 0x80000000 then address = address + 0x80000000 end
  if accessThisMemoryTable[address] ~= nil then return end
  accessThisMemoryTable[address] = { address = address, data = {}, name = name, breakpoint = nil }
  accessThisMemoryTable[address].read_breakpoint = debugger:breakpointWhatAccessThisMemoryFun(address, bytes, 'Read', name, accessThisMemoryTable[address].data, 'R')
  accessThisMemoryTable[address].write_breakpoint = debugger:breakpointWhatAccessThisMemoryFun(address, bytes, 'Write', name, accessThisMemoryTable[address].data, 'W')
end


local breakpointLabel = ''
local byteList = {
  { name = 'Byte'   , value = 1 },
  { name = '2 Byte' , value = 2 },
  { name = '4 Bytes', value = 4 },
}
local equalityList = {
  { name = '==', value = 0 },
  { name = '!=', value = 1 },
  { name = '>' , value = 2 },
  { name = '>=', value = 3 },
  { name = '<' , value = 4 },
  { name = '<=', value = 5 },
}
local registerList = {
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
local execAddr = 0
local execAddrStr = ''
--
local readWriteChangeAddr = 0
local readWriteChangeAddrStr = ''
local readWriteChangeBytes = 1
local readWriteChangeBytesStr = 'Byte'
--
local readWriteEqualityAddr = 0
local readWriteEqualityAddrStr = ''
local readWriteEquality = 0
local readWriteEqualityStr = '=='
local readWriteEqualityBytes = 1
local readWriteEqualityBytesStr = 'Byte'
local readWriteEqualityAddrVal = 0
local readWriteEqualityAddrValStr = ''
local readWriteEqualityHex = false
--
local execRegisterEqualityAddr = 0
local execRegisterEqualityAddrStr = ''
local execRegisterEqualityReg = 0x01
local execRegisterEqualityRegStr = 'at'
local execRegisterEquality = 0
local execRegisterEqualityStr = '=='
local execRegisterEqualityVal = 0
local execRegisterEqualityValStr = ''
local execRegisterEqualityHex = true
--
local readWritePCAddr = 0
local readWritePCAddrStr = ''
local readWritePCEquality = 0
local readWritePCEqualityStr = '=='
local readWritePCBytes = 1
local readWritePCBytesStr = 'Byte'
local readWritePCVal = 0
local readWritePCValStr = ''
--
local execMemoryAddr = 0
local execMemoryAddrStr = ''
local execMemoryBytes = 1
local execMemoryBytesStr = 'Byte'
local execMemoryVal = 0
local execMemoryValStr = ''
local execMemoryValHex = false
local execMemoryEquality = 0
local execMemoryEqualityStr = '=='
local execMemoryPC = 0
local execMemoryPCStr = ''
--
local instructionAccessesAddr = 0
local instructionAccessesAddrStr = ''
local removeInstructionAccessesTable = {}
--
local accessThisMemoryAddr = 0
local accessThisMemoryAddrStr = ''
local accessThisMemoryBytes = 1
local accessThisMemoryBytesStr = 'Byte'
local removeAccessThisMemoryTable = {}


local function Render0thRow()
  imgui.TextUnformatted('Label:    ')
  imgui.SameLine()
  local bool, value = imgui.extra.InputText('##break-point-label', breakpointLabel)
  if bool then breakpointLabel = value end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(breakpointLabel) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then breakpointLabel = imgui.GetClipboardText() end
  end
end

local function Render1stRow()
  imgui.Separator() imgui.TextUnformatted('|1| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  local bool, value = imgui.extra.InputText('##exec-address', execAddrStr)
  if bool then
    value = tonumber(value, 16)
    if value then
      execAddr = value
      execAddrStr = string.format('%08x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(execAddrStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        execAddr = value
        execAddrStr = string.format('%x', execAddr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.orange)
  if imgui.Button('Exec##exec-button', 70, 22) then debugger:breakpoint(execAddr, breakpointLabel, 'Exec', 1) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
end

local function Render2ndRow()
  imgui.Separator() imgui.TextUnformatted('|2| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  local bool, value = imgui.extra.InputText('##read-write-change-address', readWriteChangeAddrStr)
  if bool then
    value = tonumber(value, 16)
    if (bool) then
      readWriteChangeAddr = value
      readWriteChangeAddrStr = string.format('%08x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(readWriteChangeAddrStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        readWriteChangeAddr = value
        readWriteChangeAddrStr = string.format('%x', readWriteChangeAddr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##read-write-change-bytes', readWriteChangeBytesStr , function()
    for k, v in pairs(byteList) do
      if imgui.Selectable(v.name) then
        readWriteChangeBytes = v.value
        readWriteChangeBytesStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.blue)
  if imgui.Button('Read##read-write-change1-button', 70, 22) then debugger:breakpoint(readWriteChangeAddr, breakpointLabel, 'Read', readWriteChangeBytes) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.green)
  if imgui.Button('Write##read-write-change2-button', 70, 22) then debugger:breakpoint(readWriteChangeAddr, breakpointLabel, 'Write', readWriteChangeBytes) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.green)
  if imgui.Button('Write on Change##read-write-change2-button', 100, 22) then debugger:breakpointOnWriteChange(readWriteChangeAddr, breakpointLabel, readWriteChangeBytes) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
end

local function Render3rdRow()
  imgui.Separator() imgui.TextUnformatted('|3| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  local bool, value = imgui.extra.InputText('##read-write-equality', readWriteEqualityAddrStr)
  if bool then
    value = tonumber(value, 16)
    if (value) then
      readWriteEqualityAddr = value
      readWriteEqualityAddrStr = string.format('%08x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(readWriteEqualityAddrStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        readWriteEqualityAddr = value
        readWriteEqualityAddrStr = string.format('%x', readWriteEqualityAddr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##read-write-equality-bytes', readWriteEqualityBytesStr , function()
    for k, v in pairs(byteList) do
      if imgui.Selectable(v.name) then
        readWriteEqualityBytes = v.value
        readWriteEqualityBytesStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##read-write-equality-value-equality', readWriteEqualityStr , function()
    for k, v in pairs(equalityList) do
      if imgui.Selectable(v.name) then
        readWriteEquality = v.value
        readWriteEqualityStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('Value:')
  imgui.SameLine()
  imgui.SetNextItemWidth(65)
  bool, value = imgui.extra.InputText('##read-write-equality-value', readWriteEqualityAddrValStr)
  if bool then
    local base = 10
    local base_format = '%d'
    if readWriteEqualityHex then
      base = 16
      base_format = '0x%x'
    end
    value = tonumber(value, base)
    if (value) then
      readWriteEqualityAddrVal = value
      readWriteEqualityAddrValStr = string.format(base_format, value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(readWriteEqualityAddrValStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      local base = 10
      local base_format = '%d'
      if readWriteEqualityHex then
        base = 16
        base_format = '0x%x'
      end
      value = tonumber(imgui.GetClipboardText(), base)
      if value then
        readWriteEqualityAddrVal = value
        readWriteEqualityAddrValStr = string.format(base_format, readWriteEqualityAddrVal)
      end
    end
  end
  imgui.SameLine()
  bool, value = imgui.Checkbox('Hex##read-write-equality-hex', readWriteEqualityHex)
  if bool then
    readWriteEqualityHex = value
    if (value) then readWriteEqualityAddrValStr = string.format('0x%x', readWriteEqualityAddrVal)
    else readWriteEqualityAddrValStr = string.format('%d', readWriteEqualityAddrVal) end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.blue)
  if imgui.Button('Read##read-write-equality1-button', 70, 22) then debugger:breakpointReadWriteEquality(readWriteEqualityAddr, 'Read', readWriteEqualityBytes, breakpointLabel, readWriteEqualityAddrVal, readWriteEquality) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.green)
  if imgui.Button('Write##read-write-equality2-button', 70, 22) then debugger:breakpointReadWriteEquality(readWriteEqualityAddr, 'Write', readWriteEqualityBytes, breakpointLabel, readWriteEqualityAddrVal, readWriteEquality) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
end

local function Render4thRow()
  imgui.Separator() imgui.TextUnformatted('|4| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  local bool, value = imgui.extra.InputText('##exec-register-equality-address', execRegisterEqualityAddrStr)
  if bool then
    value = tonumber(value, 16)
    if (value) then
      execRegisterEqualityAddr = value
      execRegisterEqualityAddrStr = string.format('%08x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(execRegisterEqualityAddrStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        execRegisterEqualityAddr = value
        execRegisterEqualityAddrStr = string.format('%x', execRegisterEqualityAddr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##exec-register-equality-reg', execRegisterEqualityRegStr , function()
    for k, v in pairs(registerList) do
      if imgui.Selectable(v.name) then
        execRegisterEqualityReg = v.value
        execRegisterEqualityRegStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##exec-register-equality', execRegisterEqualityStr , function()
    for k, v in pairs(equalityList) do
      if imgui.Selectable(v.name) then
        execRegisterEquality = v.value
        execRegisterEqualityStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('Value:')
  imgui.SameLine()
  imgui.SetNextItemWidth(65)
  bool, value = imgui.extra.InputText('##exec-register-equality-value', execRegisterEqualityValStr)
  if bool then
    local base = 10
    local base_format = '%d'
    if execRegisterEqualityHex then
      base = 16
      base_format = '0x%x'
    end
    value = tonumber(value, base)
    if (value) then
      execRegisterEqualityVal = value
      execRegisterEqualityValStr = string.format(base_format, value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(execRegisterEqualityValStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      local base = 10
      local base_format = '%d'
      if execRegisterEqualityHex then
        base = 16
        base_format = '0x%x'
      end
      value = tonumber(imgui.GetClipboardText(), base)
      if value then
        execRegisterEqualityVal = value
        execRegisterEqualityValStr = string.format(base_format, execRegisterEqualityVal)
      end
    end
  end
  imgui.SameLine()
  bool, value = imgui.Checkbox('Hex##exec-register-equality-hex', execRegisterEqualityHex)
  if bool then
    execRegisterEqualityHex = value
    if (value) then execRegisterEqualityValStr = string.format('0x%x', execRegisterEqualityVal)
    else execRegisterEqualityValStr = string.format('%d', execRegisterEqualityVal) end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.orange)
  if imgui.Button('Exec##exec-register-equality-button', 70, 22) then debugger:breakpointExecRegisterEquality(execRegisterEqualityAddr, breakpointLabel, execRegisterEqualityReg, execRegisterEquality, execRegisterEqualityVal) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
end

local function Render5thRow()
  imgui.Separator() imgui.TextUnformatted('|5| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  local bool, value = imgui.extra.InputText('##instruction-accesses-address', instructionAccessesAddrStr)
  if bool then
    value = tonumber(value, 16)
    if (value) then
      instructionAccessesAddr = value
      instructionAccessesAddrStr = string.format('%08x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(instructionAccessesAddrStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        instructionAccessesAddr = value
        instructionAccessesAddrStr = string.format('%x', instructionAccessesAddr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.red)
  if imgui.Button('What Instruction Accesses##instruction-accesses-button', 160, 22) then debugger:breakpointWhatInstructionAccesses(instructionAccessesAddr, breakpointLabel) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
end

local function Render6thRow()
  imgui.Separator() imgui.TextUnformatted('|6| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  local bool, value = imgui.extra.InputText('##access-this-memory-address', accessThisMemoryAddrStr)
  if bool then
    value = tonumber(value, 16)
    if (value) then
      accessThisMemoryAddr = value
      accessThisMemoryAddrStr = string.format('%08x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(accessThisMemoryAddrStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        accessThisMemoryAddr = value
        accessThisMemoryAddrStr = string.format('%x', accessThisMemoryAddr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##access-this-memory-bytes', accessThisMemoryBytesStr , function()
    for k, v in pairs(byteList) do
      if imgui.Selectable(v.name) then
        accessThisMemoryBytes = v.value
        accessThisMemoryBytesStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.pink)
  if imgui.Button('What Access this Memory##access-this-memory-button', 160, 22) then debugger:breakpointWhatAccessThisMemory(accessThisMemoryAddr, accessThisMemoryBytes, breakpointLabel) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
end

local function Render7thRow()
  imgui.Separator() imgui.TextUnformatted('|7| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##read-write-pc', readWritePCAddrStr)
  if bool then
    value = tonumber(value, 16)
    if (value) then
      readWritePCAddr = value
      readWritePCAddrStr = string.format('%08x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(readWritePCAddrStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        readWritePCAddr = value
        readWritePCAddrStr = string.format('%x', readWritePCAddr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##read-write-pc-bytes', readWritePCBytesStr , function()
    for k, v in pairs(byteList) do
      if imgui.Selectable(v.name) then
        readWritePCBytes = v.value
        readWritePCBytesStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('PC:')
  imgui.SameLine()
  imgui.SetNextItemWidth(60)
  bool, value = imgui.extra.InputText('##read-write-pc-value', readWritePCValStr)
  if bool then
    value = tonumber(value, 16)
    if (value) then
      readWritePCVal = value
      readWritePCValStr = string.format('%x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(readWritePCValStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        readWritePCVal = value
        readWritePCValStr = string.format('%x', value)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##read-write-pc-value-equality', readWritePCEqualityStr , function()
    for k, v in pairs(equalityList) do
      if imgui.Selectable(v.name) then
        readWritePCEquality = v.value
        readWritePCEqualityStr = v.name
      end
      if v.value == 1 then break end
    end
  end)
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.blue)
  if imgui.Button('Read##read-write-pc-1-button', 70, 22) then debugger:breakpointReadWritePCEquality(readWritePCAddr, 'Read', readWritePCBytes, breakpointLabel, readWritePCVal, readWritePCEquality) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.green)
  if imgui.Button('Write##read-write-pc-2-button', 70, 22) then debugger:breakpointReadWritePCEquality(readWritePCAddr, 'Write', readWritePCBytes, breakpointLabel, readWritePCVal, readWritePCEquality) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
end

local function Render8thRow()
  imgui.Separator() imgui.TextUnformatted('|8| ') imgui.SameLine()
  imgui.TextUnformatted('Address:')
  imgui.SameLine()
  imgui.SetNextItemWidth(75)
  bool, value = imgui.extra.InputText('##exec-memory-address', execMemoryAddrStr)
  if bool then
    value = tonumber(value, 16)
    if (value) then
      execMemoryAddr = value
      execMemoryAddrStr = string.format('%08x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(execMemoryAddrStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        execMemoryAddr = value
        execMemoryAddrStr = string.format('%x', execMemoryAddr)
      end
    end
  end
  imgui.SameLine()
  imgui.PushItemWidth(65)
  imgui.safe.BeginCombo('##exec-memroy-bytes', execMemoryBytesStr , function()
    for k, v in pairs(byteList) do
      if imgui.Selectable(v.name) then
        execMemoryBytes = v.value
        execMemoryBytesStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.PushItemWidth(40)
  imgui.safe.BeginCombo('##exec-memroy-equality', execMemoryEqualityStr , function()
    for k, v in pairs(equalityList) do
      if imgui.Selectable(v.name) then
        execMemoryEquality = v.value
        execMemoryEqualityStr = v.name
      end
    end
  end)
  imgui.SameLine()
  imgui.TextUnformatted('Value:')
  imgui.SameLine()
  imgui.SetNextItemWidth(65)
  bool, value = imgui.extra.InputText('##exec-memory-value', execMemoryValStr)
  if bool then
    local base = 10
    local base_format = '%d'
    if execMemoryValHex then
      base = 16
      base_format = '0x%x'
    end
    value = tonumber(value, base)
    if (value) then
      execMemoryVal = value
      execMemoryValStr = string.format(base_format, value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(execMemoryValStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      local base = 10
      local base_format = '%d'
      if execMemoryValHex then
        base = 16
        base_format = '0x%x'
      end
      value = tonumber(imgui.GetClipboardText(), base)
      if value then
        execMemoryVal = value
        execMemoryValStr = string.format(base_format, execMemoryVal)
      end
    end
  end
  imgui.SameLine()
  bool, value = imgui.Checkbox('Hex##exec-memroy-hex', execMemoryValHex)
  if bool then
    execMemoryValHex = value
    if (value) then execMemoryValStr = string.format('0x%x', execMemoryVal)
    else execMemoryValStr = string.format('%d', execMemoryVal) end
  end
  imgui.SameLine()
  imgui.TextUnformatted('PC:')
  imgui.SameLine()
  imgui.SetNextItemWidth(60)
  bool, value = imgui.extra.InputText('##exec-memory-pc', execMemoryPCStr)
  if bool then
    value = tonumber(value, 16)
    if (value) then
      execMemoryPC = value
      execMemoryPCStr = string.format('%x', value)
    end
  end
  if imgui.IsItemHovered() then
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Left) then imgui.SetClipboardText(execMemoryPCStr) end
    if imgui.IsMouseDoubleClicked(imgui.constant.MouseButton.Right) then
      value = tonumber(imgui.GetClipboardText(), 16)
      if value then
        execMemoryPC = value
        execMemoryPCStr = string.format('%x', value)
      end
    end
  end
  imgui.SameLine()
  imgui.PushStyleVar(imgui.constant.StyleVar.FrameRounding, 3)
  imgui.PushStyleColor(imgui.constant.Col.Button, color.orange)
  if imgui.Button('Exec##exec-memory-button', 70, 22) then debugger:breakpointExecMemoryEquality(execMemoryAddr, execMemoryBytes, breakpointLabel, execMemoryVal, execMemoryEquality, execMemoryPC) end
  imgui.PopStyleColor()
  imgui.PopStyleVar()
  imgui.Separator()
end

local function RenderChildWindows()
  for k, v in pairs(instructionAccessesTable) do
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
      end

      imgui.EndTable()
      if imgui.Button(string.format('%08x', v.address)) then
        PCSX.GUI.jumpToPC(v.address)
			  imgui.SetClipboardText(string.format('%08x', v.address))
      end
      imgui.SameLine()
      if imgui.Button('Copy All') then
        local value = ''
        for k1, v1 in pairs(v.data) do
          value = value .. string.format('%08x\n', v1.address)
        end
        imgui.SetClipboardText(value)
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
        table.insert(removeInstructionAccessesTable, k)
      end
    end)
    imgui.PopID()
  end
  if #removeInstructionAccessesTable then
    for k, v in pairs(removeInstructionAccessesTable) do
      instructionAccessesTable[v] = nil
    end
    removeInstructionAccessesTable = {}
  end

  for k, v in pairs(accessThisMemoryTable) do
    imgui.PushID('access_this_memory_table')
    imgui.safe.Begin(string.format('The following instructions accessed %08x', v.address), function ()
      imgui.TextUnformatted("Name: ") imgui.SameLine() imgui.TextUnformatted(v.name)
      imgui.BeginTable(string.format('t%x', v.address), 5, imgui.constant.TableFlags.Borders)

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
        imgui.TableNextColumn()
        if imgui.SmallButton(string.format('NOP##nop%d%d', v1.address, v.address)) then
          utility:setValueInMemory(v1.address, 0x0, 4)
        end
        imgui.SameLine()
        if imgui.SmallButton(string.format('UN-NOP##unnop%d%d', v1.address, v.address)) then
          utility:setValueInMemory(v1.address, v1.code, 4)
        end
        i = i + 1
      end

      imgui.EndTable()
      if imgui.Button(string.format('%08x', v.address)) then
        PCSX.GUI.jumpToMemory(v.address)
			  imgui.SetClipboardText(string.format('%08x', v.address))
      end
      imgui.SameLine()
      if imgui.Button('Copy All') then
        local value = ''
        for k1, v1 in pairs(v.data) do
          value = value .. string.format('%08x\n', v1.address)
        end
        imgui.SetClipboardText(value)
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
        table.insert(removeAccessThisMemoryTable, k)
      end
    end)
    imgui.PopID()
  end
  if #removeAccessThisMemoryTable then
    for k, v in pairs(removeAccessThisMemoryTable) do
      accessThisMemoryTable[v] = nil
    end
    removeAccessThisMemoryTable = {}
  end
end

function DrawImguiFrame()
  imgui.safe.Begin('Debugging Script', function ()
    Render0thRow()
    Render1stRow()
    Render2ndRow()
    Render3rdRow()
    Render4thRow()
    Render5thRow()
    Render6thRow()
    Render7thRow()
    Render8thRow()
    RenderChildWindows()
  end)
end
print('Debugging Script is Loaded')
