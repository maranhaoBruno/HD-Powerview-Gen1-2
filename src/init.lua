--[[
  Copyright 2022 Bruno Maranhao

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  Power View Shade Driver for LAN-based Generation 1 & 2 Hub devices

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"                 -- just for time
local socket = require "cosock.socket"          -- just for time
local json  = require "json"
local http  = require "socket.http"
local ltn12 = require "ltn12"
local log = require "log"

-- Custom Capabiities
local capdefs = require "capabilitydefs"
capabilities["partyvoice23922.createanother"] = cap_createdev
capabilities["clevercenter17261.calibrate"] = cap_calibrate
capabilities["clevercenter17261.jog"] = cap_jog

-- Module variables
local thisDriver = {}
local initialized = false

function sendCommand(hubIP, shadeID, payload)
  local request_body = json.encode(payload)
  local response_body = {}

  local url = "http://" .. hubIP .. "/api/shades/" .. shadeID
  local res, code, response_headers = http.request{
    url = url,
    method = "PUT",
    headers =
    {
      ["Content-Type"] = "application/json";
      ["Content-Length"] = #request_body;
    },
      source = ltn12.source.string(request_body),
      sink = ltn12.sink.table(response_body),
    }
end

local function jog() -- the function activated by a momentary button in the shade device titled "Jog"
  payload = {shade = {motion = "jog"}}
  sendCommand(device.preferences.hubIP, device.preferences.shadeID, payload)
end

local function calibrate() -- the function activated by a momentary button in the shade device titled "Calibrate"
  payload = {shade = {motion = "calibrate"}}
  sendCommand(device.preferences.hubIP, device.preferences.shadeID, payload)
end

local function setShadeLevel(shadeLevel) -- the function activated by a dimmer in the shade device titled "Position"
  positionN = (65535*shadeLevel/100)//1
  payload = {shade = {positions = {posKind1 = 1, position1 = positionN}}}
  sendCommand(device.preferences.hubIP, device.preferences.shadeID, payload)
  device:emit_event(capabilities.windowShadeLevel.shadeLevel(shadeLevel))
  if shadeLevel == 0 then
    device:emit_event(capabilities.windowShade.windowShade('closed'))
  else
    device:emit_event(capabilities.windowShade.windowShade('open'))
  end
end

local function open() -- the function activated by selecting Open in the shade device
  setShadeLevel(100)
end

local function close() -- the function activated by selecting Close in the shade device
  setShadeLevel(0)
end

local function create_device(driver)

  local MFG_NAME = 'SmartThings Community'
  local MODEL = 'PowerView Shade'
  local VEND_LABEL = 'PowerView Shade'
  local ID = 'PowerViewShade_' .. socket.gettime()
  local PROFILE = 'powerViewShade.v1'

  log.info (string.format('Creating new device: label=<%s>, id=<%s>', VEND_LABEL, ID))

  local create_device_msg = {
                              type = "LAN",
                              device_network_id = ID,
                              label = VEND_LABEL,
                              profile = PROFILE,
                              manufacturer = MFG_NAME,
                              model = MODEL,
                              vendor_provided_label = VEND_LABEL,
                            }
                      
  assert (driver:try_create_device(create_device_msg), "failed to create device")

end

-- CAPABILITY HANDLERS

local function handle_calibrate(driver, device, command)

  calibrate()

end

local function handle_jog(driver, device, command)

  jog()

end

local function handle_createdev(driver, device, command)

  create_device(driver)

end

------------------------------------------------------------------------
--                REQUIRED EDGE DRIVER HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
    log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")
  
    log.debug('Exiting device initialization')
end


-- Called when device was just created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")
  
  device:emit_event(capabilities.windowShade.windowShade('unknown'))
  device:emit_event(capabilities.windowShadeLevel.shadeLevel(0))
  
  initialized = true
 
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  log.info ('Device doConfigure lifecycle invoked')

end


-- Called when device was deleted via mobile app
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  local device_list = driver:get_devices()
  
  if #device_list == 0 then
    log.warn ('All devices removed; driver disabled')
  end
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

end


-- Create Initial Device
local function discovery_handler(driver, _, should_continue)
  
  log.debug("Device discovery invoked")
  
  if not initialized then
    create_device(driver)
  end
  
  log.debug("Exiting discovery")
  
end


-----------------------------------------------------------------------
--        DRIVER MAINLINE: Build driver context table
-----------------------------------------------------------------------
thisDriver = Driver("thisDriver", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    driverSwitched = handler_driverchanged,
    infoChanged = handler_infochanged,
    doConfigure = device_doconfigure,
    removed = device_removed
  },
  
  capability_handlers = {
    [cap_calibrate.ID] = {
      [cap_calibrate.commands.push.NAME] = handle_calibrate,
    },
    [cap_jog.ID] = {
      [cap_jog.commands.push.NAME] = handle_jog,
    },
    [cap_createdev.ID] = {
      [cap_createdev.commands.push.NAME] = handle_createdev,
    },
  }
})

log.info ('HD PowerView Shade Gen 1 or 2 v1.0 Started')


thisDriver:run()
