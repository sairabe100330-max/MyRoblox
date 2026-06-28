--[[
    ชื่อ: สคริปต์ของนัด Ultimate
    อัปเดต: เพิ่มวงกลม FOV, ปรับระบบล็อกทะลุกำแพงตามสคริปต์ต้นฉบับ
]]

-- ป้องกันรันซ้ำ
local env = getgenv()
if env.ScriptOfNod_Loaded then return end
env.ScriptOfNod_Loaded = true

-- เรียกใช้บริการ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

-- ตัวแปรหลัก
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10) or game:GetService("CoreGui")

local Character, Humanoid, RootPart
local OriginalValues = {}
local Connections = {}
local ESP_Highlights = {}
local ScreenGui, MainFrame, NotifyFrame, FOV_Circle

-- ค่าความเร็วแอนิเมชัน
local TweenFast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenNormal = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenSlow = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- 🎨 ธีมสี
local Theme = {
    MainBG = Color3.fromRGB(12, 12, 12),
    SideBG = Color3.fromRGB(22, 8, 8),
    ContentBG = Color3.fromRGB(18, 12, 12),
    Header = Color3.fromRGB(170, 15, 15),
    HeaderGradient = Color3.fromRGB(255, 35, 35),
    Accent = Color3.fromRGB(255, 65, 65),
    ButtonNormal = Color3.fromRGB(45, 12, 12),
    ButtonHover = Color3.fromRGB(85, 18, 18),
    ButtonActive = Color3.fromRGB(200, 22, 22),
    ButtonDanger = Color3.fromRGB(255, 28, 28),
    SliderBG = Color3.fromRGB(38, 12, 12),
    SliderFill = Color3.fromRGB(255, 45, 45),
    TextLight = Color3.fromRGB(255, 255, 255),
    Border = Color3.fromRGB(75, 18, 18)
}

-- ⚙️ ค่าตั้งค่า — ปรับเพิ่มตามที่ขอ
local Settings = {
    Noclip = false,
    SpeedHack = false,
    MaxSpeed = 180,
    JumpPower = 600,
    AutoJump = false,
    Invisible = false,
    SelfTransparency = 0.35,
    ESP_Wall = false,
    ESP_Players = false,
    NoFall = false,
    NoDamage = false,
    Hotkey_Toggle = Enum.KeyCode.RightControl,

    -- 🔴 ระบบล็อกเป้า (ตรงตามโค้ดต้นฉบับ)
    Aim = {
        Enabled = false,
        AimPart = "Head",
        Smoothness = 0.32,
        Range = 1200,
        CheckVisible = false, -- ตรวจสอบว่าเห็นเป้าหมายไหม
        ThroughWall = false, -- ❌ เริ่มต้นไม่ล็อกทะลุ
        AutoFire = false,
        FOV = 120,
        ShowFOV = false, -- ✅ เปิด/ปิดวงกลม FOV
        TeamCheck = true
    }
}

-- 📢 ระบบแจ้งเตือน
local function CreateNotificationSystem()
    NotifyFrame = Instance.new("Frame")
    NotifyFrame.Size = UDim2.new(0, 280, 0, 50)
    NotifyFrame.Position = UDim2.new(1, -300, 0, 20)
    NotifyFrame.BackgroundColor3 = Theme.MainBG
    NotifyFrame.BorderColor3 = Theme.Accent
    NotifyFrame.BorderSizePixel = 2
    NotifyFrame.BackgroundTransparency = 1
    NotifyFrame.Visible = false
    NotifyFrame.Parent = ScreenGui
    Instance.new("UICorner", NotifyFrame).CornerRadius = UDim.new(0, 10)

    local NotifyText = Instance.new("TextLabel", NotifyFrame)
    NotifyText.Size = UDim2.new(1, -20, 1, 0)
    NotifyText.Position = UDim2.new(0, 10, 0, 0)
    NotifyText.Font = Enum.Font.GothamBold
    NotifyText.TextSize = 14
    NotifyText.TextColor3 = Theme.TextLight
    NotifyText.BackgroundTransparency = 1
    NotifyText.TextXAlignment = Enum.TextXAlignment.Left

    return function(text, duration)
        duration = duration or 2
        NotifyText.Text = "📢 " .. text
        NotifyFrame.Visible = true
        NotifyFrame.BackgroundTransparency = 1
        TweenService:Create(NotifyFrame, TweenNormal, {BackgroundTransparency = 0, Position = UDim2.new(1, -300, 0, 20)}):Play()
        task.wait(duration)
        TweenService:Create(NotifyFrame, TweenNormal, {BackgroundTransparency = 1, Position = UDim2.new(1, -260, 0, 20)}):Play()
        task.wait(0.25)
        NotifyFrame.Visible = false
    end
end
local ShowNotify = nil

-- 🛠️ บันทึก/คืนค่าเดิม
local function SaveOriginalValues()
    OriginalValues.WalkSpeed = 16
    OriginalValues.JumpPower = 50
    OriginalValues.FogEnd = Lighting.FogEnd
    OriginalValues.FogStart = Lighting.FogStart
    OriginalValues.FogColor = Lighting.FogColor
    OriginalValues.GlobalShadows = Lighting.GlobalShadows
    OriginalValues.Ambient = Lighting.Ambient
    OriginalValues.Brightness = Lighting.Brightness
    OriginalValues.OutdoorAmbient = Lighting.OutdoorAmbient
end

local function ResetAllAndClean()
    for _, conn in ipairs(Connections) do
        if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
    end
    Connections = {}

    if Character and Humanoid then
        Humanoid.WalkSpeed = OriginalValues.WalkSpeed
        Humanoid.JumpPower = OriginalValues.JumpPower
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)

        for _, v in ipairs(Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = true
                v.Transparency = 0
                v.LocalTransparencyModifier = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 0
                v.LocalTransparencyModifier = 0
            end
        end
    end

    Lighting.FogEnd = OriginalValues.FogEnd
    Lighting.FogStart = OriginalValues.FogStart
    Lighting.FogColor = OriginalValues.FogColor
    Lighting.GlobalShadows = OriginalValues.GlobalShadows
    Lighting.Ambient = OriginalValues.Ambient
    Lighting.Brightness = OriginalValues.Brightness
    Lighting.OutdoorAmbient = OriginalValues.OutdoorAmbient

    for _, hl in pairs(ESP_Highlights) do if hl then hl:Destroy() end end
    ESP_Highlights = {}

    if FOV_Circle then FOV_Circle.Visible = false end
    if ScreenGui then ScreenGui:Destroy() end
end

-- อัปเดตตัวละคร
local function RefreshCharacter()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid", 10)
    RootPart = Character:WaitForChild("HumanoidRootPart", 10)
    SaveOriginalValues()
end
RefreshCharacter()
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(RefreshCharacter))

-- 🎯 ตรวจสอบว่ามองเห็นเป้าหมายไหม (ตามโค้ดต้นฉบับ)
local function IsVisible(From, To)
    local Ray = Ray.new(From, (To - From).Unit * (To - From).Magnitude)
    local Hit = Workspace:FindPartOnRayWithIgnoreList(Ray, {Character, Camera, Workspace.Terrain})
    return not Hit or Hit:IsDescendantOf(To.Parent)
end

-- 🎯 หาเป้าหมายที่ใกล้ที่สุด
local function GetBestTarget()
    local BestTarget, BestDistance = nil, Settings.Aim.Range
    local CamPos = Camera.CFrame.Position
    local CamDir = Camera.CFrame.LookVector

    for _, Plr in ipairs(Players:GetPlayers()) do
        if Plr == LocalPlayer then continue end
        if Settings.Aim.TeamCheck and Plr.Team == LocalPlayer.Team then continue end

        local Char = Plr.Character
        if not Char then continue end
        local Human = Char:FindFirstChildOfClass("Humanoid")
        if not Human or Human.Health <= 0 then continue end

        local TargetPart = Char:FindFirstChild(Settings.Aim.AimPart) or Char:FindFirstChild("Head") or Char:FindFirstChild("HumanoidRootPart")
        if not TargetPart then continue end

        local Dist = (CamPos - TargetPart.Position).Magnitude
        if Dist > BestDistance then continue end

        local Dir = (TargetPart.Position - CamPos).Unit
        local Angle = math.deg(math.acos(math.clamp(CamDir:Dot(Dir), -1, 1)))
        if Angle > Settings.Aim.FOV / 2 then continue end

        -- ตรวจสอบทะลุกำแพงตามค่าที่ตั้งไว้
        if not Settings.Aim.ThroughWall and not IsVisible(CamPos, TargetPart.Position) then continue end

        BestDistance = Dist
        BestTarget = TargetPart
    end

    return BestTarget
end

-- 🎨 สร้างวงกลมแสดงขอบเขต FOV
local function CreateFOVCircle()
    FOV_Circle = Instance.new("Frame")
    FOV_Circle.Size = UDim2.new(0, 200, 0, 200)
    FOV_Circle.Position = UDim2.new(0.5, -100, 0.5, -100)
    FOV_Circle.BackgroundTransparency = 1
    FOV_Circle.BorderSizePixel = 2
    FOV_Circle.BorderColor3 = Theme.Accent
    FOV_Circle.Visible = false
    FOV_Circle.Parent = ScreenGui
    Instance.new("UICorner", FOV_Circle).CornerRadius = UDim.new(1, 0)
end

-- 🎛️ สร้างแถบเลื่อน
local function CreateSlider(parent, name, minVal, maxVal, defaultVal, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, 0, 0, 62)
    SliderFrame.BackgroundColor3 = Theme.ContentBG
    SliderFrame.BorderColor3 = Theme.Border
    SliderFrame.BorderSizePixel = 1
    SliderFrame.BackgroundTransparency = 1
    SliderFrame.Position = UDim2.new(0, 0, 0, 10)
    SliderFrame.Parent = parent
    Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 9)

    TweenService:Create(SliderFrame, TweenNormal, {BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}):Play()

    local Title = Instance.new("TextLabel", SliderFrame)
    Title.Size = UDim2.new(1, -10, 0, 26)
    Title.Position = UDim2.new(0, 10, 0, 5)
    Title.Text = string.format("%s : %d", name, defaultVal)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.TextColor3 = Theme.Accent
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local BarBG = Instance.new("Frame", SliderFrame)
    BarBG.Size = UDim2.new(1, -22, 0, 12)
    BarBG.Position = UDim2.new(0, 10, 0, 38)
    BarBG.BackgroundColor3 = Theme.SliderBG
    BarBG.BorderSizePixel = 0
    Instance.new("UICorner", BarBG).CornerRadius = UDim.new(0, 6)

    local BarFill = Instance.new("Frame", BarBG)
    BarFill.Size = UDim2.new(0, 0, 1, 0)
    BarFill.BackgroundColor3 = Theme.SliderFill
    BarFill.BorderSizePixel = 0
    Instance.new("UICorner", BarFill).CornerRadius = UDim.new(0, 6)
    task.wait(0.05)
    TweenService:Create(BarFill, TweenNormal, {Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)}):Play()

    local DragBtn = Instance.new("TextButton", BarFill)
    DragBtn.Size = UDim2.new(0, 20, 0, 20)
    DragBtn.Position = UDim2.new(1, -10, 0.5, -10)
    DragBtn.BackgroundColor3 = Theme.TextLight
    DragBtn.BorderColor3 = Theme.SliderFill
    DragBtn.BorderSizePixel = 2
    DragBtn.Text = ""
    DragBtn.AutoButtonColor = false
    DragBtn.BackgroundTransparency = 1
    Instance.new("UICorner", DragBtn).CornerRadius = UDim.new(1, 0)
    task.wait(0.1)
    TweenService:Create(DragBtn, TweenNormal, {BackgroundTransparency = 0}):Play()

    local isDrag = false
    table.insert(Connections, DragBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            isDrag = true
            TweenService:Create(DragBtn, TweenFast, {Size = UDim2.new(0, 24, 0, 24), BackgroundColor3 = Theme.Accent}):Play()
        end
    end))
    table.insert(Connections, DragBtn.InputEnded:Connect(function()
        isDrag = false
        TweenService:Create(DragBtn, TweenFast, {Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = Theme.TextLight}):Play()
    end))
    table.insert(Connections, UserInputService.InputChanged:Connect(function(i)
        if isDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local pos = BarBG.AbsolutePosition.X
            local w = BarBG.AbsoluteSize.X
            local newX = math.clamp(i.Position.X - pos, 0, w)
            local percent = newX / w
            TweenService:Create(BarFill, TweenFast, {Size = UDim2.new(percent, 0, 1, 0)}):Play()
            local val = math.floor(minVal + percent * (maxVal - minVal))
            Title.Text = string.format("%s : %d", name, val)
            callback(val)
        end
    end))

    return SliderFrame
end

-- 🔘 สร้างปุ่ม
local function MakeButton(parent, text, active, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 46)
    btn.BackgroundColor3 = active and Theme.ButtonActive or Theme.ButtonNormal
    btn.BorderColor3 = Theme.Border
    btn.BorderSizePixel = 1
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.TextColor3 = Theme.TextLight
    btn.AutoButtonColor = false
    btn.BackgroundTransparency = 1
    btn.Position = UDim2.new(0, 0, 0, 10)
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)

    TweenService:Create(btn, TweenNormal, {BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}):Play()

    table.insert(Connections, btn.MouseEnter:Connect(function()
        if not active then
            TweenService:Create(btn, TweenFast, {BackgroundColor3 = Theme.ButtonHover, Size = UDim2.new(0.98, 0, 0, 44)}):Play()
        end
    end))
    table.insert(Connections, btn.MouseLeave:Connect(function()
        if not active then
            TweenService:Create(btn, TweenFast, {BackgroundColor3 = Theme.ButtonNormal, Size = UDim2.new(1, 0, 0, 46)}):Play()
        end
    end))
    table.insert(Connections, btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenFast, {Size = UDim2.new(0.94, 0, 0, 42)}):Play()
    end))
    table.insert(Connections, btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenFast, {Size = UDim2.new(1, 0, 0, 46)}):Play()
        callback(btn)
    end))

    return btn
end

-- 🖼️ สร้างเมนูหลัก
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Menu_Nod_Animated"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- สร้างวงกลม FOV
CreateFOVCircle()

MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 560, 0, 460)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -230)
MainFrame.BackgroundColor3 = Theme.MainBG
MainFrame.BorderColor3 = Theme.Border
MainFrame.BorderSizePixel = 2
MainFrame.Active = true
MainFrame.Selectable = true
MainFrame.Draggable = true
MainFrame.BackgroundTransparency = 0
MainFrame.Visible = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

-- แถบหัว
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, 56)
TitleBar.BackgroundColor3 = Theme.Header
TitleBar.BackgroundTransparency = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 16)
local Gradient = Instance.new("UIGradient", TitleBar)
Gradient.Color = ColorSequence.new(Theme.Header, Theme.HeaderGradient)
Gradient.Rotation = 90

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(1, -110, 1, 0)
Title.Position = UDim2.new(0, 20, 0, 0)
Title.Text = "📌 สคริปต์ของนัด"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 20
Title.TextColor3 = Theme.Accent
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size = UDim2.new(0, 36, 0, 36)
MinBtn.Position = UDim2.new(1, -76, 0.5, -18)
MinBtn.Text = "➖"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 17
MinBtn.TextColor3 = Theme.TextLight
MinBtn.BackgroundColor3 = Theme.ButtonNormal
MinBtn.BorderSizePixel = 0
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(1, 0)

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size = UDim2.new(0, 36, 0, 36)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -18)
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 17
CloseBtn.TextColor3 = Theme.TextLight
CloseBtn.BackgroundColor3 = Theme.ButtonDanger
CloseBtn.BorderSizePixel = 0
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

-- แผงซ้าย
local LeftPanel = Instance.new("ScrollingFrame", MainFrame)
LeftPanel.Size = UDim2.new(0.34, -8, 1, -62)
LeftPanel.Position = UDim2.new(0, 10, 0, 58)
LeftPanel.BackgroundColor3 = Theme.SideBG
LeftPanel.BorderSizePixel = 0
LeftPanel.ScrollBarThickness = 7
LeftPanel.ScrollBarImageColor3 = Theme.Accent
LeftPanel.CanvasSize = UDim2.new(0, 0, 0, 450)
Instance.new("UICorner", LeftPanel).CornerRadius = UDim.new(0, 10)

local MenuLayout = Instance.new("UIListLayout", LeftPanel)
MenuLayout.Padding = UDim.new(0, 10)
MenuLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- เส้นแบ่ง
local Divider = Instance.new("Frame", MainFrame)
Divider.Size = UDim2.new(0, 2, 1, -66)
Divider.Position = UDim2.new(0.35, 0, 0, 60)
Divider.BackgroundColor3 = Theme.Border
Divider.BorderSizePixel = 0

-- แผงขวา
local RightPanel = Instance.new("Frame", MainFrame)
RightPanel.Size = UDim2.new(0.64, 0, 1, -62)
RightPanel.Position = UDim2.new(0.36, 8, 0, 58)
RightPanel.BackgroundColor3 = Theme.ContentBG
RightPanel.BorderSizePixel = 0
Instance.new("UICorner", RightPanel).CornerRadius = UDim.new(0, 10)

local ContentFrame = Instance.new("ScrollingFrame", RightPanel)
ContentFrame.Size = UDim2.new(1, -14, 1, -14)
ContentFrame.Position = UDim2.new(0, 7, 0, 7)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ScrollBarThickness = 6
ContentFrame.ScrollBarImageColor3 = Theme.Accent
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 900)

local ContentLayout = Instance.new("UIListLayout", ContentFrame)
ContentLayout.Padding = UDim.new(0, 12)

-- 📋 ระบบเมนู
local SelectedTab = nil
local function AddTab(name, func)
    local btn = Instance.new("TextButton", LeftPanel)
    btn.Size = UDim2.new(1, -10, 0, 44)
    btn.BackgroundColor3 = Theme.ButtonNormal
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Theme.TextLight
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseEnter:Connect(function()
        if btn ~= SelectedTab then
            TweenService:Create(btn, TweenFast, {BackgroundColor3 = Theme.ButtonHover, Size = UDim2.new(0.96, 0, 0, 42)}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if btn ~= SelectedTab then
            TweenService:Create(btn, TweenFast, {BackgroundColor3 = Theme.ButtonNormal, Size = UDim2.new(1, 0, 0, 44)}):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if SelectedTab then
            TweenService:Create(SelectedTab, TweenNormal, {BackgroundColor3 = Theme.ButtonNormal, Size = UDim2.new(1, 0, 0, 44)}):Play()
        end
        SelectedTab = btn
        TweenService:Create(SelectedTab, TweenNormal, {BackgroundColor3 = Theme.Header, Size = UDim2.new(1, 0, 0, 46)}):Play()
        for _, v in ipairs(ContentFrame:GetChildren()) do
            if v:IsA("GuiObject") then
                TweenService:Create(v, TweenFast, {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 10)}):Play()
                task.wait(0.1)
                v:Destroy()
            end
        end
        task.wait(0.15)
        func()
    end)

    return btn
end

-- 📝 เมนูเคลื่อนไหว
AddTab("🏃 เคลื่อนไหว", function()
    local Title = Instance.new("TextLabel", ContentFrame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "⚙️ ตั้งค่าการเคลื่อนไหว"
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 17
    Title.TextColor3 = Theme.Accent
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Center
    TweenService:Create(Title, TweenNormal, {TextTransparency = 0}):Play()

    MakeButton(ContentFrame, Settings.Noclip and "✅ ปิดทะลุกำแพง" or "🔘 เปิดทะลุกำแพง", Settings.Noclip, function(btn)
        Settings.Noclip = not Settings.Noclip
        btn.Text = Settings.Noclip and "✅ ปิดทะลุกำแพง" or "🔘 เปิดทะลุกำแพง"
        btn.BackgroundColor3 = Settings.Noclip and Theme.ButtonActive or Theme.ButtonNormal
        ShowNotify(Settings.Noclip and "เปิดทะลุกำแพงแล้ว" or "ปิดทะลุกำแพงแล้ว")
    end)

    MakeButton(ContentFrame, Settings.SpeedHack and "✅ ปิดวิ่งเร็ว" or "🔘 เปิดวิ่งเร็ว", Settings.SpeedHack, function(btn)
        Settings.SpeedHack = not Settings.SpeedHack
        Humanoid.WalkSpeed = Settings.SpeedHack and Settings.MaxSpeed or OriginalValues.WalkSpeed
        btn.Text = Settings.SpeedHack and "✅ ปิดวิ่งเร็ว" or "🔘 เปิดวิ่งเร็ว"
        btn.BackgroundColor3 = Settings.SpeedHack and Theme.ButtonActive or Theme.ButtonNormal
        ShowNotify(Settings.SpeedHack and "เปิดวิ่งเร็วแล้ว" or "ปิดวิ่งเร็วแล้ว")
    end)

    MakeButton(ContentFrame, Settings.AutoJump and "✅ ปิดกระโดดอัตโนมัติ" or "🔘 เปิดกระโดดอัตโนมัติ", Settings.AutoJump, function(btn)
        Settings.AutoJump = not Settings.AutoJump
        btn.Text = Settings.AutoJump and "✅ ปิดกระโดดอัตโนมัติ" or "🔘 เปิดกระโดดอัตโนมัติ"
        btn.BackgroundColor3 = Settings.AutoJump and Theme.ButtonActive or Theme.ButtonNormal
        ShowNotify(Settings.AutoJump and "เปิดกระโดดอัตโนมัติ" or "ปิดกระโดดอัตโนมัติ")
    end)

    CreateSlider(ContentFrame, "ความเร็ววิ่ง", 16, 300, Settings.MaxSpeed, function(v)
        Settings.MaxSpeed = v
        if Settings.SpeedHack then Humanoid.WalkSpeed = v end
    end)
    CreateSlider(ContentFrame, "พลังกระโดดสูง", 50, 1200, Settings.JumpPower, function(v)
        Settings.JumpPower = v
        Humanoid.JumpPower = v
    end)
end)

-- 📝 เมนูหายตัว
AddTab("🕶️ หายตัว", function()
    local Title = Instance.new("TextLabel", ContentFrame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "⚙️ ควบคุมการมองเห็น"
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 17
    Title.TextColor3 = Theme.Accent
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Center
    TweenService:Create(Title, TweenNormal, {TextTransparency = 0}):Play()

    MakeButton(ContentFrame, Settings.Invisible and "✅ มองเห็นปกติ" or "🔘 ทำตัวล่องหน", Settings.Invisible, function(btn)
        Settings.Invisible = not Settings.Invisible
        if Settings.Invisible then
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
                    part.Transparency = 1
                    part.LocalTransparencyModifier = Settings.SelfTransparency
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
            ShowNotify("เปิดล่องหนแล้ว")
        else
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
                    part.Transparency = 0
                    part.LocalTransparencyModifier = 0
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
            ShowNotify("ปิดล่องหนแล้ว")
        end
        btn.Text = Settings.Invisible and "✅ มองเห็นปกติ" or "🔘 ทำตัวล่องหน"
        btn.BackgroundColor3 = Settings.Invisible and Theme.ButtonActive or Theme.ButtonNormal
    end)

    CreateSlider(ContentFrame, "ความจางของตัวเอง", 0, 80, math.floor(Settings.SelfTransparency * 100), function(v)
        Settings.SelfTransparency = v / 100
        if Settings.Invisible then
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
                    part.LocalTransparencyModifier = Settings.SelfTransparency
                end
            end
        end
    end)
end)

-- 📝 เมนูมองทะลุ
AddTab("👁️ มองทะลุ", function()
    local Title = Instance.new("TextLabel", ContentFrame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "⚙️ ตั้งค่าการมองเห็น"
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 17
    Title.TextColor3 = Theme.Accent
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Center
    TweenService:Create(Title, TweenNormal, {TextTransparency = 0}):Play()

    MakeButton(ContentFrame, Settings.ESP_Wall and "✅ ปิดมองทะลุ" or "🔘 เปิดมองทะลุ", Settings.ESP_Wall, function(btn)
        Settings.ESP_Wall = not Settings.ESP_Wall
        if Settings.ESP_Wall then
            Lighting.FogEnd = 100000
            Lighting.FogStart = 0
            Lighting.FogColor = Color3.new(1, 1, 1)
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.new(1, 1, 1)
            Lighting.Brightness = 3
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
            ShowNotify("เปิดมองทะลุแล้ว")
        else
            Lighting.FogEnd = OriginalValues.FogEnd
            Lighting.FogStart = OriginalValues.FogStart
            Lighting.FogColor = OriginalValues.FogColor
            Lighting.GlobalShadows = OriginalValues.GlobalShadows
            Lighting.Ambient = OriginalValues.Ambient
            Lighting.Brightness = OriginalValues.Brightness
            Lighting.OutdoorAmbient = OriginalValues.OutdoorAmbient
            ShowNotify("ปิดมองทะลุแล้ว")
        end
        btn.Text = Settings.ESP_Wall and "✅ ปิดมองทะลุ" or "🔘 เปิดมองทะลุ"
        btn.BackgroundColor3 = Settings.ESP_Wall and Theme.ButtonActive or Theme.ButtonNormal
    end)

    MakeButton(ContentFrame, Settings.ESP_Players and "✅ ปิดไฮไลท์ศัตรู" or "🔘 เปิดไฮไลท์ศัตรู", Settings.ESP_Players, function(btn)
        Settings.ESP_Players = not Settings.ESP_Players
        if not Settings.ESP_Players then
            for _, hl in pairs(ESP_Highlights) do if hl then hl:Destroy() end end
            ESP_Highlights = {}
            ShowNotify("ปิดไฮไลท์ศัตรูแล้ว")
        else
            ShowNotify("เปิดไฮไลท์ศัตรูแล้ว")
        end
        btn.Text = Settings.ESP_Players and "✅ ปิดไฮไลท์ศัตรู" or "🔘 เปิดไฮไลท์ศัตรู"
        btn.BackgroundColor3 = Settings.ESP_Players and Theme.ButtonActive or Theme.ButtonNormal
    end)
end)

-- 📝 เมนูล็อกเป้า — อัปเดตตามที่ขอ
AddTab("🎯 ล็อกเป้า", function()
    local Title = Instance.new("TextLabel", ContentFrame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "⚙️ ระบบล็อกเป้าหมาย"
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 17
    Title.TextColor3 = Theme.Accent
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Center
    TweenService:Create(Title, TweenNormal, {TextTransparency = 0}):Play()

    MakeButton(ContentFrame, Settings.Aim.Enabled and "✅ ปิดระบบล็อกเป้า" or "🔘 เปิดระบบล็อกเป้า", Settings.Aim.Enabled, function(btn)
        Settings.Aim.Enabled = not Settings.Aim.Enabled
        btn.Text = Settings.Aim.Enabled and "✅ ปิดระบบล็อกเป้า" or "🔘 เปิดระบบล็อกเป้า"
        btn.BackgroundColor3 = Settings.Aim.Enabled and Theme.ButtonActive or Theme.ButtonNormal
        ShowNotify(Settings.Aim.Enabled and "เปิดล็อกเป้าแล้ว" or "ปิดล็อกเป้าแล้ว")
    end)

    -- ✅ ปุ่มล็อกทะลุ/ไม่ทะลุ
    MakeButton(ContentFrame, Settings.Aim.ThroughWall and "✅ ล็อกหลังกำแพง" or "🔘 ไม่ล็อกหลังกำแพง", Settings.Aim.ThroughWall, function(btn)
        Settings.Aim.ThroughWall = not Settings.Aim.ThroughWall
        btn.Text = Settings.Aim.ThroughWall and "✅ ล็อกหลังกำแพง" or "🔘 ไม่ล็อกหลังกำแพง"
        btn.BackgroundColor3 = Settings.Aim.ThroughWall and Theme.ButtonActive or Theme.ButtonNormal
        ShowNotify(Settings.Aim.ThroughWall and "เปิดล็อกทะลุกำแพง" or "ปิดล็อกทะลุกำแพง")
    end)

    -- ✅ ปุ่มเปิด/ปิดวงกลม FOV
    MakeButton(ContentFrame, Settings.Aim.ShowFOV and "✅ ซ่อนวงกลม FOV" or "🔘 แสดงวงกลม FOV", Settings.Aim.ShowFOV, function(btn)
        Settings.Aim.ShowFOV = not Settings.Aim.ShowFOV
        FOV_Circle.Visible = Settings.Aim.ShowFOV
        btn.Text = Settings.Aim.ShowFOV and "✅ ซ่อนวงกลม FOV" or "🔘 แสดงวงกลม FOV"
        btn.BackgroundColor3 = Settings.Aim.ShowFOV and Theme.ButtonActive or Theme.ButtonNormal
        ShowNotify(Settings.Aim.ShowFOV and "แสดงขอบเขต FOV" or "ซ่อนขอบเขต FOV")
    end)

    MakeButton(ContentFrame, "🎯 เป้า: หัว", false, function()
        Settings.Aim.AimPart = "Head"
        ShowNotify("เปลี่ยนจุดล็อกเป็นหัว")
    end)
    MakeButton(ContentFrame, "🎯 เป้า: ลำตัว", false, function()
        Settings.Aim.AimPart = "HumanoidRootPart"
        ShowNotify("เปลี่ยนจุดล็อกเป็นลำตัว")
    end)

    MakeButton(ContentFrame, Settings.Aim.AutoFire and "✅ ยิงอัตโนมัติ" or "🔘 ยิงเอง", Settings.Aim.AutoFire, function(btn)
        Settings.Aim.AutoFire = not Settings.Aim.AutoFire
        btn.Text = Settings.Aim.AutoFire and "✅ ยิงอัตโนมัติ" or "🔘 ยิงเอง"
        btn.BackgroundColor3 = Settings.Aim.AutoFire and Theme.ButtonActive or Theme.ButtonNormal
    end)

    CreateSlider(ContentFrame, "ระยะล็อก", 100, 2000, Settings.Aim.Range, function(v) Settings.Aim.Range = v end)
    CreateSlider(ContentFrame, "มุมมอง FOV", 30, 180, Settings.Aim.FOV, function(v)
        Settings.Aim.FOV = v
        -- ปรับขนาดวงกลม FOV
        local Size = math.clamp(200 * (v / 120), 100, 300)
        FOV_Circle.Size = UDim2.new(0, Size, 0, Size)
        FOV_Circle.Position = UDim2.new(0.5, -Size/2, 0.5, -Size/2)
    end)
    CreateSlider(ContentFrame, "ความนุ่มนวล", 10, 90, math.floor(Settings.Aim.Smoothness * 100), function(v) Settings.Aim.Smoothness = v / 100 end)
end)

-- 📝 เมนูตั้งค่า
AddTab("⚙️ ตั้งค่า", function()
    local Title = Instance.new("TextLabel", ContentFrame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "🔧 ปรับแต่งระบบ"
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 17
    Title.TextColor3 = Theme.Accent
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Center
    TweenService:Create(Title, TweenNormal, {TextTransparency = 0}):Play()

    MakeButton(ContentFrame, "🔴 ธีมแดง-ดำ", false, function()
        Theme.Accent = Color3.fromRGB(255, 65, 65)
        Theme.Header = Color3.fromRGB(170, 15, 15)
        Theme.HeaderGradient = Color3.fromRGB(255, 35, 35)
        Theme.SliderFill = Color3.fromRGB(255, 45, 45)
        FOV_Circle.BorderColor3 = Theme.Accent
        ShowNotify("เปลี่ยนเป็นธีมแดง-ดำแล้ว")
    end)

    MakeButton(ContentFrame, "🔵 ธีมน้ำเงิน-ดำ", false, function()
        Theme.Accent = Color3.fromRGB(65, 120, 255)
        Theme.Header = Color3.fromRGB(15, 40, 170)
        Theme.HeaderGradient = Color3.fromRGB(35, 70, 255)
        Theme.SliderFill = Color3.fromRGB(45, 90, 255)
        FOV_Circle.BorderColor3 = Theme.Accent
        ShowNotify("เปลี่ยนเป็นธีมน้ำเงิน-ดำแล้ว")
    end)

    MakeButton(ContentFrame, "❌ ปิดและล้างทั้งหมด", false, function()
        ResetAllAndClean()
        ShowNotify("ปิดสคริปต์เรียบร้อย")
    end)
end)

-- 📢 เริ่มระบบแจ้งเตือน
ShowNotify = CreateNotificationSystem()

-- ⌨️ ปุ่มลัด
table.insert(Connections, UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Settings.Hotkey_Toggle then
        MainFrame.Visible = not MainFrame.Visible
        ShowNotify(MainFrame.Visible and "แสดงเมนู" or "ซ่อนเมนู")
    end
end))

-- 🔁 ลูปทำงานหลัก
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not Character or not Humanoid or not RootPart then RefreshCharacter() return end

    -- ทะลุกำแพง
    if Settings.Noclip then
        for _, v in ipairs(Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end

    -- กระโดดอัตโนมัติ
    if Settings.AutoJump and Humanoid.FloorMaterial ~= Enum.Material.Air then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    -- ไม่เจ็บตก
    if Settings.NoFall then
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    else
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
    end

    -- ไม่เจ็บ
    if Settings.NoDamage and Humanoid.Health < Humanoid.MaxHealth then
        Humanoid.Health = Humanoid.MaxHealth
    end

    -- ไฮไลท์ศัตรู
    if Settings.ESP_Players then
        for _, Plr in ipairs(Players:GetPlayers()) do
            if Plr ~= LocalPlayer and Plr.Character and Plr.Character:FindFirstChild("Humanoid") and Plr.Character.Humanoid.Health > 0 then
                local Char = Plr.Character
                if not ESP_Highlights[Char] then
                    local HL = Instance.new("Highlight", Char)
                    HL.Adornee = Char
                    HL.FillColor = Theme.Accent
                    HL.FillTransparency = 0.6
                    HL.OutlineColor = Color3.new(1, 1, 1)
                    HL.OutlineTransparency = 0.1
                    HL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    ESP_Highlights[Char] = HL
                end
            else
                if ESP_Highlights[Plr.Character] then
                    ESP_Highlights[Plr.Character]:Destroy()
                    ESP_Highlights[Plr.Character] = nil
                end
            end
        end
    end

    -- 🎯 ระบบล็อกเป้า (ตรงตามโค้ดต้นฉบับ)
    if Settings.Aim.Enabled then
        local Target = GetBestTarget()
        if Target then
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, Target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, Settings.Aim.Smoothness)

            -- ยิงอัตโนมัติ
            if Settings.Aim.AutoFire and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                -- ปล่อยให้เกมจัดการการยิงเองตามโค้ดต้นฉบับ
            end
        end
    end
end))

-- ปุ่มย่อเมนู
MinBtn.MouseButton1Click:Connect(function()
    local IsMin = MainFrame.Size.Y.Offset < 100
    if IsMin then
        TweenService:Create(MainFrame, TweenNormal, {Size = UDim2.new(0, 560, 0, 460)}):Play()
        LeftPanel.Visible = true
        Divider.Visible = true
        RightPanel.Visible = true
        MinBtn.Text = "➖"
    else
        LeftPanel.Visible = false
        Divider.Visible = false
        RightPanel.Visible = false
        TweenService:Create(MainFrame, TweenNormal, {Size = UDim2.new(0, 560, 0, 58)}):Play()
        MinBtn.Text = "➕"
    end
end)

-- ปุ่มปิดเมนู
CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenSlow, {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
    task.wait(0.45)
    ResetAllAndClean()
end)

-- แจ้งเตือนเริ่มต้น
task.wait(0.5)
ShowNotify("✅ สคริปต์ของนัด โหลดเสร็จแล้ว! กด Ctrl ขวา เปิด/ปิดเมนู")
