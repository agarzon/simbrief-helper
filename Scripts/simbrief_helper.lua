-- Simbrief helper
-- Alexander Garzon Jan - 2020

-- Description: pulls OFP data from simbrief (after you generate your flight plan) using your username (API call)
-- This data wil be used: flight level, block fuel, payload, zfw, destination altitude, etc..

-- TODO: 
-- * Get RWY magnetic heading

-- Variables
require("LuaXml")

local socket = require "socket"
local http = require "socket.http"
local LIP = require("LIP");

local SettingsFile = "simbrief_helper.ini"
local SimbriefXMLFile = "simbrief.xml"
local sbUser = ""

local DataOfp = {}
local Settings = {}

local clickFetch = false

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    logMsg("imgui not supported by your FlyWithLua version")
    return
end

function readSettings()
    Settings = LIP.load(SCRIPT_DIRECTORY..SettingsFile);
    if Settings.simbrief.username ~= nil then
        sbUser = Settings.simbrief.username
   end
end

function saveSettings(newSettings)
    LIP.save(SCRIPT_DIRECTORY..SettingsFile, newSettings);
end

function fetchData()
    if sbUser == nil then
        logMsg("No simbrief username has been configured")
        return false
    end

    local webRespose, err = http.request("http://www.simbrief.com/api/xml.fetcher.php?username=" .. sbUser)
    -- would be nice to have a try-cath here
    assert(webRespose, err)

    local f = io.open(SCRIPT_DIRECTORY..SimbriefXMLFile, "w")
    f:write(webRespose)
    f:close()

    logMsg("Simbrief XML data downloaded")
    return true
end

function readXML()
    local xfile = xml.load(SCRIPT_DIRECTORY..SimbriefXMLFile)
    DataOfp["Status"] = xfile:find("status")[1]
    -- validate the file is there

    if DataOfp["Status"] ~= "Success" then
        logMsg("XML status is not success")
        return false
    end
    
    DataOfp["Origin"] = xfile:find("origin"):find("icao_code")[1]
    DataOfp["Origlevation"] = xfile:find("origin"):find("elevation")[1]
    DataOfp["OrigName"] = xfile:find("origin"):find("name")[1]
    DataOfp["OrigRwy"] = xfile:find("origin"):find("plan_rwy")[1]
    DataOfp["OrigMetar"] = xfile:find("orig_metar")[1]
    
    DataOfp["Destination"] = xfile:find("destination"):find("icao_code")[1]
    DataOfp["DestElevation"] = xfile:find("destination"):find("elevation")[1]
    DataOfp["DestName"] = xfile:find("destination"):find("name")[1]
    DataOfp["DestRwy"] = xfile:find("destination"):find("plan_rwy")[1]
    DataOfp["DestMetar"] = xfile:find("dest_metar")[1]

    DataOfp["Cpt"] = xfile:find("cpt")[1]
    DataOfp["Callsign"] = xfile:find("callsign")[1]
    DataOfp["Units"] = xfile:find("units")[1]
    DataOfp["Distance"] = xfile:find("route_distance")[1]
    DataOfp["Route"] = xfile:find("route")[1]
    DataOfp["Level"] = xfile:find("initial_altitude")[1]
    DataOfp["RampFuel"] = xfile:find("plan_ramp")[1]
    DataOfp["MinTakeoff"] = xfile:find("min_takeoff")[1]
    DataOfp["ReserveFuel"] = xfile:find("reserve")[1]
    DataOfp["Payload"] = xfile:find("payload")[1]
    DataOfp["Zfw"] = xfile:find("est_zfw")[1]
    DataOfp["CostIndex"] = xfile:find("costindex")[1]
    DataOfp["AvgWindDir"] = xfile:find("avg_wind_dir")[1]
    DataOfp["AvgWindSpd"] = xfile:find("avg_wind_spd")[1]
    DataOfp["AvgTempDev"] = xfile:find("avg_temp_dev")[1]
    DataOfp["Pax"] = xfile:find("passengers")[1]

    return true
end

function sb_on_build(sb_wnd, x, y)

    readSettings()

    imgui.TextUnformatted(string.format("Welcome, %s (%s)", DataOfp["Cpt"], DataOfp["Callsign"]))

    -- INPUT
    local changed, userNew = imgui.InputText("Simbrief username", sbUser, 255)

    if changed then
        sbUser = userNew
        local newSettings =
        {
            simbrief =
            {
                username = userNew,
            },
        };
        
        saveSettings(newSettings)
    end

    -- BUTTON
    if imgui.Button("Fetch data") then
        if fetchData() then
            readXML()
            clickFetch = true
        end
    end

    if clickFetch then
        imgui.SameLine()
        imgui.TextUnformatted(DataOfp["Status"])

        imgui.TextUnformatted("                                                  ")

        imgui.TextUnformatted("Airports:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%s - %s", DataOfp["OrigName"], DataOfp["DestName"]))

        imgui.TextUnformatted("Route:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%s/%s %s %s/%s", DataOfp["Origin"], DataOfp["OrigRwy"], DataOfp["Route"], DataOfp["Destination"], DataOfp["DestRwy"]))
        
        imgui.TextUnformatted("Distance:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d nm", DataOfp["Distance"]))

        imgui.TextUnformatted("Cruise Altitude:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d ft", DataOfp["Level"]))

        imgui.TextUnformatted("Elevations:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%s (%d ft) - %s (%d ft)", DataOfp["Origin"], DataOfp["Origlevation"], DataOfp["Destination"], DataOfp["DestElevation"]))

        imgui.TextUnformatted("                                                  ")

        imgui.TextUnformatted("Block Fuel:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d %s", DataOfp["RampFuel"], DataOfp["Units"]))

        imgui.TextUnformatted("Reserve fuel:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d %s", DataOfp["ReserveFuel"], DataOfp["Units"]))

        imgui.TextUnformatted("Minimum T/O fuel:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d %s", DataOfp["MinTakeoff"], DataOfp["Units"]))
        
        imgui.TextUnformatted("Payload:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d %s", DataOfp["Payload"], DataOfp["Units"]))

        imgui.TextUnformatted("Pax:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d", DataOfp["Pax"]))

        imgui.TextUnformatted("ZFW:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d", DataOfp["Zfw"]))

        imgui.TextUnformatted("                                                  ")

        imgui.TextUnformatted("Avg wind:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%03d/%03d", DataOfp["AvgWindDir"], DataOfp["AvgWindSpd"]))

        imgui.TextUnformatted("Avg ISA:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%03d", DataOfp["AvgTempDev"]))

        imgui.TextUnformatted("Cost Index:")
        imgui.SameLine()
        imgui.TextUnformatted(string.format("%d", DataOfp["CostIndex"]))

        imgui.TextUnformatted("                                                  ")

        imgui.TextUnformatted(string.format("%s", DataOfp["OrigMetar"]))

        imgui.TextUnformatted(string.format("%s", DataOfp["DestMetar"]))

    end

end


-- Open and close window from Lua menu

sb_wnd = nil

function sb_show_wnd()
    sb_wnd = float_wnd_create(650, 430, 1, true)
    float_wnd_set_title(sb_wnd, "Simbrief Helper")
    float_wnd_set_imgui_builder(sb_wnd, "sb_on_build")
    float_wnd_set_onclose(sb_wnd, "sb_hide_wnd")
end

function sb_hide_wnd()
    if sb_wnd then
        float_wnd_destroy(sb_wnd)
    end
end

sb_show_only_once = 0
sb_hide_only_once = 0

function toggle_simbrief_helper_interface()
	sb_show_window = not AI_show_window
	if sb_show_window then
		if sb_show_only_once == 0 then
			sb_show_wnd()
			sb_show_only_once = 1
			sb_hide_only_once = 0
		end
	else
		if sb_hide_only_once == 0 then
			sb_hide_wnd()
			sb_hide_only_once = 1
			sb_show_only_once = 0
		end
	end
end

add_macro("Simbrief Helper", "sb_show_wnd()", "sb_hide_wnd()", "deactivate")
create_command("FlyWithLua/SimbriefHelper/show_toggle", "open/close Simbrief Helper", "toggle_simbrief_helper_interface()", "", "")

