# Tiny Worlds Community Challenge

This is a fork of a fork of the Light and Shadows for Defold made for fun for the (Defold Community Challenge: Tiny Worlds)[https://forum.defold.com/t/community-challenge-tiny-worlds/81931/80].

This adds to the already awesome example of lighting with shadows and a curved world rendering few examples of a Depth of Field effect (including a full screen blur) and a possibility to add skybox based on (Defold Skybox example)[https://defold.com/examples/model/skybox/].

And presents a Tiny Medieval Town using Kay Lousberg [Medieval Hexagon Pack](https://kaylousberg.itch.io/kaykit-medieval-hexagon).

# Light and Shadows - Curved

This fork is slightly modified from the Dragosha's original to demonstrate a [curved world](https://github.com/rgrams/defold-curved-world) shader effect.

Try the web demo here: https://rgrams.github.io/defold-light-and-shadows-curved/

Unaltered original readme below:

# Light and Shadows. Pack of shaders and scene setup examples.

Required 1.3.6 Defold version.

## What is this?
A pack of materials and shaders to make a game with realtime shadow from one source (the sun) and a lot of point light sources.
The main difference from previous examples (see on the Defold forum) is the projection of the shadow map to the center of the screen (cast shadows follow the camera). So you can create a game world of any size. And the sprites/spine models get shadows from other objects as well as 3D models.

![title](assets/docs/title.png)

[Html5 demo](https://dragosha.com/defold/Light_and_Shadows/)

- Press and hold left mouse button to move the camera.
- Click on coins to collect them.
- Works on mobile as well.

## Setup

### Render
The demo project is fully configured, if you want to configure your project from scratch see this section.

Set the render file in `bootstrap` section of the game.project.

![bootstrap](assets/docs/bootstrap.png)

Of course, you can use your own render script. Just add some elements to it.

![render](assets/docs/render.png)

Add `shadow` material in the list of materials available from render.

See `rendercam/rendercam.render_script` as the reference.

In render_script include next lines:

---
    local light_and_shadows = require "light_and_shadows.light_and_shadows"
    ...
    in init() method:
    light_and_shadows.init(self)
    ..
    in update() method:
    light_and_shadows.update(self)


Tune shadow settings in the `light_and_shadows.lua` file.

Most important is:

* `BUFFER_RESOLUTION` = 2048 - Size of the shadow map texture. Select value from: 1024/2048/4096. More is better quality. Shadow map texture is projected to the game world.

* `PROJECTION_RESOLUTION` = 400 - This constant indicates the size of the area on which the shadow is projected around the screen center. Smaller size is better shadow quality. This value also depends on camera zoom / world scale. Feel free to adjust it.


### Depth of field post-processing

The whole 3D world is now rendered into an offscreen buffer and blended back after a tilt-shift inspired depth of field pass. Defaults live in `postfx/dof.lua`, but you can tweak them at runtime by messaging the render script:

```
msg.post("@render:", "set_dof", {
    enabled = true,
    focus_distance = 28,
    focus_range = 10,
    max_blur = 0.9,
    near_strength = 1.6,
    far_strength = 1.1,
    blur_version = 5, -- 1 = screen blur, 2 = depth single pass, 3 = separable, 4 = circular (4 dir), 5 = circular (8 dir)
    tint_enabled = true,
    tint_intensity = 0.3,
})
```

`blur_version` progresses from the lightest to the most advanced filter:

1. **Screen blur** - simple fullscreen blur in screen space. Depth is ignored, tinting is disabled, perfect for cheap vignette-style smearing.
2. **Depth single pass** - one pass that already samples the depth texture and uses the circle of confusion (CoC) calculated in the prefilter stage.
3. **Separable X→Y** - two passes (horizontal, then vertical) using the same separable shader, giving a smooth Gaussian-like result for moderate cost.
4. **Circular 4 directions** - gathers samples in four directions (±X, ±Y) and an inner ring to approximate round bokeh without the full cost of the next mode.
5. **Circular 8 directions** - the full gather shader with eight directions plus an inner ring; highest fidelity miniature look, but also the most texture fetches.
6. **Disabled** - no blur at all; the scene is presented untouched so you can compare or turn off the effect temporarily.

Every mode still uses the same `focus_distance`, `focus_range`, `max_blur`, `near_strength`, and `far_strength` parameters defined in `postfx/dof.lua`.
Only the post processing quad reads from the new buffers, so the existing curved-world, lighting and shadow passes stay untouched.

#### Tinting depth for debug/adjustments

There is an option to enable "tinting" as a way to visually debug or adjust DoF params.
 - Closer objects are tinted red
 - Far/background - blue
 - Focus area is tinted with green.
Tinting can be toggled via `tint_enabled`/`tint_intensity`, and the colors themselves can be overridden with `tint_near_color`, `tint_focus_color`, and `tint_far_color`. Switching modes at runtime is as easy as sending another `set_dof` message with a different `blur_version`. Tip: send the message to update DoF in on_reload and after each adjustment - Hot Reload your game.

### Modular render (DoF + skybox)

The post-process (DoF effect) and skybox logic live in separate modules:

- `postfx/dof_pass.lua` - creates RT buffers, updates DoF uniforms, renders depth/blur/composite passes, and handles the `set_dof` message.
- `rendercam/skybox_pass.lua` - encapsulates skybox rendering (predicate, constants, world matrix).

`rendercam/rendercam.render_script` just calls their APIs (`init`, `update_window`, `update_uniforms`/`apply`, `handle_message`, `final`), making it easier to swap passes or plug in an alternate render without touching the rest of the rendering pipeline.

The example uses a CC0 skybox from [here](https://freestylized.com/all-skybox/).

### Materials

* Model - material to install on the 3D models. Note, the material is set up to work in world coordinates. If you use 3D models with this material and the same texture, such objects will be assembled in batching.

* Mesh - material to install on the mesh component. Very similar to the material for models, but also uses the vertex color value in calculating the pixel totals.

* Sprite

** `light_sprite` - material to install on the sprite component. Since the sprite has no normals, we set the normal in the material as an user vector4 constant.
Note, the direction of the normal can and should be changed depending on what angle you set the sprites in your scene. In the example all sprites are tilted at the same X angle as the camera (-26.6), this is done to minimize distortion when drawing a scene with perspective, so that the sprites "look" exactly at the camera.

** `light_sprite_back` - uses the same shaders as light_sprite, but the normal in the material looks "up". Used for decals on the ground, for the floor, etc. Also drawn in its predicate, before the other sprites.

* Spine - material to install on the spine component. Uses the same shaders as light_sprite, differs from sprite only by using a different view matrix.

* Fog - `fog_sprite`, `fog_particle`, `fog_label` are used on appropriate components when we do not need to calculate light and shadows. But the component must fade in the distance and calculate fog. For example, it is used for partials of fire, or the effect of glow from a window. Which is done simply by a sprite with a blending like `ADD` installed. Explore the example scene to understand better. 

* Hidden - materials for auxiliary objects that are not involved in the rendering, but should be visible in the editor window. For example, labels or a camera model.

* Shadow - a special material for calculating the shadow map, set automatically in the render script.

Note that the materials that draw the shadows contain two samplers. Tex0 is your texture or atlas in the case of a sprite. Tex1 will be set automatically in the render script, it is a shadow map texture.

#### Tags:

Tag `shadow` marks that this object should cast a shadow. The render script will automatically substitute material for the object when it draws the shadow into the shadow map texture.

### Render constants

In addition to the data about the light sources, their position in the world and their color, only four additional constants are passed to the render script and then to the shaders.
These are: 

* `Clear color` or background color.

* `Fog color`. Usually the same as the clear color. 4th component (.w) is the fog density (0 - 1.0). Where 0 is a very high density.

* `Fog` minimum and maximum. Z-coord in the camera view space where the fog is started.

* `Ambient` color. 4th component (ambient.w) used as the maximum value of final color component at each pixels. In fragment shader it looks like

---
    diffuse_light = clamp(diffuse_light, 0.0, ambient.w);
    final_pixel_color = texture_color * diffuse_light;

All constants are in `constants.lua` module.

### Light setting

There is a special script and module with functions to setup initial render constants and manage the list of light sources during runtime in update function. This script sets constants into `constants.lua` module.

Your scene should contains one `light_setting.script`. In the example collection you can find it in the `root` game object.

![lightsetting](assets/docs/lightsetting.png)

* `Clear color` or background color. R, G, B (0 - 1.0)

* `Fog color`. Usually the same as the clear color.

* `Fog density` (0 - 1.0). Where 0 is a very high density.

* `Fog Min Max` - minimum and maximum of Z-coord in the camera view space where the fog is started.

* `Ambient` color. R, G, B (0 - 1.0). This is an additional color added after blend all light sources. Among other things, it allows you to illuminate places that are in the shadows.

* `Color max` uses as the maximum value of final color component at each pixels. If the value > 1.0, the places where light sources overlap each other may have an excessive value.

You may include several 'light_setting' scripts with different settings for the testing purposes, but only one should be enabled by trigg `on` property.

## Sun

Only one light source casts shadows and this part is about him. There is a special script to setup initial render constants for the direct light source. Use ready to go prop "sun.go" from light_and_shadows/props folder. Or you can set this constants direct in the `constants.lua` file.

![sun](assets/docs/sun.png)

* `Color` of the light source. R, G, B (0 - 1.0). 

* `Shadow` - Inverted shadow color. Essentially these values are subtracted when the shader mixes the light from different sources. If you want to make the shadow more bluish, as artists do in daylight, make the B component slightly smaller than the others.

Note that color mixing from different light sources takes into account the normal to the surface of the object, be it a sprite or a 3D model.

## Scale of objects

Since this is a pure 3D scene, we prefer to use a scale 1 meter to 1 unit (pixel) in the editor. This means that you can place a collade 3D models as is. Also such object scale is very useful for enabling the 'Move Whole Pixel' option in the 'Edit' menu of the editor. But on the other hand, you need to scale all sprites/spine models to a scale of 0.06 or something like that.

## Bulb

To add a new light source to the scene you need to place bulb.script into the game object. Or use ready to go prop "bulb.go" from light_and_shadows/props folder.

![bulb](assets/docs/bulb.png)

* `Color` of the light source. Red, Green, Blue. 
You may use a negative values as well as values more than 1.0 for override final color of pixel when all light sources are blending. 
* `Power` of the light source where 100 is normal 100 Watt bulb (just for reference, it's not exact).
* Also you may auto start particle FX attached to this game object and referenced in 'fxurl'.
* `Rotate` set to true is this object need to follow the camera rotating (works as Bilboard).

* The light source can move around the game world. The position of the source is calculated in the lights manager script. To make a lamp dynamic, just set `static` to false. Otherwise leave `static` set to 'true' for better performance.

* `Num`. If the bulb has a positive number, this light source does not participate in sorting by distance from the center of the screen. It is always visible. Of course, if the number of all bulbs is less than the MAX values of the light sources (16 in this demonstration). The default value is -1. These bulbs are sorted in the light manager script and you can add as many bulbs as you want. But only the first 16 (this is the value you can change) will get into the shader.


This example uses 16 simultaneously calculated light sources in the scene. If you need to change this number of light sources, you must change it in 'light_and_shadows.lua' and in the fragment shaders.
In the fragment shaders (.fp) change the size of the arrays here:

---
    #define LIGHT_COUNT 16
                        ^^


If you don't want to use light sources at all and you have enough ambient light from the "sun" you can optimize the fragment shaders by excluding the calculation of light sources from them. Just delete the code:

---
    for (int i = 0; i < LIGHT_COUNT; ++i) {
        float power = colors[i].w;
        if (power > 0.0) {
            // vec3 light_color, float power, vec3 light_position, vec3 position, vec3 snormal, float specular, vec3 view_dir
            diff_light += point_light2(colors[i].xyz, power, lights[i].xyz, var_position.xyz, normal_sum, 0.2, view_dir);
        }
    }

## Shadow's quality.

This bundle contains two variants the fragment shaders.

Standart quality:
![standart](assets/docs/example_standart.png)
Uses 9 reads (samplers) from the shadowmap texture + randomization UV. May be too slow for using on lowend mobile devices.

Low quality:
![low](assets/docs/example_low.png)
Uses 1 sampler. Very simple variant.
This shader also uses a short version of diffuse light function. Without the specular calculation.


To switch the quality you need to change fragment shader in used materials (model, light_sprite, light_sprite_back). 
![material](assets/docs/low.png)


## One more thing

In addition to the light scene, this example contains supporting scripts that I often use in my projects. All of them are located in the helper folder. There you can find a script for moving an object with the mouse or touch, you can move the camera, light source or any other object. A set of common methods, such as playing sound with positioning. Or `simple_input` which is described in detail here: https://github.com/Dragosha/defold-things/blob/master/helpers/simple_input.md

If you're new to Defold, notice how the coin collection example works, how the scripts communicate with each other without using hardcoded binding. The `broadcast` module from the `ludobits` library is extremely useful!


## Happy Defolding!

## Credits

* `RenderCam` camera implementation by Ross Grams
* Textures by Dragosha (https://dragosha.com/free/adventure-tileset.html)
* `ludobits`, `monarch`, `defold-input` dependencies by Björn Ritzl
