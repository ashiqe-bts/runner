struct Scene {
  viewProjection: mat4x4<f32>,
  model: mat4x4<f32>,
  bones: array<mat4x4<f32>,20>,
  tint: vec4<f32>,
  camera: vec4<f32>,
}
@group(0) @binding(0) var<uniform> scene: Scene;
struct Output {
  @builtin(position) position: vec4<f32>,
  @location(0) normal: vec3<f32>,
  @location(1) color: vec3<f32>,
  @location(2) world: vec3<f32>,
}
@vertex fn vs_main(@location(0) position: vec3<f32>, @location(1) normal: vec3<f32>,
  @location(2) color: vec4<f32>, @location(3) skin: vec4<f32>) -> Output {
  let transform = scene.bones[u32(skin.x)] * (1.-skin.z) + scene.bones[u32(skin.y)] * skin.z;
  let world = scene.model * transform * vec4<f32>(position, 1.);
  var out: Output;
  out.position = scene.viewProjection * world;
  out.normal = normalize((scene.model * transform * vec4<f32>(normal, 0.)).xyz);
  out.color = select(color.rgb, scene.tint.rgb, color.a > .5);
  out.world = world.xyz;
  return out;
}
@fragment fn fs_main(in: Output) -> @location(0) vec4<f32> {
  let n = normalize(in.normal);
  let key = max(0., dot(n,normalize(vec3<f32>(-.5,.8,-.5))));
  let rim = pow(1.-max(0.,dot(n,normalize(scene.camera.xyz-in.world))),3.);
  let lit = in.color * (.38 + key * .7) + vec3<f32>(.10,.24,.27)*rim;
  let fog = smoothstep(40.,170.,distance(scene.camera.xyz,in.world));
  return vec4<f32>(mix(lit,vec3<f32>(.06,.14,.20),fog),1.);
}
