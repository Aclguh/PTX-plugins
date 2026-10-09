-- inclinometer_tool — 倾角与水平仪量角器
-- 利用三轴加速度传感器计算精准俯仰/横滚姿态角、综合倾角与工程坡度

local isHolding = false
local zeroPitch = 0.0
local zeroRoll = 0.0

local function myAtan2(y, x)
  if x > 0 then
    return math.atan(y / x)
  elseif x < 0 then
    if y >= 0 then
      return math.atan(y / x) + math.pi
    else
      return math.atan(y / x) - math.pi
    end
  else
    if y > 0 then
      return math.pi / 2.0
    elseif y < 0 then
      return -math.pi / 2.0
    else
      return 0.0
    end
  end
end

function _calcPitchRoll(x, y, z)
  local ax = x or 0.0
  local ay = y or 0.0
  local az = z or 9.8

  local rad2deg = 180.0 / math.pi
  local pitch = myAtan2(ay, math.sqrt(ax * ax + az * az)) * rad2deg
  local roll = myAtan2(-ax, az) * rad2deg

  local norm = math.sqrt(ax * ax + ay * ay + az * az)
  if norm < 0.001 then norm = 1.0 end
  local cosTilt = az / norm
  if cosTilt > 1.0 then cosTilt = 1.0 end
  if cosTilt < -1.0 then cosTilt = -1.0 end
  local tilt = math.acos(cosTilt) * rad2deg

  local grade = math.tan(tilt * math.pi / 180.0) * 100.0
  if grade > 999.0 then grade = 999.0 end

  return pitch, roll, tilt, grade
end

local function formatAngle(val)
  local sign = ""
  local v = val
  if v < 0 then
    sign = "-"
    v = -v
  end
  local round1 = math.floor(v * 10.0 + 0.5) / 10.0
  return sign .. tostring(round1) .. "°"
end

local function formatGrade(val)
  local round1 = math.floor(val * 10.0 + 0.5) / 10.0
  return tostring(round1) .. "%"
end

function measureOnce()
  if isHolding then return nil end

  local acc = sensor.getAccelerometer()
  if acc == nil then
    state.set("statusMsg", "未获取到加速度传感器数据")
    return nil
  end

  local p, r, tilt, grade = _calcPitchRoll(acc.x, acc.y, acc.z)
  p = p - zeroPitch
  r = r - zeroRoll

  state.set("pitchText", formatAngle(p))
  state.set("rollText", formatAngle(r))
  state.set("tiltText", formatAngle(tilt))
  state.set("gradeText", formatGrade(grade))

  if math.abs(p) <= 0.6 and math.abs(r) <= 0.6 then
    state.set("levelStatus", "★ 水平校准状态 (±0.6° 内)")
    haptic.light()
  else
    state.set("levelStatus", "倾斜中")
  end

  state.set("statusMsg", "当前加速度: X=" .. string.format("%.2f", acc.x) .. " Y=" .. string.format("%.2f", acc.y) .. " Z=" .. string.format("%.2f", acc.z))
  return nil
end

-- ---------------- UI 事件 ----------------
function onInit()
  isHolding = false
  zeroPitch = 0.0
  zeroRoll = 0.0

  state.set("pitchText", "0.0°")
  state.set("rollText", "0.0°")
  state.set("tiltText", "0.0°")
  state.set("gradeText", "0.0%")
  state.set("levelStatus", "就绪 (未测量)")
  state.set("holdBtnText", "锁定读数 (Hold)")
  state.set("statusMsg", "点击「刷新测量」或持续采样设备姿态")
  measureOnce()
  return nil
end

function toggleHold()
  isHolding = not isHolding
  if isHolding then
    state.set("holdBtnText", "解锁读数 (Resume)")
    dialog.toast("读数已锁定")
  else
    state.set("holdBtnText", "锁定读数 (Hold)")
    dialog.toast("已恢复实时测量")
    measureOnce()
  end
  return nil
end

function calibrateZero()
  local acc = sensor.getAccelerometer()
  if acc ~= nil then
    local p, r = _calcPitchRoll(acc.x, acc.y, acc.z)
    zeroPitch = p
    zeroRoll = r
    dialog.toast("已将当前姿态设为相对零位 (0°)")
    measureOnce()
  else
    dialog.toast("校准失败")
  end
  return nil
end

function resetCalibration()
  zeroPitch = 0.0
  zeroRoll = 0.0
  dialog.toast("已恢复绝对重力参考系")
  measureOnce()
  return nil
end

function copyReadings()
  local txt = "【倾角测量数据】\n综合倾角: " .. (state.get("tiltText") or "") ..
    "\n俯仰角(Pitch): " .. (state.get("pitchText") or "") ..
    "\n横滚角(Roll): " .. (state.get("rollText") or "") ..
    "\n工程坡度(Grade): " .. (state.get("gradeText") or "")
  clipboard.set(txt)
  dialog.toast("测量结果已复制")
  return nil
end
