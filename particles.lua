local ffi, vector = require("ffi"), require("vector")
local screen_size, mouse_pos = vector(client.screen_size()), vector(ui.mouse_position())

local controls = {
    menu_particles = ui.new_checkbox("Misc", "Settings", "Menu Particles"),
    particle_color = ui.new_color_picker("Misc", "Settings", "Particle Color", 255, 221, 135, 200),
    particle_count = ui.new_slider("Misc", "Settings", "Particle Count", 10, 1000, 125),
    particle_side_drift = ui.new_slider("Misc", "Settings", "Particle Drift", 0, screen_size.x, 100),
    particle_random_alpha = ui.new_slider("Misc", "Settings", "Particle Randomized Alpha", 0, 100, 20),
    particle_min = ui.new_slider("Misc", "Settings", "Minimum Size", 1, 25, 3),
    particle_max = ui.new_slider("Misc", "Settings", "Maximum Size", 1, 25, 8),
    particle_speed_min = ui.new_slider("Misc", "Settings", "Minimum Speed", 1000, 25000, 2500),
    particle_speed_max = ui.new_slider("Misc", "Settings", "Maximum Speed", 1000, 25000, 7500),
    mouse_interaction = ui.new_checkbox("Misc", "Settings", "Mouse Interaction"),
    mouse_radius = ui.new_slider("Misc", "Settings", "Mouse Radius", 1, 250, 100),
}

local clux = client.unix_time
function client.unix_time()
    local s = clux() local a, b, c, d = client.system_time()
    return s * 1000 + d
end
local unix_time = client.unix_time()

local particle_table, particle_time_flush = {}, { flush = false, time = 0 }
local function regenerate_particle_table(type)
    local value = ui.get(controls.particle_count)
    
    if (type and type == 1) then
        if (#particle_table > value) then
            local remove_required = #particle_table - value

            for i = 1, remove_required do
                particle_table[#particle_table] = nil
            end
        end
    elseif (not type) then
        for i = #particle_table, 1, -1 do particle_table[i] = nil end
    end

    for i = 1, value - #particle_table do
        math.randomseed(unix_time + i)
        table.insert(particle_table, {size = math.random(ui.get(controls.particle_min), ui.get(controls.particle_max)), alpha = math.random(0, ui.get(controls.particle_random_alpha)), drift = math.random(-ui.get(controls.particle_side_drift), ui.get(controls.particle_side_drift)), speed = math.random(ui.get(controls.particle_speed_min), ui.get(controls.particle_speed_max)), x_pos = math.random(0, screen_size.x), time = unix_time, start = math.random(0, screen_size.y)})
    end
end

ui.set_callback(controls.particle_count, function() regenerate_particle_table(1) end)
ui.set_callback(controls.particle_min, function() regenerate_particle_table() end)
ui.set_callback(controls.particle_max, function() regenerate_particle_table() end)
ui.set_callback(controls.particle_speed_min, function() regenerate_particle_table() end)
ui.set_callback(controls.particle_speed_max, function() regenerate_particle_table() end)
ui.set_callback(controls.particle_side_drift, function() regenerate_particle_table() end)
ui.set_callback(controls.particle_random_alpha, function() regenerate_particle_table() end)

regenerate_particle_table()
client.set_event_callback("paint_ui", function()
    mouse_pos = vector(ui.mouse_position())
    unix_time = client.unix_time()

    if (ui.get(controls.menu_particles) and ui.is_menu_open()) then
        local r, g, b, a = ui.get(controls.particle_color)
        local mouse_interaction = ui.get(controls.mouse_interaction)
        local mouse_radius = ui.get(controls.mouse_radius)

        for i = 1, #particle_table do
            local control_a = a
            control_a = a - (a * ((particle_table[i].alpha) / 100))

            if (particle_time_flush.flush) then
                local time_difference = unix_time - particle_time_flush.time
                particle_table[i].time = particle_table[i].time + time_difference
            end

            local fall_percent = (unix_time - particle_table[i].time) / particle_table[i].speed
            local y_pos = screen_size.y * fall_percent + particle_table[i].start
            local x_pos = particle_table[i].x_pos + (particle_table[i].drift * fall_percent)

            if (fall_percent <= 1 and y_pos < screen_size.y and x_pos >= 0 and x_pos <= screen_size.x) then
                if (mouse_interaction) then
                    if (math.abs(y_pos - mouse_pos.y) <= mouse_radius) then
                        if (math.abs(x_pos - mouse_pos.x) <= mouse_radius) then
                            if (x_pos > mouse_pos.x) then
                                particle_table[i].x_pos = mouse_pos.x + mouse_radius - (particle_table[i].drift * fall_percent)
                            else
                                particle_table[i].x_pos = mouse_pos.x - mouse_radius - (particle_table[i].drift * fall_percent)
                            end
                        end
                    end
                end

                renderer.circle(x_pos, y_pos, r, g, b, control_a, particle_table[i].size, 0, 1)
            else
                math.randomseed(unix_time + i)
                particle_table[i].time, particle_table[i].start, particle_table[i].x_pos = unix_time, 0, math.random(0, screen_size.x)
            end
        end

        if (particle_time_flush.flush) then
            particle_time_flush.flush = false
        end
    else
        if (not particle_time_flush.flush) then
            particle_time_flush.flush, particle_time_flush.time = true, unix_time
        end
    end
end)
