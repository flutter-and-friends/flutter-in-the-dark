#version 320 es

// Burn-reveal fragment shader: ONE pass that draws the "paper" overlay with
// a jagged burn hole punched through it, the charred ring, and the flame rim
// — replacing the rasterized-ImageShader-inside-dstOut-ShaderMask + separate
// CustomPainter(BurnPainter) pair in `widgets/burn_effects.dart`.
//
// Because the shader outputs alpha=0 for the hole region directly, NO
// saveLayer / BlendMode.dstOut is needed at all: this painter composites over
// whatever is beneath (the pre-warmed challenge iframe) with the normal
// source-over blend the CustomPaint layer already gets. That removes the
// full-screen saveLayer rasterization the dstOut mask forced every frame.
//
// The math is a line-for-line port of the pure Dart in
// `helpers/burn_phase.dart` (sampleBurn) and `helpers/burn_edge.dart`
// (BurnEdge.radiusScaleAt). The countdown text is NOT drawn by this shader
// (a fragment shader cannot draw widget text); see burn_shader.dart for how
// the hole-hole alpha mask is reused to fade the paper text by the same mask.

precision highp float;

#include <flutter/runtime_effect.glsl>

// u_bounds.xy = top-left of the paint rect, u_bounds.zw = size (logical px).
layout(location = 0) uniform vec4 u_bounds;
// u_shape.x = progress (0..1), .y = variation, .z = halfDiagonal, .w = rimAlpha.
layout(location = 1) uniform vec4 u_shape;
// Per-frequency phases for the 3 sinusoids (frequencies are the constant 3/5/8).
layout(location = 2) uniform vec4 u_phase0; // .x = phase for f=3
layout(location = 3) uniform vec4 u_phase1; // .x = phase for f=5
layout(location = 4) uniform vec4 u_phase2; // .x = phase for f=8
// Normalized amplitudes (sum == 1.0), lower frequencies dominate: a_i = (1 - i*0.25)/total.
layout(location = 5) uniform vec4 u_amp; // .xyz = a3,a5,a8
// u_paper.rgb = opaque paper color, u_paper.a = paper alpha.
layout(location = 6) uniform vec4 u_paper;

layout(location = 0) out vec4 fragColor;

const float PI = 3.1415926535897932384626;

// Ease-in-cubic, identical to burn_phase._easeInCubic.
float easeInCubic(float t) { return t * t * t; }

// BurnEdge.radiusScaleAt: periodic angular noise, clamped to [0.65, 1.35].
float radiusScaleAt(float theta) {
  float sum = u_amp.x * sin(3.0 * theta + u_phase0.x)
            + u_amp.y * sin(5.0 * theta + u_phase1.x)
            + u_amp.z * sin(8.0 * theta + u_phase2.x);
  return clamp(1.0 + u_shape.y * sum, 0.65, 1.35);
}

void main() {
  vec2 pos = FlutterFragCoord().xy - u_bounds.xy; // logical px from top-left
  vec2 center = u_bounds.zw * 0.5;
  vec2 d = pos - center;
  float dist = length(d);
  // atan(y, x); undefined at the exact center, but the hole there erases anyway.
  float theta = dist < 0.0001 ? 0.0 : atan(d.y, d.x);

  float progress = u_shape.x;
  float halfDiagonal = u_shape.z;

  // sampleBurn(p): hole + band offsets, as fractions of halfDiagonal.
  float t = clamp(progress, 0.0, 1.0);
  float hole = easeInCubic(t);
  float char = clamp(hole + 0.10, 0.0, 1.3);
  float flame = clamp(hole + 0.18, 0.0, 1.5);
  float fadeIn = clamp(t / 0.15, 0.0, 1.0);
  float fadeOut = t <= 0.75 ? 1.0 : clamp(1.0 - (t - 0.75) / 0.25, 0.0, 1.0);
  float rimAlpha = fadeIn * fadeOut;

  // Angular perturbation of every radius by the SAME scale (bands hug the edge).
  float scale = radiusScaleAt(theta);
  float holePx = hole * scale * halfDiagonal;
  float charPx = char * scale * halfDiagonal;
  float flamePx = flame * scale * halfDiagonal;

  // --- Hole erase: 1 inside, soft falloff across the char band, 0 outside ---
  // The ImageShader version blurred the hole path by charWidth/2. A 1-px
  // smoothstep is the analytic feather; we use half the band width each side
  // of the contour to approximate the blur's spread.
  float charWidth = max((char - hole) * scale * halfDiagonal, 1.0);
  float feather = charWidth * 0.5;
  float erase = 1.0 - smoothstep(holePx - feather, holePx + feather, dist);

  // --- Charred ring: darkened paper just OUTSIDE the hole, soft edges ---
  // Band from hole to char radius, alpha peaking mid-band.
  float charBand = smoothstep(holePx, holePx + feather, dist)
                 * (1.0 - smoothstep(charPx - feather, charPx + feather, dist));
  vec3 charColor = vec3(0.169, 0.078, 0.031); // #2B1408

  // --- Flame rim: ember glow outside, hot core hugging the edge ---
  float flameWidth = max((flame - hole) * scale * halfDiagonal, 1.0);
  float flameBand = smoothstep(charPx, charPx + feather, dist)
                  * (1.0 - smoothstep(flamePx - feather, flamePx + feather, dist));
  vec3 ember = vec3(1.0, 0.235, 0.0);   // #FF3C00
  vec3 midOrange = vec3(1.0, 0.427, 0.0); // #FF6D00
  vec3 hotCore = vec3(1.0, 0.843, 0.251); // #FFD740

  // Hot core: a tight ring straddling the hole contour, only on the outside.
  float coreBand = smoothstep(holePx, holePx + 2.0, dist)
                 * (1.0 - smoothstep(holePx + 2.0, holePx + 2.0 + flameWidth * 0.4, dist));

  // Compose: start from opaque paper, cut the hole, add char then flame.
  vec4 paper = vec4(u_paper.rgb, u_paper.a);
  // Darken paper toward char inside the char band (multiply-ish darkening).
  vec3 burned = mix(paper.rgb, charColor, clamp(charBand, 0.0, 1.0));
  // Flame sits on top, additively brightened toward the rim colors.
  vec3 flameCol = ember * flameBand * 0.6 + midOrange * flameBand * 0.85 + hotCore * coreBand;
  vec3 rgb = burned + flameCol * rimAlpha;

  // Alpha: paper alpha everywhere except the erased hole.
  float alpha = paper.a * (1.0 - erase);

  fragColor = vec4(rgb, alpha);
}
