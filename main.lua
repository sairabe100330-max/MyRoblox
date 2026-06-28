--[[
    🚀 สคริปต์หลักส่วนตัว
    แมพ: +1 Keyboard PRO
    ฟีเจอร์: ป้องกันวาปกลับ, ทะลุสิ่งกีดขวาง
]]

print("✅ กำลังโหลดระบบของคุณ...")

local Services = game:GetService("Players"), game:GetService("RunService"), game:GetService("CoreGui")
local LocalPlayer = Services.Players.LocalPlayer
local Character, Humanoid, RootPart, LastSafePos

-- โหลดตัวละครใหม่เมื่อเกิด
local function LoadCharacter()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid", 20)
    RootPart = Character:WaitForChild("HumanoidRootPart", 20)
    LastSafePos = RootPart.CFrame
end
LoadCharacter()
LocalPlayer.CharacterAdded:Connect(LoadCharacter)

-- ระบบทำงานหลัก
Services.RunService.Heartbeat:Connect(function()
    if not Character or not Humanoid or not RootPart then LoadCharacter() return end

    -- ทะลุสิ่งกีดขวาง
    pcall(function()
        for _, Part in ipairs(Character:GetDescendants()) do
            if Part:IsA("BasePart") then
                Part.CanCollide = false
                Part.CollisionGroupId = 0
            end
        end
    end)

    -- ป้องกันวาปกลับจุดเริ่ม
    local dist = (RootPart.Position - LastSafePos.Position).Magnitude
    if dist > 100 then
        RootPart.CFrame = LastSafePos
        RootPart.Velocity = Vector3.new(0,0,0)
    else
        LastSafePos = RootPart.CFrame
    end

    -- ปิดสถานะรีเซ็ต
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end)

-- แจ้งเตือน
pcall(function()
    local g = Instance.new("ScreenGui", Services.CoreGui)
    local t = Instance.new("TextLabel", g)
    t.Size = UDim2.new(0,220,0,40)
    t.Position = UDim2.new(0.73,0,0.1,0)
    t.BackgroundColor3 = Color3.new(0.1,0.6,0.1)
    t.Text = "✅ ระบบพร้อมใช้งาน"
    t.TextColor3 = Color3.new(1,1,1)
    t.Font = Enum.Font.GothamBold
    Instance.new("UICorner", t)
    task.delay(2.5, function() g:Destroy() end)
end)

print("✅ โหลดเสร็จเรียบร้อย!")
