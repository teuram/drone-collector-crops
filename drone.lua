
local drone = component.proxy(component.list("drone")())
local modem = component.proxy(component.list("modem")())
local eeprom = component.proxy(component.list("eeprom")())
local interweb = component.proxy(component.list("internet")())
local fwaddress = "https://raw.githubusercontent.com/teuram/drone-collector-crops/main/drone.lua"

local port = 60

local offset = { x = 0, y = 0 }

local storage = {}
local area = {
    start = {}, endd = {}
}

function copy_table(t)
    local t1 = {}
    for k, v in pairs(t) do t1[k] = v end
    return t1
end

function move(x, z)
    drone.move(x, 0, z)
    offset.x = offset.x + x
    offset.z = offset.z + z
end

function set_pos(x, z)
    local dx = x - offset.x
    local dz = z - offset.z
    move(dx, dz)
end

function run()
    modem.open(port)
    while true do
        local evt, _, sender, port, _, cmd, a, b, c, d = computer.pullSignal()
        if evt == "modem_message" then

            if cmd == "update" then
                local web_request = interweb.request(fwaddress)
                web_request.finishConnect()
                local full_response = ""
                while true do
                    local chunk = web_request.read()
                    if chunk then
                        str.gsub(chunk, "\r\n", "\n")
                        full_response = full_response .. chunk
                    else
                        break
                    end
                end
                eeprom.set(full_response)
            end
            if cmd == "set_storage" then
                storage = copy_table(offset)
            end
            if cmd == "set_area_start" then
                area.start = copy_table(offset)
            end
            if cmd == "set_area_end" then
                area.endd = copy_table(offset)
            end

            if cmd == "move" then
                move(a, b)
            end
            if cmd == "crop" then
                crop()
            end
            if cmd == "shutdown" then
                set_pos(0, 0)
                drop_inventory()
                modem.close(port)
                computer.shutdown(false)
            end
        end
    end
end

function check_overflow_inventory(procent)
    local inventory_size = drone.inventorySize()
    local overflow = 0
    for i = 1, inventory_size, 1 do
        drone.select(i)
        overflow = overflow + (drone.count() / (drone.count() + drone.space()))
    end
    return overflow > (inventory_size * (procent / 100))
end

function drop_inventory()
    local old = copy_table(offset)
    set_pos(storage.x, storage.z)
    computer.pullSignal(5)

    local inventory_size = drone.inventorySize()
    for i = 1, inventory_size, 1 do
        drone.select(i)
        drone.drop(0, drone.count() + drone.space())
    end
    set_pos(old.x, old.z)
    computer.pullSignal(5)
end

function inventory()
    if check_overflow_inventory(80) then drop_inventory() end
end

function crop()
    local dx = area.endd.x - area.start.x
    local dz = area.endd.z - area.start.z

    local norm = {}
    norm.x = dx > 0 and 1 or -1
    norm.z = dz > 0 and 1 or -1

    for x = area.start.x, area.endd.x, norm.x do
        for z = area.start.z, area.endd.z, norm.z do
            set_pos(x, z)
            computer.pullSignal(0.5)
            drone.use(0, false)
            computer.pullSignal(0.4)
            inventory()
        end
        area.start.z, area.endd.z = area.endd.z, area.start.z
        norm.z = -norm.z
    end
end

run()
