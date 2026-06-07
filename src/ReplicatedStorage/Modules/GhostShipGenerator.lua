--!strict
-- GhostShipGenerator.lua (ReplicatedStorage/Modules)
-- Production server-authoritative ghost ship spawner for Fog Sea.
-- Uses real GhostShipRig from ServerStorage.Assets. Mobile-optimized with network ownership.

local Utils = require(script.Parent.Utils)
local CollectionService = Utils.GetService("CollectionService")
local RunService = Utils.GetService("RunService")
local ServerStorage = Utils.GetService("ServerStorage")

local GhostShipGenerator = {}
GhostShipGenerator.__index = GhostShipGenerator

export type GhostShip = {
    Model: Model,
    Difficulty: number,
    LastSpawnTime: number,
}

local activeShips: {GhostShip} = {}
local globalMaid = Utils.CreateMaid()

local CONFIG = {
    MaxShips = 5,
    SpawnDistance = 180,
    CullDistance = 420,
    SpawnChancePerTick = 0.035, -- ~every 28 seconds on average
}

local ghostShipTemplate: Model? = nil

local function getGhostShipTemplate(): Model?
    if not ghostShipTemplate then
        local assets = ServerStorage:FindFirstChild("Assets")
        ghostShipTemplate = assets and assets:FindFirstChild("GhostShipRig")

        if not ghostShipTemplate then
            warn("[GhostShipGenerator] GhostShipRig not found in ServerStorage.Assets — using fallback")
        end
    end
    return ghostShipTemplate
end

function GhostShipGenerator.SpawnGhostShip(difficulty: number?): GhostShip?
    local template = getGhostShipTemplate()
    if not template then return nil end

    local ship = template:Clone()
    ship:PivotTo(CFrame.new(
        math.random(-CONFIG.SpawnDistance, CONFIG.SpawnDistance),
        18,
        math.random(-CONFIG.SpawnDistance, CONFIG.SpawnDistance)
    ))
    ship.Parent = workspace

    CollectionService:AddTag(ship, "GhostShip")

    -- Critical for mobile: Server owns all physics
    for _, descendant in ship:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant:SetNetworkOwner(nil)
        end
    end

    local ghostShip: GhostShip = {
        Model = ship,
        Difficulty = difficulty or 1.0,
        LastSpawnTime = tick(),
    }

    table.insert(activeShips, ghostShip)
    return ghostShip
end

function GhostShipGenerator.GetActiveShips(): {GhostShip}
    return activeShips
end

function GhostShipGenerator.CullDistantShips(center: Vector3)
    for i = #activeShips, 1, -1 do
        local ship = activeShips[i]
        if ship.Model.PrimaryPart then
            local dist = (ship.Model.PrimaryPart.Position - center).Magnitude
            if dist > CONFIG.CullDistance then
                ship.Model:Destroy()
                table.remove(activeShips, i)
            end
        end
    end
end

function GhostShipGenerator.Initialize()
    globalMaid:GiveTask(RunService.Heartbeat:Connect(function()
        if #activeShips < CONFIG.MaxShips and math.random() < CONFIG.SpawnChancePerTick then
            GhostShipGenerator.SpawnGhostShip(1.0 + (#activeShips * 0.12))
        end
    end))

    print("[GhostShipGenerator] Initialized with real GhostShipRig from ServerStorage.Assets")
end

function GhostShipGenerator.Destroy()
    globalMaid:Cleanup()
    for _, ship in activeShips do
        if ship.Model then ship.Model:Destroy() end
    end
    table.clear(activeShips)
end

return GhostShipGenerator