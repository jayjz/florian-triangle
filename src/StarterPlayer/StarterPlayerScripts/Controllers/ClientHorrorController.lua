--!strict
-- ClientHorrorController.lua (StarterPlayerScripts/Controllers)
-- Advanced client-side horror feedback with screen effects, jumpscares, and hallucinations.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")
local SoundService = Utils.GetService("SoundService")

local ClientHorrorController = {}
local maid = Utils.CreateMaid()

local Remotes = {
    SanityChanged = Utils.CreateRemoteEvent("SanityChanged"),
    HorrorPulse = Utils.CreateRemoteEvent("HorrorPulse"),
    HallucinationTriggered = Utils.CreateRemoteEvent("HallucinationTriggered"),
}

local currentSanity = 100
local colorCorrection: ColorCorrectionEffect?
local depthOfField: DepthOfFieldEffect?
local lastJumpscare = 0

function ClientHorrorController.Initialize()
    colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Parent = Lighting

    depthOfField = Instance.new("DepthOfFieldEffect")
    depthOfField.Parent = Lighting

    Remotes.SanityChanged.OnClientEvent:Connect(function(level: number)
        currentSanity = level
    end)

    Remotes.HorrorPulse.OnClientEvent:Connect(function(intensity: number)
        ClientHorrorController:ApplyPulseEffect(intensity)
    end)

    Remotes.HallucinationTriggered.OnClientEvent:Connect(function(type: number)
        ClientHorrorController:TriggerHallucination(type)
    end)

    maid:GiveTask(RunService.RenderStepped:Connect(function()
        local insanity = (100 - currentSanity) / 100
        if colorCorrection then
            colorCorrection.Saturation = -0.65 * insanity
            colorCorrection.Contrast = 0.35 * insanity
        end
        if depthOfField then
            depthOfField.FarIntensity = 0.85 * insanity
        end
    end))

    print("[ClientHorrorController] Initialized - Full horror feedback active")
end

function ClientHorrorController:ApplyPulseEffect(intensity: number)
    if not colorCorrection then return end
    local original = colorCorrection.Brightness
    colorCorrection.Brightness = intensity * 0.5
    task.delay(0.18, function()
        if colorCorrection then colorCorrection.Brightness = original end
    end)
end

function ClientHorrorController:TriggerHallucination(type: number)
    print(`[ClientHorror] Hallucination Type {type} triggered`)
    -- Future: Spawn fake entity visuals, distort audio, etc.
end

function ClientHorrorController:TriggerJumpscare(intensity: number)
    if tick() - lastJumpscare < 8 then return end
    lastJumpscare = tick()

    if colorCorrection then
        colorCorrection.Brightness = intensity * 0.9
        task.delay(0.12, function()
            if colorCorrection then colorCorrection.Brightness = 0 end
        end)
    end
    -- Add camera shake and sound here in future iterations
end

function ClientHorrorController.Destroy()
    maid:Cleanup()
    if colorCorrection then colorCorrection:Destroy() end
    if depthOfField then depthOfField:Destroy() end
end

return ClientHorrorController