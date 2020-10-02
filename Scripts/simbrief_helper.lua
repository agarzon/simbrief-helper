-- Simbrief helper
-- Alexander Garzon Jan - 2020

-- Description: It gets your OFP data from simbrief (after you generate your flight plan) using your username (API call), in order to display
-- variables like flight level, block fuel, payload, zfw, destination altitude, metar, etc..

-- TODO:
-- * Get RWY magnetic heading

-- Modules
local xml2lua = require("xml2lua")
local handler = require("xmlhandler.tree")

-- Replace mbox.print() with print()
-- require("mbox")
-- print = mbox.print

-- Useful debug tool
-- local inspect = require 'inspect'

-- Variables
local socket = require "socket"
local http = require "socket.http"
local LIP = require("LIP");

local SettingsFile = "simbrief_helper.ini"
local SimbriefXMLFile = "simbrief.xml"
local sbUser = ""
local fontBig = false

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
  --do return end -- stop
  if sbUser == nil then
    logMsg("No simbrief username has been configured")
    return false
  end

  -- It would be nice to have a try-cath here
  local webRespose, webStatus = http.request("http://www.simbrief.com/api/xml.fetcher.php?username=" .. sbUser)

  if webStatus ~= 200 then
    logMsg("Simbrief API is not responding OK")
    return false
  end

  local f = io.open(SCRIPT_DIRECTORY..SimbriefXMLFile, "w")
  f:write(webRespose)
  f:close()

  logMsg("Simbrief XML data downloaded")
  return true
end

function readXML()
  -- New XML parser
  local xfile = xml2lua.loadFile(SCRIPT_DIRECTORY..SimbriefXMLFile)
  local parser = xml2lua.parser(handler)
  parser:parse(xfile)

  DataOfp["Status"] = handler.root.OFP.fetch.status

  if DataOfp["Status"] ~= "Success" then
    logMsg("XML status is not success")
    return false
  end

  DataOfp["Origin"] = handler.root.OFP.origin.icao_code
  DataOfp["Origlevation"] = handler.root.OFP.origin.elevation
  DataOfp["OrigName"] = handler.root.OFP.origin.name
  DataOfp["OrigRwy"] = handler.root.OFP.origin.plan_rwy
  DataOfp["OrigMetar"] = handler.root.OFP.weather.orig_metar

  DataOfp["Destination"] = handler.root.OFP.destination.icao_code
  DataOfp["DestElevation"] = handler.root.OFP.destination.elevation
  DataOfp["DestName"] = handler.root.OFP.destination.name
  DataOfp["DestRwy"] = handler.root.OFP.destination.plan_rwy
  DataOfp["DestMetar"] = handler.root.OFP.weather.dest_metar

  DataOfp["Cpt"] = handler.root.OFP.crew.cpt
  DataOfp["Callsign"] = handler.root.OFP.atc.callsign
  DataOfp["Aircraft"] = handler.root.OFP.aircraft.name
  DataOfp["Units"] = handler.root.OFP.params.units
  DataOfp["Distance"] = handler.root.OFP.general.route_distance
  DataOfp["Ete"] = handler.root.OFP.times.est_time_enroute
  DataOfp["Route"] = handler.root.OFP.general.route
  DataOfp["Level"] = handler.root.OFP.general.initial_altitude
  DataOfp["RampFuel"] = (math.ceil(handler.root.OFP.fuel.plan_ramp/100) * 100)
  DataOfp["MinTakeoff"] = handler.root.OFP.fuel.min_takeoff
  DataOfp["ReserveFuel"] = handler.root.OFP.fuel.reserve
  DataOfp["Cargo"] = handler.root.OFP.weights.cargo
  DataOfp["Pax"] = handler.root.OFP.weights.pax_count
  DataOfp["Payload"] = handler.root.OFP.weights.payload
  DataOfp["Zfw"] = (handler.root.OFP.weights.est_zfw / 1000)
  DataOfp["CostIndex"] = handler.root.OFP.general.costindex

  -- find TOC
  local iTOC = 1
  while handler.root.OFP.navlog.fix[iTOC].ident ~= "TOC" do
    iTOC = iTOC + 1
  end

  DataOfp["CrzWindDir"] = handler.root.OFP.navlog.fix[iTOC].wind_dir
  DataOfp["CrzWindSpd"] = handler.root.OFP.navlog.fix[iTOC].wind_spd
  DataOfp["CrzTemp"] = handler.root.OFP.navlog.fix[iTOC].oat
  DataOfp["CrzTempDev"] = handler.root.OFP.navlog.fix[iTOC].oat_isa_dev

  return true
end

function timeConvert(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "no data";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    return hours..":"..mins
  end
end

function sb_on_build(sb_wnd, x, y)
  if fontBig == true then
    imgui.SetWindowFontScale(1.2)
  else
    imgui.SetWindowFontScale(1)
  end

  if DataOfp["Cpt"] == nil then
    imgui.TextUnformatted(string.format("Enter your simbrief username below and then click the button."))
  else
    imgui.TextUnformatted(string.format("Welcome, %s (%s)", DataOfp["Cpt"], DataOfp["Callsign"]))
  end

  if imgui.TreeNode("Settings") then
    -- INPUT
    local changed, userNew = imgui.InputText("Simbrief Username", sbUser, 255)

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

    local fontChanged, fontNewVal = imgui.Checkbox("Use bigger font size", fontBig)
    if fontChanged then
      fontBig = fontNewVal
    end
    imgui.TreePop()
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

    imgui.TextUnformatted(string.format("Aircraft:         %s", DataOfp["Aircraft"]))
    imgui.TextUnformatted(string.format("Airports:         %s - %s", DataOfp["OrigName"], DataOfp["DestName"]))
    imgui.TextUnformatted(string.format("Route:            %s/%s %s %s/%s", DataOfp["Origin"], DataOfp["OrigRwy"], DataOfp["Route"], DataOfp["Destination"], DataOfp["DestRwy"]))
    imgui.TextUnformatted(string.format("Distance:         %d nm", DataOfp["Distance"]))
    imgui.SameLine()
    imgui.TextUnformatted(string.format("ETE: %s", timeConvert(DataOfp["Ete"])))
    imgui.TextUnformatted(string.format("Cruise Altitude:  %d ft", DataOfp["Level"]))
    imgui.TextUnformatted(string.format("Elevations:       %s (%d ft) - %s (%d ft)", DataOfp["Origin"], DataOfp["Origlevation"], DataOfp["Destination"], DataOfp["DestElevation"]))

    imgui.TextUnformatted("                                                  ")
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFFF00)
    imgui.TextUnformatted(string.format("Block Fuel:       %d %s", DataOfp["RampFuel"], DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Reserve fuel:     %d %s", DataOfp["ReserveFuel"], DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Takeoff fuel:     %d %s", DataOfp["MinTakeoff"], DataOfp["Units"]))
    imgui.PopStyleColor()

    imgui.TextUnformatted(string.format("Cargo:            %d %s", DataOfp["Cargo"], DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Pax:              %d", DataOfp["Pax"]))
    imgui.TextUnformatted(string.format("Payload:          %d %s", DataOfp["Payload"], DataOfp["Units"]))
    imgui.TextUnformatted(string.format("ZFW:              %02.1f", DataOfp["Zfw"]))
    imgui.TextUnformatted(string.format("Cost Index:       %d", DataOfp["CostIndex"]))

    imgui.TextUnformatted("                                                  ")
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00)
    imgui.TextUnformatted(string.format("TOC Wind:        %03d/%03d", DataOfp["CrzWindDir"], DataOfp["CrzWindSpd"]))
    imgui.TextUnformatted(string.format("TOC Temp:        %03d C", DataOfp["CrzTemp"]))
    imgui.TextUnformatted(string.format("TOC ISA Dev:     %03d C", DataOfp["CrzTempDev"]))
    imgui.PopStyleColor()

    imgui.TextUnformatted("                                                  ")
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00BFFF)
    imgui.TextUnformatted(string.format("%s", DataOfp["OrigMetar"]))
    imgui.TextUnformatted(string.format("%s", DataOfp["DestMetar"]))
    imgui.PopStyleColor()
  end

end

-- Open and close window from Lua menu

sb_wnd = nil

function sb_show_wnd()
  readSettings() -- It should read only once
  sb_wnd = float_wnd_create(650, 550, 1, true)
  --float_wnd_set_imgui_font(sb_wnd, 2)
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
  sb_show_window = not sb_show_window
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
