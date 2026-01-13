# Visual Effects Recipes

## Table of Contents
- [Surface Effects](#surface-effects)
- [Animated Effects](#animated-effects)
- [Particle Effects](#particle-effects)
- [Post-Processing Effects](#post-processing-effects)

## Surface Effects

### Fresnel / Rim Lighting

Edge glow based on view angle:

```glsl
// In fragment shader
uniform vec3 cameraPosition;
varying vec3 vWorldPosition;
varying vec3 vNormal;

void main() {
  vec3 viewDir = normalize(cameraPosition - vWorldPosition);
  vec3 normal = normalize(vNormal);

  // Fresnel factor: 0 when facing camera, 1 at edges
  float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 3.0);

  vec3 baseColor = vec3(0.1);
  vec3 rimColor = vec3(0.0, 0.5, 1.0);

  gl_FragColor = vec4(baseColor + rimColor * fresnel, 1.0);
}
```

### Triplanar Mapping

Texture without UV seams:

```glsl
uniform sampler2D u_texture;
uniform float u_scale;
varying vec3 vWorldPosition;
varying vec3 vNormal;

void main() {
  vec3 blending = abs(normalize(vNormal));
  blending = normalize(max(blending, 0.00001));
  float b = blending.x + blending.y + blending.z;
  blending /= b;

  vec3 pos = vWorldPosition * u_scale;

  vec4 xaxis = texture2D(u_texture, pos.yz);
  vec4 yaxis = texture2D(u_texture, pos.xz);
  vec4 zaxis = texture2D(u_texture, pos.xy);

  gl_FragColor = xaxis * blending.x + yaxis * blending.y + zaxis * blending.z;
}
```

### Matcap Shading

Material capture using normal-based UV lookup:

```glsl
uniform sampler2D u_matcap;
varying vec3 vViewNormal;

void main() {
  vec3 normal = normalize(vViewNormal);
  vec2 matcapUV = normal.xy * 0.5 + 0.5;
  gl_FragColor = texture2D(u_matcap, matcapUV);
}

// Vertex shader must output view-space normal:
// vViewNormal = normalize(normalMatrix * normal);
```

### Toon / Cel Shading

Quantized lighting bands:

```glsl
uniform vec3 u_lightDir;
uniform vec3 u_baseColor;
varying vec3 vNormal;

void main() {
  vec3 normal = normalize(vNormal);
  float NdotL = dot(normal, normalize(u_lightDir));

  // Quantize to bands (clamp to avoid exceeding 1.0 at NdotL=1)
  float bands = 3.0;
  float shade = floor(clamp(NdotL, 0.0, 0.9999) * bands) / (bands - 1.0);
  shade = max(shade, 0.2);  // Ambient minimum

  gl_FragColor = vec4(u_baseColor * shade, 1.0);
}
```

**Toon outlines (separate pass):**
```javascript
// Render backfaces slightly scaled up
const outlineMat = new THREE.ShaderMaterial({
  side: THREE.BackSide,
  vertexShader: `
    void main() {
      vec3 pos = position + normal * 0.02;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
    }
  `,
  fragmentShader: `
    void main() {
      gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
  `
});
```

### Hologram / Scanlines

```glsl
// Fragment shader (use with ShaderMaterial which auto-injects cameraPosition)
uniform float u_time;
uniform vec3 cameraPosition; // Auto-injected by ShaderMaterial, or declare for RawShaderMaterial
varying vec2 vUv;
varying vec3 vNormal;
varying vec3 vWorldPosition; // Must output from vertex shader

void main() {
  vec3 viewDir = normalize(cameraPosition - vWorldPosition);
  float fresnel = pow(1.0 - abs(dot(viewDir, vNormal)), 2.0);

  // Scanlines
  float scanline = sin(vUv.y * 200.0 + u_time * 10.0) * 0.5 + 0.5;
  scanline = pow(scanline, 1.5);

  // Flicker
  float flicker = sin(u_time * 20.0) * 0.1 + 0.9;

  vec3 holoColor = vec3(0.0, 0.8, 1.0);
  float alpha = (fresnel * 0.5 + scanline * 0.3) * flicker;

  gl_FragColor = vec4(holoColor * alpha, alpha);
}

// Vertex shader for hologram (outputs world position for fresnel)
// varying vec3 vWorldPosition;
// varying vec3 vNormal;
// varying vec2 vUv;
// void main() {
//   vUv = uv;
//   vNormal = normalize(normalMatrix * normal);
//   vWorldPosition = (modelMatrix * vec4(position, 1.0)).xyz;
//   gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
// }
```

### Glitch Effect

```glsl
uniform float u_time;
uniform sampler2D u_texture;
varying vec2 vUv;

float random(vec2 co) {
  return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  vec2 uv = vUv;

  // Random line offset
  float lineNoise = step(0.98, random(vec2(floor(vUv.y * 50.0), u_time)));
  uv.x += lineNoise * (random(vec2(u_time)) - 0.5) * 0.2;

  // RGB shift
  float shift = sin(u_time * 5.0) * 0.005;
  float r = texture2D(u_texture, uv + vec2(shift, 0.0)).r;
  float g = texture2D(u_texture, uv).g;
  float b = texture2D(u_texture, uv - vec2(shift, 0.0)).b;

  gl_FragColor = vec4(r, g, b, 1.0);
}
```

## Animated Effects

### UV Scrolling

```glsl
uniform float u_time;
uniform sampler2D u_texture;
uniform vec2 u_speed;  // e.g., vec2(0.1, 0.0)
varying vec2 vUv;

void main() {
  vec2 scrollUV = fract(vUv + u_time * u_speed);
  gl_FragColor = texture2D(u_texture, scrollUV);
}
```

### Dissolve / Disintegration

```glsl
uniform float u_dissolve;  // 0 to 1
uniform sampler2D u_noise;
uniform vec3 u_edgeColor;
varying vec2 vUv;

void main() {
  float noise = texture2D(u_noise, vUv * 3.0).r;

  // Discard dissolved pixels
  if (noise < u_dissolve) discard;

  // Glowing edge
  float edge = 1.0 - smoothstep(0.0, 0.1, noise - u_dissolve);
  vec3 baseColor = vec3(0.5);

  gl_FragColor = vec4(mix(baseColor, u_edgeColor, edge), 1.0);
}
```

### Wave Distortion (Vertex)

```glsl
uniform float u_time;
uniform float u_amplitude;
uniform float u_frequency;

void main() {
  vec3 pos = position;

  // Wave along X
  pos.y += sin(pos.x * u_frequency + u_time * 2.0) * u_amplitude;

  // Optional: multiple wave directions
  pos.y += sin(pos.z * u_frequency * 0.5 + u_time) * u_amplitude * 0.5;

  gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
}
```

### Heat Haze / Refraction

```glsl
uniform float u_time;
uniform sampler2D u_scene;      // Background render
uniform sampler2D u_distortion; // Normal/noise map
uniform float u_strength;
varying vec2 vUv;

void main() {
  vec2 distort = texture2D(u_distortion, vUv + u_time * 0.01).rg;
  distort = (distort * 2.0 - 1.0) * u_strength;

  vec4 color = texture2D(u_scene, vUv + distort);
  gl_FragColor = color;
}
```

### Pulsing Glow

```glsl
uniform float u_time;
uniform vec3 u_glowColor;

void main() {
  float pulse = 0.5 + 0.5 * sin(u_time * 3.0);
  vec3 emissive = u_glowColor * pulse;

  vec3 baseColor = vec3(0.1);
  gl_FragColor = vec4(baseColor + emissive, 1.0);
}
```

## Particle Effects

### Point Sprite (gl_PointCoord)

```glsl
// Fragment shader for THREE.Points
uniform sampler2D u_sprite;
uniform vec3 u_color;

void main() {
  // gl_PointCoord is 0-1 across the point sprite
  vec4 tex = texture2D(u_sprite, gl_PointCoord);

  // Make circular
  float dist = length(gl_PointCoord - 0.5);
  if (dist > 0.5) discard;

  // Soft edge
  float alpha = 1.0 - smoothstep(0.4, 0.5, dist);

  gl_FragColor = vec4(u_color * tex.rgb, tex.a * alpha);
}
```

### Soft Particles (Depth Fade)

Requires depth texture setup (see threejs-integration.md for WebGLRenderTarget with DepthTexture).

```glsl
uniform sampler2D u_depthTexture;
uniform float u_cameraNear;
uniform float u_cameraFar;
uniform vec2 u_resolution;

// Correct linearization: depth texture stores non-linear depth
float linearizeDepth(float d) {
  float z = d * 2.0 - 1.0; // Convert [0,1] to NDC [-1,1]
  return (2.0 * u_cameraNear * u_cameraFar) / (u_cameraFar + u_cameraNear - z * (u_cameraFar - u_cameraNear));
}

void main() {
  vec2 screenUV = gl_FragCoord.xy / u_resolution;
  float sceneDepth = linearizeDepth(texture2D(u_depthTexture, screenUV).r);
  // gl_FragCoord.z is already in [0,1], same space as depth texture
  float particleDepth = linearizeDepth(gl_FragCoord.z);

  float fade = clamp((sceneDepth - particleDepth) * 10.0, 0.0, 1.0);

  vec4 color = vec4(1.0, 0.5, 0.0, 1.0);
  gl_FragColor = vec4(color.rgb, color.a * fade);
}
```

### Animated Sprite Sheet

```glsl
uniform sampler2D u_spriteSheet;
uniform float u_frame;      // Current frame (0, 1, 2, ...)
uniform vec2 u_gridSize;    // e.g., vec2(4.0, 4.0) for 4x4 grid

void main() {
  float frame = floor(u_frame);
  float col = mod(frame, u_gridSize.x);
  float row = floor(frame / u_gridSize.x);

  vec2 frameUV = gl_PointCoord / u_gridSize;
  frameUV.x += col / u_gridSize.x;
  frameUV.y += row / u_gridSize.y;

  gl_FragColor = texture2D(u_spriteSheet, frameUV);
}
```

## Post-Processing Effects

### Gaussian Blur (Separable)

```glsl
// Horizontal pass
uniform sampler2D u_texture;
uniform vec2 u_resolution;
uniform float u_radius;
varying vec2 vUv;

void main() {
  vec2 texel = 1.0 / u_resolution;
  vec4 sum = vec4(0.0);

  // 9-tap kernel
  sum += texture2D(u_texture, vUv + vec2(-4.0 * texel.x * u_radius, 0.0)) * 0.051;
  sum += texture2D(u_texture, vUv + vec2(-3.0 * texel.x * u_radius, 0.0)) * 0.0918;
  sum += texture2D(u_texture, vUv + vec2(-2.0 * texel.x * u_radius, 0.0)) * 0.12245;
  sum += texture2D(u_texture, vUv + vec2(-1.0 * texel.x * u_radius, 0.0)) * 0.1531;
  sum += texture2D(u_texture, vUv) * 0.1633;
  sum += texture2D(u_texture, vUv + vec2(1.0 * texel.x * u_radius, 0.0)) * 0.1531;
  sum += texture2D(u_texture, vUv + vec2(2.0 * texel.x * u_radius, 0.0)) * 0.12245;
  sum += texture2D(u_texture, vUv + vec2(3.0 * texel.x * u_radius, 0.0)) * 0.0918;
  sum += texture2D(u_texture, vUv + vec2(4.0 * texel.x * u_radius, 0.0)) * 0.051;

  gl_FragColor = sum;
}
// Repeat with Y direction for vertical pass
```

### Vignette

```glsl
uniform sampler2D u_texture;
uniform float u_intensity;
uniform float u_smoothness;
varying vec2 vUv;

void main() {
  vec4 color = texture2D(u_texture, vUv);

  vec2 center = vUv - 0.5;
  float dist = length(center);
  // smoothstep(edge0, edge1, x) requires edge0 < edge1
  float vignette = 1.0 - smoothstep(0.5 - u_smoothness, 0.5, dist * u_intensity);

  gl_FragColor = vec4(color.rgb * vignette, color.a);
}
```

### Chromatic Aberration

```glsl
uniform sampler2D u_texture;
uniform float u_amount;
varying vec2 vUv;

void main() {
  vec2 dir = vUv - 0.5;
  float dist = length(dir);

  vec2 offset = dir * dist * u_amount;

  float r = texture2D(u_texture, vUv + offset).r;
  float g = texture2D(u_texture, vUv).g;
  float b = texture2D(u_texture, vUv - offset).b;

  gl_FragColor = vec4(r, g, b, 1.0);
}
```

### Film Grain

```glsl
uniform sampler2D u_texture;
uniform float u_time;
uniform float u_amount;
varying vec2 vUv;

float random(vec2 co) {
  return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  vec4 color = texture2D(u_texture, vUv);

  float grain = random(vUv + u_time) - 0.5;
  color.rgb += grain * u_amount;

  gl_FragColor = color;
}
```

### Edge Detection (Sobel)

```glsl
uniform sampler2D u_texture;
uniform vec2 u_resolution;
varying vec2 vUv;

void main() {
  vec2 texel = 1.0 / u_resolution;

  // Sample 3x3 neighborhood
  float tl = texture2D(u_texture, vUv + texel * vec2(-1, 1)).r;
  float t  = texture2D(u_texture, vUv + texel * vec2(0, 1)).r;
  float tr = texture2D(u_texture, vUv + texel * vec2(1, 1)).r;
  float l  = texture2D(u_texture, vUv + texel * vec2(-1, 0)).r;
  float r  = texture2D(u_texture, vUv + texel * vec2(1, 0)).r;
  float bl = texture2D(u_texture, vUv + texel * vec2(-1, -1)).r;
  float b  = texture2D(u_texture, vUv + texel * vec2(0, -1)).r;
  float br = texture2D(u_texture, vUv + texel * vec2(1, -1)).r;

  // Sobel operators
  float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
  float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;

  float edge = sqrt(gx*gx + gy*gy);
  gl_FragColor = vec4(vec3(edge), 1.0);
}
```

### Bloom (Threshold + Blur + Combine)

```glsl
// Pass 1: Extract bright areas
uniform sampler2D u_texture;
uniform float u_threshold;

void main() {
  vec4 color = texture2D(u_texture, vUv);
  float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  gl_FragColor = brightness > u_threshold ? color : vec4(0.0);
}

// Pass 2 & 3: Blur (see Gaussian Blur above)

// Pass 4: Combine
uniform sampler2D u_scene;
uniform sampler2D u_bloom;
uniform float u_intensity;

void main() {
  vec4 scene = texture2D(u_scene, vUv);
  vec4 bloom = texture2D(u_bloom, vUv);
  gl_FragColor = scene + bloom * u_intensity;
}
```

### Color Grading (Simple)

```glsl
uniform sampler2D u_texture;
uniform float u_brightness;
uniform float u_contrast;
uniform float u_saturation;
varying vec2 vUv;

void main() {
  vec4 color = texture2D(u_texture, vUv);

  // Brightness
  color.rgb += u_brightness;

  // Contrast
  color.rgb = (color.rgb - 0.5) * u_contrast + 0.5;

  // Saturation
  float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
  color.rgb = mix(vec3(gray), color.rgb, u_saturation);

  gl_FragColor = color;
}
```
