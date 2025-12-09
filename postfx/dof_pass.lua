local dof = require "postfx.dof"
local rendercam = require "rendercam.rendercam"

local M = {}

local IDENTITY_MATRIX = vmath.matrix4()
local SET_DOF = hash("set_dof")

local function delete_target(target)
    if target then
        render.delete_render_target(target)
    end
end

local function clamp_depth_range(near_z, far_z)
    near_z = near_z or 0.1
    far_z = far_z or (near_z + 1000.0)
    if near_z < 0.0001 then
        near_z = 0.1
    end
    if far_z - near_z < 0.01 then
        far_z = near_z + 0.01
    end
    return near_z, far_z
end

local function setup_postfx_targets(self)
    local width = math.floor(rendercam.window.x + 0.5)
    local height = math.floor(rendercam.window.y + 0.5)
    if width <= 0 or height <= 0 then
        return
    end
    if self.scene_rt and self.scene_width == width and self.scene_height == height then
        return
    end
    delete_target(self.scene_rt)
    delete_target(self.scene_depth_rt)
    delete_target(self.dof_prefilter_rt)
    delete_target(self.dof_blur_rt)

    local color_params = {
        format = render.FORMAT_RGBA16F,
        width = width,
        height = height,
        min_filter = render.FILTER_LINEAR,
        mag_filter = render.FILTER_LINEAR,
        u_wrap = render.WRAP_CLAMP_TO_EDGE,
        v_wrap = render.WRAP_CLAMP_TO_EDGE,
    }
    local depth_params = {
        format = render.FORMAT_DEPTH,
        width = width,
        height = height,
        min_filter = render.FILTER_NEAREST,
        mag_filter = render.FILTER_NEAREST,
        u_wrap = render.WRAP_CLAMP_TO_EDGE,
        v_wrap = render.WRAP_CLAMP_TO_EDGE,
    }
    self.scene_rt = render.render_target("scene_buffer", {
        [render.BUFFER_COLOR_BIT] = color_params,
        [render.BUFFER_DEPTH_BIT] = depth_params
    })
    local depth_color_params = {
        format = render.FORMAT_R32F,
        width = width,
        height = height,
        min_filter = render.FILTER_LINEAR,
        mag_filter = render.FILTER_LINEAR,
        u_wrap = render.WRAP_CLAMP_TO_EDGE,
        v_wrap = render.WRAP_CLAMP_TO_EDGE,
    }
    local depth_depth_params = {
        format = render.FORMAT_DEPTH,
        width = width,
        height = height,
        min_filter = render.FILTER_NEAREST,
        mag_filter = render.FILTER_NEAREST,
        u_wrap = render.WRAP_CLAMP_TO_EDGE,
        v_wrap = render.WRAP_CLAMP_TO_EDGE,
    }
    self.scene_depth_rt = render.render_target("scene_depth_buffer", {
        [render.BUFFER_COLOR_BIT] = depth_color_params,
        [render.BUFFER_DEPTH_BIT] = depth_depth_params
    })

    local half_w = math.max(1, math.floor(width * 0.5))
    local half_h = math.max(1, math.floor(height * 0.5))
    local prefilter_params = {
        format = render.FORMAT_RGBA16F,
        width = half_w,
        height = half_h,
        min_filter = render.FILTER_LINEAR,
        mag_filter = render.FILTER_LINEAR,
        u_wrap = render.WRAP_CLAMP_TO_EDGE,
        v_wrap = render.WRAP_CLAMP_TO_EDGE,
    }
    local blur_params = {
        format = render.FORMAT_RGBA16F,
        width = half_w,
        height = half_h,
        min_filter = render.FILTER_LINEAR,
        mag_filter = render.FILTER_LINEAR,
        u_wrap = render.WRAP_CLAMP_TO_EDGE,
        v_wrap = render.WRAP_CLAMP_TO_EDGE,
    }
    self.dof_prefilter_rt = render.render_target("dof_prefilter_buffer", {
        [render.BUFFER_COLOR_BIT] = prefilter_params,
    })
    self.dof_blur_rt = render.render_target("dof_blur_buffer", {
        [render.BUFFER_COLOR_BIT] = blur_params,
    })

    self.scene_width = width
    self.scene_height = height
    self.dof_half_width = half_w
    self.dof_half_height = half_h
    if self.simple_blur_cb then
        self.simple_blur_cb.texel_size = vmath.vector4(1 / width, 1 / height, 0, 0)
    end
end

function M.update_window(self)
    setup_postfx_targets(self)
end

function M.init(self)
    self.dof_prefilter_cb = render.constant_buffer()
    self.dof_blur_cb = render.constant_buffer()
    self.dof_composite_cb = render.constant_buffer()
    self.simple_blur_cb = render.constant_buffer()
    self.post_pred = render.predicate({"postfx"})
end

function M.update_uniforms(self)
    if not (self.scene_width and self.scene_height and self.dof_half_width and self.dof_half_height) then
        return
    end
    local uniforms = dof.get_uniforms()
    local enabled = uniforms.enabled
    local focus_params = uniforms.focus
    local misc_params = uniforms.misc
    self.blur_version = uniforms.blur_version or 1
    local simple_mode = self.blur_version == 1
    local near_z, far_z = rendercam.get_depth_params()
    near_z, far_z = clamp_depth_range(near_z, far_z)

    local full_texel = vmath.vector4(1 / self.scene_width, 1 / self.scene_height, self.scene_width, self.scene_height)
    local half_texel = vmath.vector4(1 / self.dof_half_width, 1 / self.dof_half_height, self.dof_half_width, self.dof_half_height)
    local depth_params = vmath.vector4(near_z, far_z, 0, 0)
    local depth_blur_enabled = enabled and not simple_mode
    local enable_params = vmath.vector4(depth_blur_enabled and 1 or 0, 0, 0, (enabled and simple_mode) and 1 or 0)

    self.dof_prefilter_cb.focus_params = focus_params
    self.dof_prefilter_cb.misc_params = misc_params
    self.dof_prefilter_cb.depth_params = depth_params
    self.dof_prefilter_cb.texel_size = full_texel

    self.dof_blur_cb.focus_params = focus_params
    self.dof_blur_cb.blur_params = half_texel

    self.dof_composite_cb.focus_params = focus_params
    self.dof_composite_cb.misc_params = misc_params
    self.dof_composite_cb.depth_params = depth_params
    self.dof_composite_cb.enable_params = enable_params
    self.dof_composite_cb.tint_control = uniforms.tint_control
    self.dof_composite_cb.tint_near = uniforms.tint_near
    self.dof_composite_cb.tint_focus = uniforms.tint_focus
    self.dof_composite_cb.tint_far = uniforms.tint_far

    self.dof_enabled = enabled
    self.depth_blur_enabled = depth_blur_enabled
    self.simple_blur_mode = enabled and simple_mode
end

function M.render_depth_pass(self, options)
    if not (self.scene_depth_rt and self.depth_blur_enabled) then
        return
    end

    render.set_render_target(self.scene_depth_rt)
    render.set_viewport(rendercam.viewport.x, rendercam.viewport.y, rendercam.viewport.width, rendercam.viewport.height)
    render.set_view(self.view)
    render.set_projection(self.proj)
    render.set_depth_func(render.COMPARE_FUNC_LESS)
    render.set_depth_mask(true)
    render.enable_state(render.STATE_DEPTH_TEST)
    render.enable_state(render.STATE_CULL_FACE)
    render.clear({ [render.BUFFER_COLOR_BIT] = vmath.vector4(1, 1, 1, 1), [render.BUFFER_DEPTH_BIT] = 1 })

    render.enable_material("dof_model_depth")
    render.draw(self.model_pred, options)
    render.disable_material()

    render.disable_state(render.STATE_CULL_FACE)
    render.enable_material("dof_sprite_depth")
    render.draw(self.atile_pred, options)
    render.draw(self.tile_pred, options)
    render.draw(self.btile_pred, options)
    render.disable_material()

    render.disable_state(render.STATE_DEPTH_TEST)
    render.set_depth_mask(false)
    render.set_render_target(self.scene_rt)
end

function M.apply(self, viewport)
    if not self.scene_rt then
        return
    end

    local blur_version = self.blur_version or 1
    local effect_enabled = self.dof_enabled
    local depth_blur_enabled = self.depth_blur_enabled
    local simple_mode = self.simple_blur_mode
    local final_blur_target = self.scene_rt

    render.disable_state(render.STATE_DEPTH_TEST)
    render.disable_state(render.STATE_CULL_FACE)
    render.set_depth_mask(false)
    render.set_view(IDENTITY_MATRIX)
    render.set_projection(IDENTITY_MATRIX)
    render.set_blend_func(render.BLEND_ONE, render.BLEND_ZERO)

    if effect_enabled then
        if simple_mode then
            render.set_render_target(self.dof_blur_rt)
            render.set_viewport(0, 0, self.dof_half_width, self.dof_half_height)
            render.clear({ [render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0) })
            render.enable_texture(0, self.scene_rt, render.BUFFER_COLOR_BIT)
            render.enable_material("blur_simple")
            render.draw(self.post_pred, { constants = self.simple_blur_cb })
            render.disable_material()
            render.disable_texture(0)
            final_blur_target = self.dof_blur_rt
        elseif depth_blur_enabled then
            render.set_render_target(self.dof_prefilter_rt)
            render.set_viewport(0, 0, self.dof_half_width, self.dof_half_height)
            render.clear({ [render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0) })
            render.enable_texture(0, self.scene_rt, render.BUFFER_COLOR_BIT)
            if self.scene_depth_rt then
                render.enable_texture(1, self.scene_depth_rt, render.BUFFER_COLOR_BIT)
            else
                render.enable_texture(1, self.scene_rt, render.BUFFER_COLOR_BIT)
            end
            render.enable_material("dof_prefilter")
            render.draw(self.post_pred, { constants = self.dof_prefilter_cb })
            render.disable_material()
            render.disable_texture(1)
            render.disable_texture(0)

            if blur_version == 3 then
                render.set_render_target(self.dof_blur_rt)
                render.set_viewport(0, 0, self.dof_half_width, self.dof_half_height)
                render.clear({ [render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0) })
                render.enable_texture(0, self.dof_prefilter_rt, render.BUFFER_COLOR_BIT)
                self.dof_blur_cb.blur_direction = vmath.vector4(1, 0, 0, 0)
                render.enable_material("dof_blur_separable")
                render.draw(self.post_pred, { constants = self.dof_blur_cb })
                render.disable_material()
                render.disable_texture(0)

                render.set_render_target(self.dof_prefilter_rt)
                render.set_viewport(0, 0, self.dof_half_width, self.dof_half_height)
                render.clear({ [render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0) })
                render.enable_texture(0, self.dof_blur_rt, render.BUFFER_COLOR_BIT)
                self.dof_blur_cb.blur_direction = vmath.vector4(0, 1, 0, 0)
                render.enable_material("dof_blur_separable")
                render.draw(self.post_pred, { constants = self.dof_blur_cb })
                render.disable_material()
                render.disable_texture(0)
                final_blur_target = self.dof_prefilter_rt
            elseif blur_version == 4 then
                render.set_render_target(self.dof_blur_rt)
                render.set_viewport(0, 0, self.dof_half_width, self.dof_half_height)
                render.clear({ [render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0) })
                render.enable_texture(0, self.dof_prefilter_rt, render.BUFFER_COLOR_BIT)
                render.enable_material("dof_blur_circular4")
                render.draw(self.post_pred, { constants = self.dof_blur_cb })
                render.disable_material()
                render.disable_texture(0)
                final_blur_target = self.dof_blur_rt
            elseif blur_version == 5 then
                render.set_render_target(self.dof_blur_rt)
                render.set_viewport(0, 0, self.dof_half_width, self.dof_half_height)
                render.clear({ [render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0) })
                render.enable_texture(0, self.dof_prefilter_rt, render.BUFFER_COLOR_BIT)
                render.enable_material("dof_blur_circular")
                render.draw(self.post_pred, { constants = self.dof_blur_cb })
                render.disable_material()
                render.disable_texture(0)
                final_blur_target = self.dof_blur_rt
            else
                render.set_render_target(self.dof_blur_rt)
                render.set_viewport(0, 0, self.dof_half_width, self.dof_half_height)
                render.clear({ [render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0) })
                render.enable_texture(0, self.dof_prefilter_rt, render.BUFFER_COLOR_BIT)
                render.enable_material("dof_blur")
                render.draw(self.post_pred, { constants = self.dof_blur_cb })
                render.disable_material()
                render.disable_texture(0)
                final_blur_target = self.dof_blur_rt
            end
        end
    end

    render.set_render_target(render.RENDER_TARGET_DEFAULT)
    render.set_viewport(0, 0, rendercam.window.x, rendercam.window.y)
    render.enable_texture(0, self.scene_rt, render.BUFFER_COLOR_BIT)
    render.enable_texture(1, final_blur_target, render.BUFFER_COLOR_BIT)
    if self.scene_depth_rt then
        render.enable_texture(2, self.scene_depth_rt, render.BUFFER_COLOR_BIT)
    else
        render.enable_texture(2, self.scene_rt, render.BUFFER_COLOR_BIT)
    end
    render.enable_material("dof_composite")
    render.draw(self.post_pred, { constants = self.dof_composite_cb })
    render.disable_material()
    render.disable_texture(2)
    render.disable_texture(1)
    render.disable_texture(0)

    render.set_view(self.view)
    render.set_projection(self.proj)
    if viewport then
        render.set_viewport(viewport.x, viewport.y, viewport.width, viewport.height)
    end
    render.set_blend_func(render.BLEND_SRC_ALPHA, render.BLEND_ONE_MINUS_SRC_ALPHA)
end

function M.handle_message(self, message_id, message)
    if message_id ~= SET_DOF then
        return false
    end
    if message.enabled ~= nil then dof.set_enabled(message.enabled) end
    if message.focus_distance or message.focus_range then
        dof.set_focus(message.focus_distance, message.focus_range)
    end
    if message.max_blur then dof.set_max_blur(message.max_blur) end
    if message.near_strength or message.far_strength then
        dof.set_strengths(message.near_strength, message.far_strength)
    end
    if message.blur_version then
        dof.set_blur_version(message.blur_version)
    end
    if message.tint then
        dof.set_tint(message.tint)
    else
        if message.tint_enabled ~= nil or message.tint_intensity or message.tint_near_color or message.tint_focus_color or message.tint_far_color then
            dof.set_tint({
                enabled = message.tint_enabled,
                intensity = message.tint_intensity,
                near_color = message.tint_near_color,
                focus_color = message.tint_focus_color,
                far_color = message.tint_far_color,
            })
        end
    end
    return true
end

function M.final(self)
    delete_target(self.scene_rt)
    delete_target(self.scene_depth_rt)
    delete_target(self.dof_prefilter_rt)
    delete_target(self.dof_blur_rt)
end

return M
