
---@description handles the vehicle to trailer rope syncing.
AddStateBagChangeHandler('towing_rope', nil, function(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    local entity = lib.waitFor(function()
        entity = GetEntityFromStateBagName(bagname)
        if entity ~= 0 then
            return true
        end
    end, ("Entity (%s) took too long to exist"):format(bagname), 10000)
    if not entity then return end
    
    if value then
        local vehicle = value.vehicle
        local trailer = value.trailer
        
        if not DoesEntityExist(vehicle) or not DoesEntityExist(trailer) then return end
        
        -- Wait for a second to ensure the vehicle is in the correct position
        Wait(1000)
        
        -- Delete any existing rope first
        if State.rope then
            DeleteRope(State.rope)
            State.rope = nil
        end
        if State.activeRopes[vehicle] then
            DeleteRope(State.activeRopes[vehicle])
            State.activeRopes[vehicle] = nil
        end
        
        -- Get bone positions
        local trailerBoneIndex = GetEntityBoneIndexByName(trailer, 'attach_male')
        local vehicleBoneIndex = GetEntityBoneIndexByName(vehicle, 'engine')
        
        if not trailerBoneIndex or not vehicleBoneIndex then return end
        
        -- Calculate height offset based on ramp states
        local heightOffset = value.heightOffset
        local trailerPos = GetWorldPositionOfEntityBone(trailer, trailerBoneIndex)
        trailerPos = vector3(trailerPos.x, trailerPos.y, trailerPos.z + heightOffset)
        local vehiclePos = GetWorldPositionOfEntityBone(vehicle, vehicleBoneIndex)
        local distance = #(trailerPos - vehiclePos)
        -- Load rope textures
        if not RopeAreTexturesLoaded() then
            RopeLoadTextures()
            while not RopeAreTexturesLoaded() do
                Wait(0)
            end
        end
        
        -- Create new rope
        local ropeLength = distance + 0.5
        local rope = AddRope(
            trailerPos.x, trailerPos.y, trailerPos.z,
            0.0, 0.0, 0.0,
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
        
        -- Attach rope ends using the calculated positions
        AttachEntitiesToRope(rope, 
            trailer, vehicle,
            trailerPos.x, trailerPos.y, trailerPos.z,
            vehiclePos.x, vehiclePos.y, vehiclePos.z,
            ropeLength,
            false, false,
            trailerBoneIndex,
            vehicleBoneIndex
        )
        State.rope = rope
        -- Store rope reference
        State.activeRopes[vehicle] = rope
    else
        -- Clean up rope if it exists
        if State.activeRopes[entity] then
            DeleteRope(State.activeRopes[entity])
            State.activeRopes[entity] = nil
        end
    end
end)

---@description Handles the rope in hand syncing..
AddStateBagChangeHandler('ropeHolder', nil, function(bagName, key, value)
    local entity = lib.waitFor(function()
        entity = GetEntityFromStateBagName(bagname)
        if entity ~= 0 then
            return true
        end
    end, ("Entity (%s) took too long to exist"):format(bagname), 10000)
    if not entity then return end

    State.ropeInitiator = value
    if not value then
        if State.invisibleItem then
            DeleteEntity(State.invisibleItem)
            State.invisibleItem = nil
        end
        if State.rope then
            DeleteRope(State.rope)
            State.rope = nil
        end
        State.isHoldingRope = false
        return
    end
end)

---@description Handles the main ramp state syncing.
AddStateBagChangeHandler('mainRampOpen', nil, function(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    local trailer = GetEntityFromStateBagName(bagName)
    State.isMainRampDown = value
    if value then
        SetVehicleDoorOpen(trailer, 5, false, false)
        return
    else
        SetVehicleDoorShut(trailer, 5, false)
        return
    end
end)

---@description Handles the secondary ramp state syncing.
AddStateBagChangeHandler('secondaryRampOpen', nil, function(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    local trailer = lib.waitFor(function()
        entity = GetEntityFromStateBagName(bagname)
        if entity ~= 0 then
            return true
        end
    end, ("Entity (%s) took too long to exist"):format(bagname), 10000)
    State.isSecondRampDown = value  -- Corrected logic
    if value then
        SetVehicleDoorOpen(trailer, 4, false, false)
    else
        SetVehicleDoorShut(trailer, 4, false)
    end
end)

---@description Handles the invisible item to trailer  (the rope to trailer) syncing.
AddStateBagChangeHandler('connectedToTrailer', nil, function(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    if value then
        State.invisibleItem = lib.waitFor(function()
            entity = GetEntityFromStateBagName(bagname)
            if entity ~= 0 then
                return true
            end
        end, ("Entity (%s) took too long to exist"):format(bagname), 10000)
        State.invisibleItemPos = GetEntityCoords(State.invisibleItem)
    else
        State.invisibleItem = nil
        State.invisibleItemPos = nil
    end
end)

---@description Handles the trailer to invisible item (the trailer to rope) syncing.
AddStateBagChangeHandler('connectedToInvisibleItem', nil, function(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    Wait(1000)
    State.trailer = lib.waitFor(function()
        entity = GetEntityFromStateBagName(bagname)
        if entity ~= 0 then
            return true
        end
    end, ("Entity (%s) took too long to exist"):format(bagname), 10000)
    if value then
        TakeRopeActually()
    else
        DeleteRope(State.rope)
        State.rope = nil
    end
end)

---@description Handles the vehicle to trailer syncing.
AddStateBagChangeHandler('setVehicle', nil, function(bagName, key, value)
    if value then
        AttachRopeToVehicle(lib.waitFor(function()
            entity = GetEntityFromStateBagName(bagname)
            if entity ~= 0 then
                return true
            end
        end, ("Entity (%s) took too long to exist"):format(bagname), 10000))
    end
end)




