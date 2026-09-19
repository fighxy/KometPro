#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec2 uRectOrigin;
uniform vec2 uRectSize;
uniform float uRadius;
uniform float uSpread;
uniform float uRefraction;
uniform float uChroma;
uniform float uSpecular;
uniform vec4 uTint;
uniform vec2 uLight;
uniform float uTintFeather;
uniform float uRimWidth;
uniform float uBand;
uniform float uIor;
uniform float uSaturation;
uniform float uAdaptive;
uniform float uRimAlpha;
uniform float uBounceAlpha;
uniform float uDepthShade;
uniform float uInterior;

uniform sampler2D uBackdrop;

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);
const float kSlopeMax = 8.0;
const int TAPS = 8;
const float kGolden = 2.399963;

float roundedBoxSdf(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

vec2 surfaceNormal(vec2 p, vec2 halfSize, float radius) {
  vec2 unit = vec2(1.0, 0.0);
  float dx = roundedBoxSdf(p + unit.xy, halfSize, radius) -
             roundedBoxSdf(p - unit.xy, halfSize, radius);
  float dy = roundedBoxSdf(p + unit.yx, halfSize, radius) -
             roundedBoxSdf(p - unit.yx, halfSize, radius);
  return normalize(vec2(dx, dy) + vec2(1e-6));
}

// Convex squircle bevel, h(x) = (1 - (1 - x)^4)^(1/4) for x from the rim
// inward. Its slope is what bends the light, so the lens is strongest in the
// first pixels of the edge and flat in the middle — the profile Apple's glass
// shows, unlike a plain gradient that smears distortion across the whole
// surface.
float bevelSlope(float x) {
  float u = clamp(1.0 - x, 0.0, 1.0);
  float u2 = u * u;
  float u4 = u2 * u2;
  float denom = pow(max(1.0 - u4, 1e-3), 0.75);
  return min(u2 * u / denom, kSlopeMax);
}

// Lateral offset of a ray entering the bevel, Snell's law with the ray
// orthogonal to the backdrop: tan(theta_in) - tan(theta_refracted).
float refractionBend(float slope, float ior) {
  float sin1 = slope * inversesqrt(1.0 + slope * slope);
  float sin2 = sin1 / max(ior, 1.0001);
  float cos2 = sqrt(max(1.0 - sin2 * sin2, 1e-5));
  return max(slope - sin2 / cos2, 0.0);
}

vec3 sampleBackdrop(vec2 coord) {
  vec2 uv = coord / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

// Poisson-ish disk gather. The radius grows toward the middle of the surface,
// so the rim keeps a readable magnified edge while the body stays frosted.
vec3 gather(vec2 origin, float radius, vec2 normal, float aberration) {
  vec3 sum = vec3(0.0);
  for (int i = 0; i < TAPS; i++) {
    float t = (float(i) + 0.5) / float(TAPS);
    float angle = float(i) * kGolden;
    vec2 disk = vec2(cos(angle), sin(angle)) * radius * sqrt(t);
    vec2 coord = origin + disk;
    if (aberration > 0.0) {
      sum.r += sampleBackdrop(coord + normal * aberration).r;
      sum.g += sampleBackdrop(coord).g;
      sum.b += sampleBackdrop(coord - normal * aberration).b;
    } else {
      sum += sampleBackdrop(coord);
    }
  }
  return sum / float(TAPS);
}

vec3 saturated(vec3 color, float amount) {
  return mix(vec3(dot(color, kLuma)), color, amount);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 halfSize = uRectSize * 0.5;
  vec2 center = uRectOrigin + halfSize;
  vec2 p = fragCoord - center;

  float radius = min(uRadius, min(halfSize.x, halfSize.y));
  float sd = roundedBoxSdf(p, halfSize, radius);

  if (sd > 0.0) {
    fragColor = vec4(sampleBackdrop(fragCoord), 1.0);
    return;
  }

  vec2 normal = surfaceNormal(p, halfSize, radius);
  float band = clamp(uBand * uSpread, 1.0, min(halfSize.x, halfSize.y));
  float depth = clamp(-sd / band, 0.0, 1.0);

  float slope = bevelSlope(depth);
  float bend = refractionBend(slope, uIor);
  float maxBend = max(refractionBend(kSlopeMax, uIor), 1e-3);
  float lens = bend / maxBend;
  float shift = uRefraction * lens;

  float blur = mix(1.0, max(uInterior, 0.0), depth);
  float aberration = uChroma * shift;

  vec3 refracted = gather(fragCoord + normal * shift, blur, normal, aberration);
  vec3 color = saturated(refracted, uSaturation);

  // Adaptive tint: the veil grows with the gap between what is behind the
  // glass and the glass's own tone, so content on top keeps its contrast over
  // both dark and bright backdrops instead of washing out.
  float luma = dot(color, kLuma);
  float target = dot(uTint.rgb, kLuma);
  float mismatch = clamp(abs(luma - target) * 1.4, 0.0, 1.0);
  float veil = smoothstep(0.0, 1.0, clamp(-sd / max(uTintFeather, 1.0), 0.0, 1.0));
  float alpha = clamp(uTint.a + uAdaptive * mismatch, 0.0, 1.0) * veil;
  color = mix(color, uTint.rgb, alpha);

  vec2 light = normalize(uLight + vec2(1e-6));
  float facing = dot(normal, light);
  float rim = 1.0 - smoothstep(0.0, max(uRimWidth, 1.0), -sd);
  float lit = pow(max(facing, 0.0), 2.0) * rim;
  float bounced = pow(max(-facing, 0.0), 2.0) * rim;

  color += vec3(uSpecular * uRimAlpha * lit);
  color += vec3(uSpecular * uBounceAlpha * bounced);

  // Thickness: the bevel meeting the flat body reads as a soft dark line.
  float inner = 4.0 * depth * (1.0 - depth);
  color *= 1.0 - uDepthShade * inner * (0.55 + 0.45 * bounced);

  fragColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
