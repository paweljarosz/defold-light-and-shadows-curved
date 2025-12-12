local M = {}

-- Convert a rotation matrix to a quaternion (assumes no scaling/shearing).
local function quat_from_matrix(m)
    local trace = m.c0.x + m.c1.y + m.c2.z
    local q
    if trace > 0 then
        local s = math.sqrt(trace + 1.0) * 2
        local invs = 1 / s
        q = vmath.quat(
            (m.c2.y - m.c1.z) * invs,
            (m.c0.z - m.c2.x) * invs,
            (m.c1.x - m.c0.y) * invs,
            0.25 * s
        )
    elseif m.c0.x > m.c1.y and m.c0.x > m.c2.z then
        local s = math.sqrt(1.0 + m.c0.x - m.c1.y - m.c2.z) * 2
        local invs = 1 / s
        q = vmath.quat(
            0.25 * s,
            (m.c0.y + m.c1.x) * invs,
            (m.c0.z + m.c2.x) * invs,
            (m.c2.y - m.c1.z) * invs
        )
    elseif m.c1.y > m.c2.z then
        local s = math.sqrt(1.0 + m.c1.y - m.c0.x - m.c2.z) * 2
        local invs = 1 / s
        q = vmath.quat(
            (m.c0.y + m.c1.x) * invs,
            0.25 * s,
            (m.c1.z + m.c2.y) * invs,
            (m.c0.z - m.c2.x) * invs
        )
    else
        local s = math.sqrt(1.0 + m.c2.z - m.c0.x - m.c1.y) * 2
        local invs = 1 / s
        q = vmath.quat(
            (m.c0.z + m.c2.x) * invs,
            (m.c1.z + m.c2.y) * invs,
            0.25 * s,
            (m.c1.x - m.c0.y) * invs
        )
    end
    return q
end

local function quat_to_matrix(q)
    local x, y, z, w = q.x, q.y, q.z, q.w
    local xx, yy, zz = x * x, y * y, z * z
    local xy, xz, yz = x * y, x * z, y * z
    local wx, wy, wz = w * x, w * y, w * z

    local m = vmath.matrix4()
    m.c0 = vmath.vector4(1 - 2 * (yy + zz), 2 * (xy + wz), 2 * (xz - wy), 0)
    m.c1 = vmath.vector4(2 * (xy - wz), 1 - 2 * (xx + zz), 2 * (yz + wx), 0)
    m.c2 = vmath.vector4(2 * (xz + wy), 2 * (yz - wx), 1 - 2 * (xx + yy), 0)
    m.c3 = vmath.vector4(0, 0, 0, 1)
    return m
end

local function quat_slerp(t, q0, q1)
    local cosTheta = q0.x * q1.x + q0.y * q1.y + q0.z * q1.z + q0.w * q1.w
    if cosTheta < 0 then
        q1 = vmath.quat(-q1.x, -q1.y, -q1.z, -q1.w)
        cosTheta = -cosTheta
    end
    if cosTheta > 0.9995 then
        -- Quats are almost the same; fall back to linear blend then normalize.
        local q = vmath.quat(
            q0.x + t * (q1.x - q0.x),
            q0.y + t * (q1.y - q0.y),
            q0.z + t * (q1.z - q0.z),
            q0.w + t * (q1.w - q0.w)
        )
        local len = math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
        return vmath.quat(q.x / len, q.y / len, q.z / len, q.w / len)
    end

    local theta = math.acos(cosTheta)
    local sinTheta = math.sin(theta)
    local w0 = math.sin((1 - t) * theta) / sinTheta
    local w1 = math.sin(t * theta) / sinTheta
    return vmath.quat(
        q0.x * w0 + q1.x * w1,
        q0.y * w0 + q1.y * w1,
        q0.z * w0 + q1.z * w1,
        q0.w * w0 + q1.w * w1
    )
end

function M.init(self)
    self.skybox_pred = render.predicate({"skybox"})
    self.skybox_rot_strength = -0.85
    self.skybox_pitch_deg = -4
    self.skybox_offset = vmath.vector4(0, 200, 0, 0)
    self.skybox_cb = render.constant_buffer()
end

function M.draw(self, view, proj)
    if not self.skybox_pred then
        return
    end
    if not (view and proj) then
        return
    end
    -- Blend between identity and view rotation (inverse camera) so the skybox follows the camera.
    local strength = self.skybox_rot_strength or 0
    local view_rot = vmath.matrix4()
    view_rot.c0 = view.c0
    view_rot.c1 = view.c1
    view_rot.c2 = view.c2
    view_rot.c3 = vmath.vector4(0, 0, 0, 1)
    local view_quat = quat_from_matrix(view_rot)
    local blended_quat = quat_slerp(strength, vmath.quat(), view_quat)
    local blended_rot = quat_to_matrix(blended_quat)
    local pitch_rad = math.rad(self.skybox_pitch_deg or 0)
    local tilt_rot = quat_to_matrix(vmath.quat_rotation_x(pitch_rad))
    local final_rot = blended_rot * tilt_rot

    -- Temporarily replace view and projection only for skybox rendering.
    render.set_view(final_rot)
    render.set_projection(proj)
    render.set_depth_mask(false)
    render.disable_state(render.STATE_DEPTH_TEST)
    render.disable_state(render.STATE_CULL_FACE) -- draw both sides; cube is viewed from inside
    -- Offset cubemap lookup
    self.skybox_cb.sky_offset = self.skybox_offset

    render.set_depth_func(render.COMPARE_FUNC_LEQUAL)
    render.draw(self.skybox_pred, { constants = self.skybox_cb })
    render.set_depth_func(render.COMPARE_FUNC_LESS)
    render.enable_state(render.STATE_DEPTH_TEST)
    render.set_depth_mask(true)

    -- Bring back the original view and projection.
    render.set_view(view)
    render.set_projection(proj)
end

return M
