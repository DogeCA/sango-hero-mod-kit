-- ============================================================
-- 三國英豪 SangoHero.exe 作弊部署脚本 (v9-config)
-- 用法：游戏启动 → 进图 → 用 CE 断点抓世界对象(见下) → 修改
--       WORLD 变量 → 整段粘贴进 CE Lua 引擎执行
-- 功能：全屏攻击(F7开关) + 双轴4倍移速
-- 依赖：CE 已附加 SangoHero.exe
-- ============================================================

-- 【每局必改】世界对象地址。抓取方法：
--   CE → Memory View → Tools → Auto Assemble? 不用。
--   直接法：让 ZCode 挂执行断点 sub_469190 (0x469190)，
--   游戏里挥一刀，断点寄存器 ECX/ESI = 世界对象地址。
WORLD = 0x28582020   -- ← 每局更新这个值
MEMO = WORLD + 0xA00EBC   -- 命中备忘数组(8×dword)，勿手改

-- ===== 以下内容一般不用改 =====
local SITES = {
  {a=0x4691FA, len=7,  d8=0x00, imm=-99999, disp={0x8B,0x4E,0x08}},
  {a=0x469218, len=6,  d8=0x08, imm= 99999, disp={0x8B,0xCB}},
  {a=0x469245, len=7,  d8=0x0C, imm= 99999, disp={0x8B,0x4E,0x04}},
  {a=0x469263, len=10, d8=0x04, imm=-99999, disp={0x8B,0x2D,0x4C,0xC2,0x4D,0x00}},
  {a=0x4692D8, len=8,  d8=0x20, imm=-99999, disp={0x8B,0x4C,0x24,0x34}},
  {a=0x4692F4, len=10, d8=0x24, imm= 99999, disp={0x8A,0x82,0x94,0x0E,0xA0,0x00}},
}
if _G.sango then
  return 'already deployed, on=' .. tostring(_G.sango.on)
end
for i, s in ipairs(SITES) do
  local b = readBytes(s.a, 4, true)
  if not b or b[1] ~= 0x89 or b[2] ~= 0x4C or b[3] ~= 0xC5 or b[4] ~= s.d8 then
    return 'ABORT: site ' .. i .. ' bytes not original (重复部署或版本不对)'
  end
end
local cave = allocateMemory(320)
if not cave or cave < 0x10000 then return 'ABORT: allocateMemory fail' end
for i, s in ipairs(SITES) do
  local base = cave + (i - 1) * 48
  local stub = {0x80, 0x7C, 0x24, 0x18, 0x05, 0x74, (s.len + 12) & 0xFF,
                0xC7, 0x84, 0xC5}
  local d = s.d8
  for k = 0, 3 do stub[#stub + 1] = (d >> (8 * k)) & 0xFF end
  local v = s.imm & 0xFFFFFFFF
  for k = 0, 3 do stub[#stub + 1] = (v >> (8 * k)) & 0xFF end
  for _, db in ipairs(s.disp) do stub[#stub + 1] = db end
  stub[#stub + 1] = 0xE9
  local rel = (s.a + s.len) - (base + #stub + 5)
  local rr = rel & 0xFFFFFFFF
  for k = 0, 3 do stub[#stub + 1] = (rr >> (8 * k)) & 0xFF end
  stub[#stub + 1] = 0x89; stub[#stub + 1] = 0x4C; stub[#stub + 1] = 0xC5; stub[#stub + 1] = s.d8
  for _, db in ipairs(s.disp) do stub[#stub + 1] = db end
  stub[#stub + 1] = 0xE9
  rel = (s.a + s.len) - (base + #stub + 5)
  rr = rel & 0xFFFFFFFF
  for k = 0, 3 do stub[#stub + 1] = (rr >> (8 * k)) & 0xFF end
  writeBytes(base, stub)
end
local zeros = {}
for i = 1, 400 do zeros[i] = 0 end
local memof = {}
for i = 1, 32 do memof[i] = 0xFF end
local GATE = {[0]=true, [1]=true, [2]=true, [3]=true, [5]=true,
              [16]=true, [17]=true, [19]=true, [21]=true}
local st = {sites = SITES, cave = cave, memo = MEMO, on = false, last = 0}
_G.sango = st
local function applyAll()
  for i, s in ipairs(st.sites) do
    s.saved = readBytes(s.a, s.len, true)
    local p = {0xE9}
    local rr = ((st.cave + (i - 1) * 48) - (s.a + 5)) & 0xFFFFFFFF
    for k = 0, 3 do p[#p + 1] = (rr >> (8 * k)) & 0xFF end
    while #p < s.len do p[#p + 1] = 0x90 end
    writeBytes(s.a, p)
  end
  st.on = true
end
local function restoreAll()
  for i, s in ipairs(st.sites) do
    if s.saved then writeBytes(s.a, s.saved) end
  end
  st.on = false
end
st.applyAll = applyAll
st.restoreAll = restoreAll
local t = createTimer(nil, false)
t.Interval = 30
t.OnTimer = function(timer)
  local p = readInteger(0x4DC450)
  if p and p ~= 0 then
    local state = readInteger(p + 8)
    if state and GATE[state] then
      local base = readInteger(0x4DC24C)
      if base and base > 0x10000 and base < 0x7FFF0000 then
        writeBytes(base, zeros)
      end
      writeBytes(MEMO, memof)
    end
  end
  -- F7 (VK 0x76) 开关全屏攻击
  if isKeyPressed(0x76) and os.clock() - st.last > 0.4 then
    st.last = os.clock()
    local b = readBytes(st.sites[1].a, 1, true)
    if b and b[1] == 0x89 then applyAll() elseif b and b[1] == 0xE9 then restoreAll() end
  end
end
t.Enabled = true
st.timer = t
applyAll()
-- 双轴移速：横向 20 (原5)，纵向 16 (原4)
local so = readInteger(0x4DD6BC)
local rb = readBytes(0x4DDAA0, 1, true)
local sp = so + rb[1] * 60
writeBytes(sp + 0x54, {20})
writeBytes(sp + 0x55, {16})
return 'deployed: world=' .. string.format('%X', WORLD) ..
       ' memo=' .. string.format('%X', MEMO) ..
       ' cave=' .. string.format('%X', cave) .. ' | F7=全屏攻击开关'
