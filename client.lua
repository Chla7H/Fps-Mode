-- client.lua | MEGA FPS MENU - real boosters only (no fake toggles)

local menuOpen = false
local currentMode = "normal"
local fps = 60

local settings = {
    shadows = true,
    particles = true,
    density = true,
    parked = true,
    lod = true,
    lights = true,
    distant = true,
    gen = true,
    fires = true
}

local modes = {
    normal = { ped = 1.0, veh = 1.0, rand = 1.0, park = 1.0, scen = 1.0, lodScale = 1.0, shadows = true,  particles = true,  rain = true,  density = true,  parked = true, lod = true,  extras = false, pop = false, timecycle = nil, blackout = false, nodistant = false, nogen = false, nofire = false },
    fps    = { ped = 0.5, veh = 0.4,  rand = 0.4,  park = 0.4,  scen = 0.4,  lodScale = 1.0, shadows = true,  particles = true,  rain = true,  density = true,  parked = true, lod = true,  extras = false, pop = false, timecycle = nil, blackout = false, nodistant = false, nogen = false, nofire = false },
    boost  = { ped = 0.2, veh = 0.15, rand = 0.15, park = 0.15, scen = 0.15, lodScale = 0.55, shadows = false, particles = false, rain = false, density = false, parked = false, lod = false, extras = true,  pop = false, timecycle = "cinema", blackout = false, nodistant = true,  nogen = true,  nofire = true },
    low    = { ped = 0.1, veh = 0.1,  rand = 0.1,  park = 0.1,  scen = 0.1,  lodScale = 0.65, shadows = false, particles = false, rain = false, density = false, parked = false, lod = false, extras = true,  pop = false, timecycle = "cinema", blackout = false, nodistant = true,  nogen = true,  nofire = true },
    citizen = { ped = 0.6, veh = 0.6, rand = 0.6, park = 0.5, scen = 0.6, lodScale = 1.0, shadows = true, particles = true, rain = true, density = true, parked = true, lod = true, extras = true, pop = false, timecycle = nil, blackout = false, nodistant = false, nogen = false, nofire = true },
    beast  = { ped = 0.0, veh = 0.0,  rand = 0.0,  park = 0.0,  scen = 0.0,  lodScale = 0.25, shadows = false, particles = false, rain = false, density = false, parked = false, lod = false, extras = true,  pop = true,  timecycle = "yell_tunnel_nodirect", blackout = true,  nodistant = true,  nogen = true,  nofire = true },
    ultra  = { ped = 0.0, veh = 0.0,  rand = 0.0,  park = 0.0,  scen = 0.0,  lodScale = 0.3,  shadows = false, particles = false, rain = false, density = false, parked = false, lod = false, extras = true,  pop = true,  timecycle = "yell_tunnel_nodirect", blackout = true,  nodistant = true,  nogen = true,  nofire = true }
}


-- ========== Local weather (only this player sees it) ==========
local weatherTypes = {
    sun   = { type = "EXTRASUNNY" },
    rain  = { type = "RAIN" },
    storm = { type = "THUNDER" },
    fog   = { type = "FOGGY" },
    snow  = { type = "XMAS", snow = true },
    night = { type = "CLEAR", hour = 0 }
}
local currentWeather = "sun"
local weatherActive = false

local function EnforceWeather()
    local w = weatherTypes[currentWeather]
    if not w then return end
    SetWeatherTypePersist(w.type)
    SetWeatherTypeNowPersist(w.type)
    SetWeatherTypeNow(w.type)
    if w.hour then
        NetworkOverrideClockTime(w.hour, 0, 0)
    else
        NetworkClearClockTimeOverride()
    end
    ForceSnowPass(w.snow == true)
    SetForceVehicleTrails(w.snow == true)
    SetForcePedFootstepsTracks(w.snow == true)
end

function ApplyWeather(name)
    if not weatherTypes[name] then return end
    currentWeather = name
    weatherActive = true
    -- stop common weather-sync scripts from fighting this client-side weather
    TriggerEvent("qb-weathersync:client:DisableSync")
    TriggerEvent("vSync:toggle", false)
    EnforceWeather()
end

Citizen.CreateThread(function()
    Citizen.Wait(2000)
    ApplyWeather("sun") -- default weather
    while true do
        Citizen.Wait(1000)
        if weatherActive then EnforceWeather() end
    end
end)

-- ========== Apply mode ==========
local function ApplyMode(modeName)
    local mode = modes[modeName]
    if not mode then return end

    currentMode = modeName
    settings.shadows   = mode.shadows
    settings.particles = mode.particles
    settings.density   = mode.density
    settings.parked    = mode.parked
    settings.lod       = mode.lod
    settings.lights    = not mode.blackout
    settings.distant   = not mode.nodistant
    settings.gen       = not mode.nogen
    settings.fires     = not mode.nofire

    SetArtificialLightsState(mode.blackout == true)
    DisableVehicleDistantlights(mode.nodistant == true)
    SetAllVehicleGeneratorsActive(not mode.nogen)

    if mode.timecycle then
        SetTimecycleModifier(mode.timecycle)
        SetTimecycleModifierStrength(modeName == "ultra" and 0.85 or (modeName == "low" and 0.5 or 0.6))
    else
        ClearTimecycleModifier()
    end

    RopeDrawShadowEnabled(not mode.extras)
    SetCloudsAlpha(mode.extras and 0.0 or 1.0)

    if not mode.particles then
        RemoveParticleFxInRange(GetEntityCoords(PlayerPedId()), 100.0)
    end

    ClearAllBrokenGlass()
    ClearPedBloodDamage(PlayerPedId())
    ClearPedWetness(PlayerPedId())
    ClearPedEnvDirt(PlayerPedId())
end

-- ========== Open / close ==========
local function CloseMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = "close" })
end

local function OpenMenu()
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "open", fps = fps, mode = currentMode, settings = settings, weather = currentWeather })
end

RegisterCommand("fps", function()
    if menuOpen then CloseMenu() else OpenMenu() end
end, false)

-- ========== Per-frame boosters ==========
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local mode = modes[currentMode] or modes.normal

        -- Density: zero or mode values
        if not settings.density then
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
        else
            SetPedDensityMultiplierThisFrame(mode.ped)
            SetScenarioPedDensityMultiplierThisFrame(mode.scen, mode.scen)
            SetVehicleDensityMultiplierThisFrame(mode.veh)
            SetRandomVehicleDensityMultiplierThisFrame(mode.rand)
            SetParkedVehicleDensityMultiplierThisFrame(mode.park)
        end

        -- Parked vehicles
        if not settings.parked then
            SetNumberOfParkedVehicles(-1)
        end

        -- Draw distance (LOD) - one of the strongest boosters
        if not settings.lod then
            OverrideLodscaleThisFrame(mode.lodScale)
        end

        -- Shadows
        if not settings.shadows then
            CascadeShadowsSetCascadeBoundsScale(0.0)
            CascadeShadowsEnableEntityTracker(false)
        end

        -- Boost/ultra pack: model budgets, boats, garbage trucks, distant sirens
        if mode.extras then
            SetReducePedModelBudget(true)
            SetReduceVehicleModelBudget(true)
            SetGarbageTrucks(false)
            SetRandomBoats(false)
            DistantCopCarSirens(false)
            if mode.pop then
                SetPedPopulationBudget(0)
                SetVehiclePopulationBudget(0)
            end
        end
    end
end)

-- ========== Periodic cleanup every 5 seconds ==========
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        if currentMode == "normal" then goto continue end

        local coords = GetEntityCoords(PlayerPedId())

        if not settings.particles then
            RemoveParticleFxInRange(coords, 120.0)
        end

        if currentMode == "boost" or currentMode == "low" or currentMode == "beast" or currentMode == "ultra" then
            RemoveDecalsInRange(coords.x, coords.y, coords.z, 120.0)
        end

        if not settings.fires then
            StopFireInRange(coords.x, coords.y, coords.z, 150.0)
        end

        ::continue::
    end
end)

-- ========== FPS counter ==========
Citizen.CreateThread(function()
    local prev = GetGameTimer()
    local frames = 0

    while true do
        Citizen.Wait(0)
        frames = frames + 1
        local now = GetGameTimer()

        if now - prev >= 1000 then
            fps = frames
            frames = 0
            prev = now

            if menuOpen then
                SendNUIMessage({ action = "updateFPS", fps = fps })
            end
        end
    end
end)

-- ========== Focus guard ==========
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        -- focus left alone: other Nizar UIs manage their own focus
    end
end)

-- ========== NUI Callbacks ==========
RegisterNUICallback("close", function(_, cb)
    CloseMenu()
    cb("ok")
end)

RegisterNUICallback("selectMode", function(data, cb)
    local mode = data.mode
    if mode and modes[mode] then
        ApplyMode(mode)
    end
    cb("ok")
end)

RegisterNUICallback("toggleSetting", function(data, cb)
    local name = data.setting
    local value = data.value

    if name and settings[name] ~= nil then
        settings[name] = value

        if name == "shadows" then
            if value then
                CascadeShadowsSetCascadeBoundsScale(1.0)
                CascadeShadowsEnableEntityTracker(true)
            else
                CascadeShadowsSetCascadeBoundsScale(0.0)
                CascadeShadowsEnableEntityTracker(false)
            end
        elseif name == "particles" and not value then
            RemoveParticleFxInRange(GetEntityCoords(PlayerPedId()), 100.0)
        elseif name == "lights" then
            SetArtificialLightsState(not value)
        elseif name == "distant" then
            DisableVehicleDistantlights(not value)
        elseif name == "gen" then
            SetAllVehicleGeneratorsActive(value)
        elseif name == "fires" and not value then
            local c = GetEntityCoords(PlayerPedId())
            StopFireInRange(c.x, c.y, c.z, 150.0)
        end
    end
    cb("ok")
end)

RegisterNUICallback("selectWeather", function(data, cb)
    if data and data.weather then ApplyWeather(data.weather) end
    cb("ok")
end)

RegisterNUICallback("cleanLag", function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    ClearAreaOfPeds(coords.x, coords.y, coords.z, 150.0, 1)
    ClearAreaOfVehicles(coords.x, coords.y, coords.z, 150.0, false, false, false, false, false)
    ClearAreaOfObjects(coords.x, coords.y, coords.z, 150.0, 0)
    RemoveParticleFxInRange(coords, 120.0)
    RemoveDecalsInRange(coords.x, coords.y, coords.z, 150.0)
    StopFireInRange(coords.x, coords.y, coords.z, 150.0)
    ClearAllBrokenGlass()
    ClearPedBloodDamage(PlayerPedId())
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then
        WashDecalsFromVehicle(veh, 1.0)
        SetVehicleDirtLevel(veh, 0.0)
    end
    StopAllAlarms(true)
    cb("ok")
end)

RegisterNUICallback("restartSettings", function(_, cb)
    currentMode = "normal"
    settings = { shadows = true, particles = true, density = true, parked = true, lod = true, lights = true, distant = true, gen = true, fires = true }
    SetArtificialLightsState(false)
    DisableVehicleDistantlights(false)
    SetAllVehicleGeneratorsActive(true)
    ClearTimecycleModifier()
    ApplyWeather("sun")
    SetCloudsAlpha(1.0)
    CascadeShadowsSetCascadeBoundsScale(1.0)
    CascadeShadowsEnableEntityTracker(true)
    RopeDrawShadowEnabled(true)
    cb("ok")
end)


-- release NUI focus if the resource stops/restarts while menu is open
AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)

-- make sure the UI is hidden on start
Citizen.CreateThread(function()
    Citizen.Wait(500)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end)
