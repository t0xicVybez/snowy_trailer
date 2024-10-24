Config = require 'configs.client'

-- State variables
State = {
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
        top = {nil, nil, nil},     -- When ramp is down
        bottom = {nil, nil, nil}   -- Ground level
    },
    vehicleSizes = {}        -- Store vehicle lengths
}

---@description Gets the position behind the trailer.
---@param distance number
---@param sideOffset number
---@return vector3 | nil
local function GetPositionBehindTrailer(distance, sideOffset)
    if not State.trailer then return nil end
    
    return GetOffsetFromEntityInWorldCoords(
        State.trailer,
        sideOffset,
        -distance,
        0.0
    )
end

---@description Resets the rope state.
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

---@description Spawns a trailer at the given position.
---@param position any
function SpawnTrailer(position)
    local trailerHash = 'tr2'
    lib.requestModel(trailerHash, 5000)
    
    State.trailer = CreateVehicle(trailerHash, position.x, position.y, position.z, position.w, true, false)
    SetEntityAsMissionEntity(State.trailer, true, true)
    exports.ox_target:addLocalEntity(State.trailer, {
        {
            name = 'take_rope',
            label = 'Take Rope',
            icon = 'fas fa-rope-solid',
            onSelect = function()
                TakeRope()
            end,
            canInteract = function()
                return not State.isHoldingRope and not State.attachedVehicle
            end
        },
        {
            name = 'return_rope',
            label = 'Return Rope',
            icon = 'fas fa-hand',
            onSelect = function()
                ReturnRope()
            end,
            canInteract = function()
                return State.isHoldingRope and not State.attachedVehicle
            end
        },
        {
            name = 'detach_rope',
            label = 'Detach Rope',
            icon = 'fas fa-scissors',
            onSelect = function()
                DetachRope()
            end,
            canInteract = function()
                return State.attachedVehicle ~= nil
            end
        },
        {
            name = 'teleport_behind',
            label = 'Move Behind Trailer',
            icon = 'fas fa-arrow-right',
            onSelect = function()
                TeleportVehicleBehindTrailer(false)
            end
        },
        {
            name = 'ramp_controls',
            label = 'Ramp Controls',
            icon = 'fas fa-angle-down',
            onSelect = function()
                ShowRampControls()
            end
        },
        {
            name = 'pull_vehicle',
            label = 'Pull Vehicle',
            icon = 'fas fa-arrow-right',
            onSelect = function()
                StartPullingVehicle()
            end,
            canInteract = function()
                return State.attachedVehicle ~= nil -- Only show when a vehicle is attached
            end
        },
    })
    SetModelAsNoLongerNeeded(trailerHash)
    return State.trailer
end
exports('CreateTrailer', SpawnTrailer)
-- Function to take rope from trailer
---@description Makes the rope per client and attaches it to the trailer.
function TakeRopeActually()
    
    local trailerBoneIndex = GetEntityBoneIndexByName(State.trailer, 'attach_male')
    local trailerBonePos = GetWorldPositionOfEntityBone(State.trailer, trailerBoneIndex)

    if not RopeAreTexturesLoaded() then
		RopeLoadTextures()
		while not RopeAreTexturesLoaded() do
			Wait(0)
		end
	end
    -- Delete existing rope if there is one
    if State.rope then
        DeleteRope(State.rope)
        State.rope = nil
    end
    
    -- Create rope with better visibility parameters
    local ropeLength = 40.0
    State.rope = AddRope(
        trailerBonePos.x, trailerBonePos.y, trailerBonePos.z,
        0.0, 0.0, 0.5,
        ropeLength,        -- Length
        1,                -- Type (1 = normal rope)
        ropeLength,       -- Max length
        1.0,             -- Min length ratio
        9.0,             -- Force multiplier (increased for better physics)
        false,           -- Unbreakable
        true,           -- Rigid (set to false for more natural movement)
        true,            -- Start tied
        1.0,             -- Texture variation
        true             -- World position
    )
    AttachEntitiesToRope(State.rope, 
        State.trailer, State.invisibleItem,
        trailerBonePos.x, trailerBonePos.y, trailerBonePos.z+0.5,  -- trailer offset
        State.invisibleItemPos.x, State.invisibleItemPos.y, State.invisibleItemPos.z,  -- player hand offset
        ropeLength,
        false, false,
        trailerBoneIndex,
        State.invisibleItemPos
    )    
    -- Make sure rope exists before continuing
end

---@description The function that handles rope taking.
function TakeRope()
    -- Set ourselves as the rope initiator
    State.ropeInitiator = cache.serverId
    
    -- Set the state bag on the trailer to track who has the rope
    Entity(State.trailer).state:set('ropeHolder', State.ropeInitiator, true)
    
    -- Only create the invisible item and rope if we're the initiator
    if State.ropeInitiator == cache.serverId then
        local playerPed = cache.ped
        local playerLeftHandBone = GetPedBoneIndex(playerPed, 18905)
        local playerLeftHandBonePos = GetWorldPositionOfEntityBone(playerPed, playerLeftHandBone)
        
        if State.invisibleItem then
            DeleteEntity(State.invisibleItem)
            State.invisibleItem = nil
        end
        
        -- Create and attach invisible item
        lib.requestModel('prop_tequila_bottle', 5000)
        
        State.invisibleItem = CreateObject(`prop_tequila_bottle`, playerLeftHandBonePos.x, playerLeftHandBonePos.y, playerLeftHandBonePos.z, true, true, true)
        SetEntityVisible(State.invisibleItem, false, 0)
        SetEntityCollision(State.invisibleItem, false, false)
        NetworkRegisterEntityAsNetworked(State.invisibleItem)
        
        local netId = NetworkGetNetworkIdFromEntity(State.invisibleItem)
        SetNetworkIdExistsOnAllMachines(netId, true)
        
        AttachEntityToEntity(State.invisibleItem, playerPed, playerLeftHandBone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        Entity(State.invisibleItem).state:set("connectedToTrailer", true, true)
        Entity(State.trailer).state:set("connectedToInvisibleItem", true, true)
        SetModelAsNoLongerNeeded('prop_tequila_bottle')
        -- Create the rope
    end
    
    State.isHoldingRope = true
    CreateVehicleTargetOptions()
end

---@description Creates the target options for nearby vehicles when holding rope.
function CreateVehicleTargetOptions()
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
---@description Returns the rope to the trailer.
function ReturnRope()
    if State.ropeInitiator == cache.serverId then
        ResetRopeState()
    end
    exports.ox_target:removeGlobalVehicle({'attach_rope_to_vehicle'})
end

---@description Detaches the rope from the vehicle.
function DetachRope()
    if not State.attachedVehicle then return end
    if State.ropeInitiator == cache.serverId then
        TakeRope()
        ReturnRope()
        RemoveSyncedRope(State.attachedVehicle)
        ResetRopeState()
        Entity(State.trailer).state:set('towing_rope', nil, true)
    end
    
    State.attachedVehicle = nil
end

---@description Command to spawn them setup when debug is enabled
if Config.Debug then
    RegisterCommand('spawntowtruck', function()
        local playerPos = GetEntityCoords(cache.ped)
        SpawnTrailer(vector4(playerPos.x+5.0, playerPos.y+2.0, playerPos.z, GetEntityHeading(cache.ped)))
        lib.notify({
            title = 'Success',
            description = 'Vehicles spawned successfully',
            type = 'success'
        })
    end, false)
end

---@description Handles the ramp controls via context menu.
function ShowRampControls()
    lib.showContext('trailer_ramp_controls')
end

-- Create the context menu for ramp controls
lib.registerContext({
    id = 'trailer_ramp_controls',
    title = 'Trailer Ramp Controls',
    options = {
        {
            title = 'Main Ramp',
            description = 'Control the main loading ramp',
            onSelect = function()
                Entity(State.trailer).state:set("mainRampOpen", not State.isMainRampDown, true) 
                -- For now we'll just notify
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

---@description Gets the closest vehicle bumper to the player.
---@param vehicle number
---@return string | vector3 | nil
function GetClosestVehicleBumper(vehicle)
    if not vehicle then return nil end
    
    -- Get player position
    local playerPos = GetEntityCoords(cache.ped)
    
    -- Get vehicle bone positions
    local frontBoneIndex = GetEntityBoneIndexByName(vehicle, 'bumper_f')
    local rearBoneIndex = GetEntityBoneIndexByName(vehicle, 'bumper_r')
    
    if not frontBoneIndex or not rearBoneIndex then return nil end
    
    local frontBumperPos = GetWorldPositionOfEntityBone(vehicle, frontBoneIndex)
    local rearBumperPos = GetWorldPositionOfEntityBone(vehicle, rearBoneIndex)
    
    -- Calculate distances
    local distToFront = #(playerPos - frontBumperPos)
    local distToRear = #(playerPos - rearBumperPos)
    
    -- Return the closest bone index and position
    if distToFront < distToRear then
        return frontBoneIndex, frontBumperPos, 'front'
    else
        return rearBoneIndex, rearBumperPos, 'rear'
    end
end

---@description Creates a synced rope between the trailer and vehicle.
---@param vehicle number
function CreateSyncedRope(vehicle)
    if not vehicle or not State.trailer then return end
    
    -- Get trailer bone position
    local trailerBoneIndex = GetEntityBoneIndexByName(State.trailer, 'bumper_r')
    local trailerPos = GetWorldPositionOfEntityBone(State.trailer, trailerBoneIndex)
    
    -- Adjust height based on ramp states
    local heightOffset = State.isMainRampDown and (State.isSecondRampDown and 3.5 or 0.5) or 0.0
    trailerPos = vector3(trailerPos.x, trailerPos.y, trailerPos.z + heightOffset)
    
    -- Get closest vehicle bumper
    local vehicleBoneIndex, vehiclePos, attachPoint = GetClosestVehicleBumper(vehicle)
    if not vehicleBoneIndex then return end
    
    -- Fixed rope length
    local ropeLength = 25.0
    
    -- Create the rope
    if not RopeAreTexturesLoaded() then
        RopeLoadTextures()
        while not RopeAreTexturesLoaded() do
            Wait(0)
        end
    end
    
    local rope = AddRope(
        trailerPos.x, trailerPos.y, trailerPos.z,
        0.0, 0.0, 0.0,
        ropeLength,
        1,
        ropeLength,
        1.0,
        1.0,
        true,
        true,
        true,
        1.0,
        true
    )
    
    -- Store rope reference
    State.activeRopes[vehicle] = rope
    
    -- Attach rope to both entities
    ActivatePhysics(rope)
    AttachEntitiesToRope(rope,
        State.trailer, vehicle,
        trailerPos.x, trailerPos.y, trailerPos.z,
        vehiclePos.x, vehiclePos.y, vehiclePos.z,
        ropeLength,
        true, true
    )
    
    -- Force the rope to be tight
    RopeForceLength(rope, ropeLength)
    
    -- Sync the rope state
    Entity(State.trailer).state:set('towing_rope', {
        vehicle = vehicle,
        trailer = State.trailer,
        heightOffset = heightOffset,
        ropeLength = ropeLength,
        attachPoint = attachPoint
    }, true)
end

---@description Removes the synced rope.
---@param vehicle number
function RemoveSyncedRope(vehicle)
    if not vehicle then return end
    
    -- Remove the rope state
    Entity(State.trailer).state:set('towing_rope', nil, true)
    
    if State.activeRopes[vehicle] then
        DeleteRope(State.activeRopes[vehicle])
        State.activeRopes[vehicle] = nil
    end
    
    -- Remove the target option from trailer
    exports.ox_target:removeLocalEntity(State.trailer, {'pull_vehicle'})
    
    -- Reset attached vehicle state
    State.attachedVehicle = nil
    
    -- Re-add target options for the trailer
    exports.ox_target:addLocalEntity(State.trailer, {
        {
            name = 'pull_vehicle',
            label = 'Pull Vehicle',
            icon = 'fas fa-arrow-up',
            onSelect = function()
                StartPullingVehicle()
            end,
            canInteract = function()
                return State.attachedVehicle ~= nil
            end
        }
    })
end

-- Add state bag handler for rope sync

---@description Teleports the vehicle behind the trailer.
---@param reverse boolean
function TeleportVehicleBehindTrailer(reverse)
    if not State.attachedVehicle then return end
    
    local pos = GetPositionBehindTrailer(15.0, 0.0)
    if not pos then return end
    
    local heading = GetEntityHeading(State.trailer)
    if reverse then
        heading = (heading + 180.0) % 360.0
    end
    
    SetEntityCoordsNoOffset(State.attachedVehicle, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(State.attachedVehicle, heading)
end

---@description Attaches the rope to the vehicle.
---@param vehicle number
function AttachRopeToVehicle(vehicle)
    if not vehicle then return end
    
    -- Get bone positions
    local trailerBoneIndex = GetEntityBoneIndexByName(State.trailer, 'attach_male')
    local vehicleBoneIndex = GetEntityBoneIndexByName(vehicle, 'engine')
    
    if not trailerBoneIndex or not vehicleBoneIndex then 
        lib.notify({
            title = 'Error',
            description = 'Could not find attachment points',
            type = 'error'
        })
        return 
    end
    
    -- Clean up the old rope in hand first
    if State.rope then
        DeleteRope(State.rope)
        State.rope = nil
    end
    
    if State.invisibleItem then
        DeleteEntity(State.invisibleItem)
        State.invisibleItem = nil
    end
    
    -- Store the attached vehicle
    State.attachedVehicle = vehicle
    
    -- Calculate height offset based on ramp states
    local heightOffset = State.isMainRampDown and (State.isSecondRampDown and 3.5 or 0.5) or 0.0
    
    -- Create a synced rope between points
    local headingDifference = GetEntityHeading(State.attachedVehicle) - GetEntityHeading(State.trailer)
    if (headingDifference + 180) % 360 < 90 then
        TeleportVehicleBehindTrailer(true)
    else
        TeleportVehicleBehindTrailer(false)
    end
    Entity(State.trailer).state:set('towing_rope', {
        vehicle = vehicle,
        trailer = State.trailer,
        heightOffset = heightOffset,
        ropeLength = 25.0
    }, true)
    
    -- Clean up the holding rope state
    State.isHoldingRope = false
    
    lib.notify({
        title = 'Success',
        description = 'Rope attached to vehicle',
        type = 'success'
    })
end

---@description Moves the vehicle towards the trailer rope position.
function StartPullingVehicle()
    if not State.attachedVehicle or not State.trailer then return end
    local trailerBoneIndex = GetEntityBoneIndexByName(State.trailer, 'attach_male')
    local vehicleBoneIndex = GetEntityBoneIndexByName(State.attachedVehicle, 'engine')
    if not trailerBoneIndex or not vehicleBoneIndex then return end
    local trailerHeading = GetEntityHeading(State.trailer)
    local vehicleHeading = GetEntityHeading(State.attachedVehicle)
    local headingDiff = math.abs(trailerHeading - vehicleHeading)
    local isBackwards = headingDiff > 150 and headingDiff < 210
    local speed = 2.0
    if isBackwards then
        speed = -2.0
    end
    local headingDifference = GetEntityHeading(State.attachedVehicle) - GetEntityHeading(State.trailer)
    if (headingDifference + 180) % 360 < 90 then
        TeleportVehicleBehindTrailer(true)
    else
        TeleportVehicleBehindTrailer(false)
    end
    Wait(300)
    Entity(State.trailer).state:set('towing_rope', {
        vehicle = State.attachedVehicle,
        trailer = State.trailer,
        heightOffset = State.isMainRampDown and (State.isSecondRampDown and 3.5 or 0.5) or 0.0,
        ropeLength = 25.0
    }, true)
    
    CreateThread(function()
        while State.attachedVehicle and State.activeRopes[State.attachedVehicle] do
            local trailerPos = GetWorldPositionOfEntityBone(State.trailer, trailerBoneIndex)
            local vehiclePos = GetWorldPositionOfEntityBone(State.attachedVehicle, vehicleBoneIndex)
            local heightOffset = State.isMainRampDown and (State.isSecondRampDown and 3.5 or 0.5) or 0.0
            trailerPos = vector3(trailerPos.x, trailerPos.y, trailerPos.z + heightOffset)
            local distance = #(trailerPos - vehiclePos)
            if distance <= (State.isMainRampDown and Config.Distance.SecondaryRamp or Config.Distance.MainRamp) then
                Entity(State.trailer).state:set('towing_rope', nil, true)
                break
            end
            
            SetVehicleForwardSpeed(State.attachedVehicle, speed)
            Wait(0)
        end
    end)
end

---@description Stops the vehicle from being pulled.
function StopPullingVehicle()
    if State.attachedVehicle then
        SetVehicleForwardSpeed(State.attachedVehicle, 0.0)
        
    end
end












