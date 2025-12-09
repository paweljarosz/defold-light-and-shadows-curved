local M = {}

function M.init(self)
    self.skybox_pred = render.predicate({"skybox"})
    self.skybox_cb = render.constant_buffer()
    self.skybox_world = vmath.matrix4()
end

function M.draw(self, view, proj)
    if not (self.skybox_pred and self.skybox_cb and self.skybox_world) then
        return
    end
    if not (view and proj) then
        return
    end
    local view_no_trans = vmath.matrix4()
    view_no_trans.c0 = view.c0
    view_no_trans.c1 = view.c1
    view_no_trans.c2 = view.c2
    view_no_trans.c3 = vmath.vector4(0, 0, 0, view.c3.w)
    local view_proj = view_no_trans * proj
    self.skybox_cb.view_proj = view_proj
    self.skybox_cb.world = self.skybox_world

    render.set_depth_mask(false)
    render.disable_state(render.STATE_DEPTH_TEST)
    render.disable_state(render.STATE_CULL_FACE) -- draw both sides; cube is viewed from inside
    render.set_depth_func(render.COMPARE_FUNC_LEQUAL)
    render.draw(self.skybox_pred, { constants = self.skybox_cb })
    render.set_depth_func(render.COMPARE_FUNC_LESS)
    render.enable_state(render.STATE_DEPTH_TEST)
    render.set_depth_mask(true)
end

return M
