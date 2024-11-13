local Config = require 'configs.client'

local State = {
    trailer = nil,
    truck = nil,
    rope = nil,
    isHoldingRope = false,
    attachedVehicle = nil,
    invisibleItem = nil,
    invisibleItemPos = nil,
    isMainRampDown = false,
    isSecondRampDown = false,
    ropeInitiator = nil,
    activeRopes = {},
    ropeObjects = {},
    attachedVehicles = {
        top = {nil, nil, nil},
        bottom = {nil, nil, nil}
    },
    vehicleSizes = {}
}

local function GetPositionBehindTrailer(distance, sideOffset)
    if not State.trailer then return nil end
    return GetOffsetFromEntityInWorldCoords(State.trailer, sideOffset, -distance, 0.0)
end

local function ResetRopeState()
    if State.invisibleItem then
        Entity(State.invisibleItem).state:set("connectedToTrailer", false, true)
        Entity(State.trailer).state:set("connectedToInvisibleItem", false, true)
        DeleteEntity(State.invisibleItem)
        State.invisibleItem = nil
    end
    if State.rope then
        DeleteRope(State.rope)
        State.rope = nil
    end
    State.isHoldingRope = false
    Entity(State.trailer).state:set('ropeHolder', nil, true)
end

local function SpawnTrailer(position)
    local trailerHash = GetHashKey('tr2')
    RequestModel(trailerHash)
    while not HasModelLoaded(trailerHash) do
        Wait(0)
    end
    
    State.trailer = CreateVehicle(trailerHash, position.x, position.y, position.z, position.w, true, false)
    SetEntityAsMissionEntity(State.trailer, true, true)
    exports.ox_target:addLocalEntity(State.trailer, {
        -- Trailer target options
    })
end
exports('CreateTrailer', SpawnTrailer)

local function TakeRopeActually()
    local trailerBoneIndex = GetEntityBoneIndexByName(State.trailer, 'attach_male')
    local trailerBonePos = GetWorldPositionOfEntityBone(State.trailer, trailerBoneIndex)

    if not RopeAreTexturesLoaded() then
        RopeLoadTextures()
        while not RopeAreTexturesLoaded() do
            Wait(0)
        end
    end
    
    if State.rope then
        DeleteRope(State.rope)
        State.rope = nil
    end
    
    local ropeLength = 40.0
    State.rope = AddRope(
        trailerBonePos.x, trailerBonePos.y, trailerBonePos.z,
        0.0, 0.0, 0.5,
        ropeLength,
        1,
        ropeLength,
        1.0,
        9.0,
        false,
        true,
        true,
        1.0,
        true
    )
    AttachEntitiesToRope(State.rope, State.trailer, State.invisibleItem,
        trailerBonePos.x, trailerBonePos.y, trailerBonePos.z+0.5,
        State.invisibleItemPos.x, State.invisibleItemPos.y, State.invisibleItemPos.z,
        ropeLength,
        false, false,
        trailerBoneIndex,
        State.invisibleItemPos
    )
end

local function TakeRope()
    State.ropeInitiator = GetPlayerServerId(PlayerId())
    Entity(State.trailer).state:set('ropeHolder', State.ropeInitiator, true)
    
    if State.ropeInitiator == GetPlayerServerId(PlayerId()) then
        local playerPed = PlayerPedId()
        local playerLeftHandBone = GetPedBoneIndex(playerPed, 18905)
        local playerLeftHandBonePos = GetWorldPositionOfEntityBone(playerPed, playerLeftHandBone)
        
        if State.invisibleItem then
            DeleteEntity(State.invisibleItem)
            State.invisibleItem = nil
        end
        
        RequestModel(`prop_tequila_bottle`)
        while not HasModelLoaded(`prop_tequila_bottle`) do
            Wait(0)
        end
        
        State.invisibleItem = CreateObject(`prop_tequila_bottle`, playerLeftHandBonePos.x, playerLeftHandBonePos.y, playerLeftHandBonePos.z, true, true, true)
        SetEntityVisible(State.invisibleItem, false, 0)
        SetEntityCollision(State.invisibleItem, false, false)
        NetworkRegisterEntityAsNetworked(State.invisibleItem)
        
        local netId = NetworkGetNetworkIdFromEntity(State.invisibleItem)
        SetNetworkIdExistsOnAllMachines(netId, true)
        
        AttachEntityToEntity(State.invisibleItem, playerPed, playerLeftHandBone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        Entity(State.invisibleItem).state:set("connectedToTrailer", true, true)
        Entity(State.trailer).state:set("connectedToInvisibleItem", true, true)
    end
    
    State.isHoldingRope = true
    CreateVehicleTargetOptions()
end

local function CreateVehicleTargetOptions()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'attach_rope_to_vehicle',
            label = 'Attach Rope',
            icon = 'fas fa-link',
            onSelect = function(data)
                Entity(data.entity).state:set('setVehicle', true, true)
            end,
            canInteract = function(entity)
                return State.isHoldingRope and entity ~= State.truck and entity ~= State.trailer
            end
        }
    })
end

local function ReturnRope()
    if State.ropeInitiator == GetPlayerServerId(PlayerId()) then
        ResetRopeState()
    end
    exports.ox_target:removeGlobalVehicle({'attach_rope_to_vehicle'})
end

local function DetachRope()
    if not State.attachedVehicle then return end
    if State.ropeInitiator == GetPlayerServerId(PlayerId()) then
        TakeRope()
        ReturnRope()
        RemoveSyncedRope(State.attachedVehicle)
        ResetRopeState()
        Entity(State.trailer).state:set('towing_rope', nil, true)
    end
    State.attachedVehicle = nil
end

if Config.Debug then
    RegisterCommand('spawntowtruck', function()
        local playerPos = GetEntityCoords(PlayerPedId())
        SpawnTrailer(vector4(playerPos.x+5.0, playerPos.y+2.0, playerPos.z, GetEntityHeading(PlayerPedId())))
        lib.notify({
            title = 'Success',
            description = 'Vehicles spawned successfully',
            type = 'success'
        })
    end, false)
end

local function ShowRampControls()
    lib.showContext('trailer_ramp_controls')
end

lib.registerContext({
    id = 'trailer_ramp_controls',
    title = 'Trailer Ramp Controls',
    options = {
        {
            title = 'Main Ramp',
            description = 'Control the main loading ramp',
            onSelect = function()
                Entity(State.trailer).state:set("mainRampOpen", not State.isMainRampDown, true)
                lib.notify({
                    title = 'Ramp Control',
                    description = State.isMainRampDown and 'Main ramp lowered' or 'Main ramp raised',
                    type = 'success'
                })
            end
        },
        {
            title = 'Secondary Ramp',
            description = 'Control the secondary ramp',
            onSelect = function()
                Entity(State.trailer).state:set("secondaryRampOpen", not State.isSecondRampDown, true)
                lib.notify({
                    title = 'Ramp Control',
                    description = State.isSecondRampDown and 'Secondary ramp lowered' or 'Secondary ramp raised',
                    type = 'success'
                })
            end
        }
    }
})

-- Functions for handling vehicle-related logic
local GetClosestVehicleBumper, CreateSyncedRope, RemoveSyncedRope, TeleportVehicleBehindTrailer, AttachRopeToVehicle, StartPullingVehicle, StopPullingVehicle = nil, nil, nil, nil, nil, nil, nil