--!strict
-- ClientHorrorController.lua (StarterPlayerScripts/Controllers)
-- Client-side horror feedback system for Fog Sea.
-- Handles dynamic screen effects based on sanity and provides hooks for jumpscares/hallucinations.
-- All effects are client-only. No server state is modified.

local Utils = require(game.ReplicatedStorage.Modules.Utils)
local RunService = Utils.GetService("RunService")
local Lighting = Utils.GetService("Lighting")

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
            colorCorrection.Saturation = -0.6 * insanity
            colorCorrection.Contrast = 0.3 * insanity
        end

        if depthOfField then
            depthOfField.FarIntensity = 0.8 * insanity
        end
    end))

    print("[ClientHorrorController] Initialized")
end

function ClientHorrorController:ApplyPulseEffect(intensity: number)
    if not colorCorrection then return end

    local original = colorCorrection.Brightness
    colorCorrection.Brightness = intensity * 0.4

    task.delay(0.2, function()
        if colorCorrection then
            colorCorrection.Brightness = original
        end
    end)
end

function ClientHorrorController:TriggerHallucination(type: number)
    -- Placeholder for future hallucination types
    print(`[ClientHorror] Hallucination triggered: Type {type}`)
end

function ClientHorrorController:TriggerJumpscare(intensity: number)
    if not colorCorrection then return end

    local original = colorCorrection.Brightness
    colorCorrection.Brightness = intensity * 0.8

    task.delay(0.15, function()
        if colorCorrection then
            colorCorrection.Brightness = original
        end
    end)
end

function ClientHorrorController.Destroy()
    maid:Cleanup()

    if colorCorrection then
        colorCorrection:Destroy()
        colorCorrection = nil
    end

    if depthOfField then
        depthOfField:Destroy()
        depthOfField = nil
    end
end

return ClientHorrorController