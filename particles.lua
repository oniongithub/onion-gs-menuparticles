local vector, ffi, bit = require("vector"), require("ffi"), require("bit")
local screen_size, mouse_pos = vector(client.screen_size()), vector(ui.mouse_position())

local surfaceTable = ffi.cast(ffi.typeof("void***"), client.create_interface("vguimatsurface.dll", "VGUI_Surface031"))
local drawSetColor = ffi.cast(ffi.typeof("void(__thiscall*)(void*, int, int, int, int)"), surfaceTable[0][15])
local drawOutlinedCircle = ffi.cast(ffi.typeof("void(__thiscall*)(void*, int, int, int, int)"), surfaceTable[0][103])

function renderer.outlined_circle(x, y, r, g, b, a, radius, segments)
    drawSetColor(surfaceTable, r, g, b, a)
    drawOutlinedCircle(surfaceTable, x, y, radius, segments)
end

function renderer.filled_circle(x, y, r, g, b, a, radius, segments)
    local per_angle, last_pos_x, last_pos_y = 360 / segments

    for i = 0, segments do
        if (i * per_angle <= 360) then
            local cur_pos_x, cur_pos_y, current_angle = nil, nil, math.rad(i * per_angle)

            if (not last_pos_x or not last_pos_y) then
                last_pos_x, last_pos_y = radius * math.cos(current_angle) + x, radius * math.sin(current_angle) + y
            else
                cur_pos_x, cur_pos_y = radius * math.cos(current_angle) + x, radius * math.sin(current_angle) + y;          
                renderer.triangle(last_pos_x, last_pos_y, cur_pos_x, cur_pos_y, x, y, r, g, b, a)
                last_pos_x, last_pos_y = cur_pos_x, cur_pos_y
            end
        end
    end
end

local controls = {
    menu_particles = ui.new_checkbox("Misc", "Settings", "Menu Particles"),
    particle_color = ui.new_color_picker("Misc", "Settings", "Particle Color", 255, 221, 135, 200),
    particle_fps = ui.new_slider("Misc", "Settings", "Particle Optimization", 1, 3, 2),
    particle_count = ui.new_slider("Misc", "Settings", "Particle Count", 10, 1000, 125),
    particle_side_drift = ui.new_slider("Misc", "Settings", "Particle Drift", 0, screen_size.x, 100),
    particle_random_alpha = ui.new_slider("Misc", "Settings", "Particle Randomized Alpha", 0, 100, 20),
    particle_min = ui.new_slider("Misc", "Settings", "Minimum Size", 1, 25, 3),
    particle_max = ui.new_slider("Misc", "Settings", "Maximum Size", 1, 25, 8),
    particle_speed_min = ui.new_slider("Misc", "Settings", "Minimum Speed", 1000, 25000, 2500),
    particle_speed_max = ui.new_slider("Misc", "Settings", "Maximum Speed", 1000, 25000, 7500),
    particle_connection = ui.new_checkbox("Misc", "Settings", "Particle Connection"),
    particle_connection_radius = ui.new_slider("Misc", "Settings", "Connection Radius", 1, screen_size.x, 100),
    particle_connection_color = ui.new_color_picker("Misc", "Settings", "Connection Color", 255, 221, 135, 200),
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
        local c_r, c_g, c_b, c_a = ui.get(controls.particle_connection_color)
        local mouse_interaction = ui.get(controls.mouse_interaction)
        local mouse_radius = ui.get(controls.mouse_radius)
        local particle_connection = ui.get(controls.particle_connection)
        local particle_connection_radius = ui.get(controls.particle_connection_radius)

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

                if (particle_connection) then
                    for f = i, #particle_table do
                        if (f ~= i) then
                            local fall_percent_2 = (unix_time - particle_table[f].time) / particle_table[f].speed
                            local y_pos_2 = screen_size.y * fall_percent_2 + particle_table[f].start
                            local x_pos_2 = particle_table[f].x_pos + (particle_table[f].drift * fall_percent_2)

                            if (math.sqrt((x_pos - x_pos_2)^2 + (y_pos - y_pos_2)^2) <= particle_connection_radius) then
                                renderer.line(x_pos, y_pos, x_pos_2, y_pos_2, c_r, c_g, c_b, c_a)
                            end
                        end
                    end
                end

                local segments = 8 if (particle_table[i].size >= 4 and particle_table[i].size <= 6) then segments = particle_table[i].size + 2 end

                local fps_mode = ui.get(controls.particle_fps)
                if (fps_mode == 1) then
                    renderer.circle(x_pos, y_pos, r, g, b, control_a, particle_table[i].size, 0, 1)
                elseif (fps_mode == 2) then
                    renderer.filled_circle(x_pos, y_pos, r, g, b, control_a, particle_table[i].size, segments)
                else
                    renderer.outlined_circle(x_pos, y_pos, r, g, b, control_a, particle_table[i].size, segments)
                end
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
