components {
  id: "coin"
  component: "/examples/example1/coin.script"
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_DYNAMIC\n"
  "mass: 1.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"default\"\n"
  "mask: \"default\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "  }\n"
  "  data: 2.5\n"
  "}\n"
  "locked_rotation: true\n"
  ""
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"Icon-coin\"\n"
  "material: \"/light_and_shadows/materials/sprite/light_sprite.material\"\n"
  "textures {\n"
  "  sampler: \"tex0\"\n"
  "  texture: \"/assets/rgba/tiles.atlas\"\n"
  "}\n"
  "textures {\n"
  "  sampler: \"tex1\"\n"
  "  texture: \"/assets/rgba/tiles.atlas\"\n"
  "}\n"
  ""
  rotation {
    x: -0.23004974
    w: 0.97317886
  }
  scale {
    x: 0.04
    y: 0.04
    z: 0.04
  }
}
