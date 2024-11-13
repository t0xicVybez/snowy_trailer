-- statebags.lua
local Config = require 'configs.client'

local function HandleTowingRopeSync(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    local entity = GetEntityFromStateBagName(bagName)
    if not entity then return end
    
    if value then
        local vehicle = value.vehicle
        local trailer = value.trailer
        
        if not DoesEntityExist(vehicle) or not DoesEntityExist(trailer) then return end
        
        Wait(1000)
        
        -- Clean up any existing ropes
        if State.rope then
            DeleteRope(State.rope)
            State.rope = nil
        end
        if State.activeRopes[vehicle] then
            DeleteRope(State.activeRopes[vehicle])
            State.activeRopes[vehicle] = nil
        end
        
        local trailerBoneIndex = GetEntityBoneIndexByName(trailer, 'attach_male')
        local vehicleBoneIndex = GetEntityBoneIndexByName(vehicle, 'engine')
        
        if not trailerBoneIndex or not vehicleBoneIndex then return end
        
        local heightOffset = value.heightOffset
        local trailerPos = GetWorldPositionOfEntityBone(trailer, trailerBoneIndex)
        trailerPos = vector3(trailerPos.x, trailerPos.y, trailerPos.z + heightOffset)
        local vehiclePos = GetWorldPositionOfEntityBone(vehicle, vehicleBoneIndex)
        local distance = #(trailerPos - vehiclePos)
        
        if not RopeAreTexturesLoaded() then
            RopeLoadTextures()
            while not RopeAreTexturesLoaded() do
                Wait(0)
            end
        end
        
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
        State.activeRopes[vehicle] = rope
    else
        if State.activeRopes[entity] then
            DeleteRope(State.activeRopes[entity])
            State.activeRopes[entity] = nil
        end
    end
end

local function HandleRopeHolderSync(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
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
    end
end

local function HandleMainRampSync(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    local trailer = GetEntityFromStateBagName(bagName)
    State.isMainRampDown = value
    if value then
        SetVehicleDoorOpen(trailer, 5, false, false)
    else
        SetVehicleDoorShut(trailer, 5, false)
    end
end

local function HandleSecondaryRampSync(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    local trailer = GetEntityFromStateBagName(bagName)
    State.isSecondRampDown = value
    if value then
        SetVehicleDoorOpen(trailer, 4, false, false)
    else
        SetVehicleDoorShut(trailer, 4, false)
    end
end

local function HandleInvisibleItemSync(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    if value then
        State.invisibleItem = GetEntityFromStateBagName(bagName)
        State.invisibleItemPos = GetEntityCoords(State.invisibleItem)
    else
        State.invisibleItem = nil
        State.invisibleItemPos = nil
    end
end

local function HandleTrailerInvisibleItemSync(bagName, key, value)
    if Config.Debug then
        lib.print.warn("statebag change", key, value)
    end
    Wait(1000)
    State.trailer = GetEntityFromStateBagName(bagName)
    if value then
        TakeRopeActually()
    else
        DeleteRope(State.rope)
        State.rope = nil
    end
end

local function HandleVehicleAttachSync(bagName, key, value)
    if value then
        AttachRopeToVehicle(GetEntityFromStateBagName(bagName))
    end
end

AddStateBagChangeHandler('towing_rope', nil, HandleTowingRopeSync)
AddStateBagChangeHandler('ropeHolder', nil, HandleRopeHolderSync)
AddStateBagChangeHandler('mainRampOpen', nil, HandleMainRampSync)
AddStateBagChangeHandler('secondaryRampOpen', nil, HandleSecondaryRampSync)
AddStateBagChangeHandler('connectedToTrailer', nil, HandleInvisibleItemSync)
AddStateBagChangeHandler('connectedToInvisibleItem', nil, HandleTrailerInvisibleItemSync)
AddStateBagChangeHandler('setVehicle', nil, HandleVehicleAttachSync)