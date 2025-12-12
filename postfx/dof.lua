local M = {}

M.enabled = true
M.focus_distance = 200
M.focus_range = 500
M.max_blur = 0.6
M.near_strength = 2.0
M.far_strength = 3.0
M.blur_version = 4

M.tint_enabled = false
M.tint_intensity = 0.75
M.tint_near_color = vmath.vector3(1.0, 0.2, 0.2)
M.tint_focus_color = vmath.vector3(0.2, 1.0, 0.2)
M.tint_far_color = vmath.vector3(0.2, 0.4, 1.0)

local function clamp_positive(value, fallback)
    if value and value > 0 then
        return value
    end
    return fallback
end

local function to_vec3(value, fallback)
    if value then
        if type(value) == "userdata" then
            return vmath.vector3(value)
        elseif type(value) == "table" then
            local x = value.x or value[1]
            local y = value.y or value[2]
            local z = value.z or value[3]
            if x and y and z then
                return vmath.vector3(x, y, z)
            end
        end
    end
    return fallback
end

function M.set_enabled(value)
    if value == nil then
        return
    end
    M.enabled = value and true or false
end

function M.set_focus(distance, range)
    if distance then
        M.focus_distance = math.max(0.0, distance)
    end
    if range then
        M.focus_range = clamp_positive(range, 0.01)
    end
end

function M.set_strengths(near_multiplier, far_multiplier)
    if near_multiplier then
        M.near_strength = near_multiplier
    end
    if far_multiplier then
        M.far_strength = far_multiplier
    end
end

function M.set_max_blur(value)
    if value then
        M.max_blur = clamp_positive(value, 0.1)
    end
end

function M.set_blur_version(value)
    value = tonumber(value)
    if not value then
        return
    end
    if value < 1 then value = 1 end
    if value > 6 then value = 6 end
    M.blur_version = math.floor(value)
    if M.blur_version == 6 then
        M.enabled = false
    else
        M.enabled = true
    end
end

function M.set_tint(options)
    if not options then
        return
    end
    if options.enabled ~= nil then
        M.tint_enabled = options.enabled and true or false
    end
    if options.intensity then
        M.tint_intensity = math.max(0, options.intensity)
    end
    if options.near_color then
        M.tint_near_color = to_vec3(options.near_color, M.tint_near_color)
    end
    if options.focus_color then
        M.tint_focus_color = to_vec3(options.focus_color, M.tint_focus_color)
    end
    if options.far_color then
        M.tint_far_color = to_vec3(options.far_color, M.tint_far_color)
    end
end

function M.get_uniforms()
    local focus_range = clamp_positive(M.focus_range, 0.01)
    local focus_params = vmath.vector4(M.focus_distance, focus_range, M.max_blur, M.near_strength)
    local misc_params = vmath.vector4(M.far_strength, 0, 0, 0)
    local effect_enabled = M.enabled and M.blur_version ~= 6
    local tint_control = vmath.vector4(M.tint_intensity, M.tint_enabled and 1 or 0, 0, 0)
    local tint_near = vmath.vector4(M.tint_near_color.x, M.tint_near_color.y, M.tint_near_color.z, 0)
    local tint_focus = vmath.vector4(M.tint_focus_color.x, M.tint_focus_color.y, M.tint_focus_color.z, 0)
    local tint_far = vmath.vector4(M.tint_far_color.x, M.tint_far_color.y, M.tint_far_color.z, 0)
    return {
        enabled = effect_enabled,
        focus = focus_params,
        misc = misc_params,
        blur_version = M.blur_version,
        tint_control = tint_control,
        tint_near = tint_near,
        tint_focus = tint_focus,
        tint_far = tint_far,
    }
end

return M
