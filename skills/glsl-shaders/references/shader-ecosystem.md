# Shader Libraries & Ecosystem

## Table of Contents
- [Lygia](#lygia)
- [glslify](#glslify)
- [Shadertoy Patterns](#shadertoy-patterns)
- [glsl-easings](#glsl-easings)

## Lygia

Lygia is a shader library of reusable GLSL functions. Include via URL or copy snippets.

### Setup Options

**Option 1: npm package (recommended)**
```bash
npm install lygia
```
```javascript
// Import local files with ?raw in Vite
import noiseGlsl from 'lygia/generative/noise.glsl?raw';
```

**Option 2: Copy functions directly**
Visit https://lygia.xyz and copy the GLSL code you need into your project.

**Option 3: Fetch at runtime (for prototyping)**
```javascript
const noiseGlsl = await fetch('https://lygia.xyz/generative/noise.glsl').then(r => r.text());
```

Note: Vite's `?raw` only works with local files, not remote URLs.

### Key Lygia Modules

| Category | Functions | Import Path |
|----------|-----------|-------------|
| Generative | `noise`, `fbm`, `voronoise`, `curl` | `lygia/generative/` |
| SDF | `circleSDF`, `boxSDF`, `lineSDF` | `lygia/sdf/` |
| Color | `luma`, `saturate`, `blend` | `lygia/color/` |
| Math | `rotate2d`, `scale2d`, `map` | `lygia/math/` |
| Lighting | `diffuse`, `specular`, `fresnel` | `lygia/lighting/` |

### Example: Lygia Noise

```glsl
// If using lygia via include/copy
// #include "lygia/generative/noise.glsl"

// Or copy the function directly:
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1,0)), u.x),
             mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}
```

## glslify

Node.js-based GLSL module system. Enables `#pragma glslify` imports.

### Setup

```bash
npm install glslify glslify-loader
```

**Webpack config:**
```javascript
module: {
  rules: [{
    test: /\.(glsl|frag|vert)$/,
    use: ['raw-loader', 'glslify-loader']
  }]
}
```

**Vite config (vite-plugin-glslify):**
```javascript
import glslify from 'vite-plugin-glslify';
export default { plugins: [glslify()] };
```

### Usage

```glsl
// myshader.frag
#pragma glslify: noise = require('glsl-noise/simplex/2d')
#pragma glslify: ease = require('glsl-easings/cubic-in-out')

void main() {
  float n = noise(vUv * 10.0);
  float t = ease(fract(u_time));
  gl_FragColor = vec4(vec3(n * t), 1.0);
}
```

### Popular glslify Packages

| Package | Purpose | Example |
|---------|---------|---------|
| `glsl-noise` | Simplex/perlin/cellular noise | `require('glsl-noise/simplex/3d')` |
| `glsl-easings` | Easing functions | `require('glsl-easings/exponential-out')` |
| `glsl-random` | Hash-based random | `require('glsl-random')` |
| `glsl-blend` | Photoshop blend modes | `require('glsl-blend/overlay')` |

### Three.js Integration

```javascript
import { ShaderMaterial } from 'three';
import frag from './myshader.frag'; // glslify processes this
import vert from './myshader.vert';

const material = new ShaderMaterial({
  vertexShader: vert,
  fragmentShader: frag,
  uniforms: { u_time: { value: 0 } }
});
```

## Shadertoy Patterns

Converting Shadertoy shaders to Three.js.

### Variable Mapping

| Shadertoy | Three.js | Notes |
|-----------|----------|-------|
| `iResolution` | `uniform vec2 u_resolution` | Set to canvas size |
| `iTime` | `uniform float u_time` | `clock.getElapsedTime()` |
| `iTimeDelta` | `uniform float u_delta` | `clock.getDelta()` |
| `iFrame` | `uniform int u_frame` | Increment per frame |
| `iMouse` | `uniform vec4 u_mouse` | (x, y, clickX, clickY) |
| `iChannel0-3` | `uniform sampler2D u_texture0-3` | Texture uniforms |
| `fragCoord` | `gl_FragCoord.xy` | Pixel coordinates |
| `fragColor` | `gl_FragColor` | Output color |

### Conversion Template

**Shadertoy original:**
```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec3 col = 0.5 + 0.5 * cos(iTime + uv.xyx + vec3(0, 2, 4));
  fragColor = vec4(col, 1.0);
}
```

**Three.js conversion:**
```glsl
precision highp float;
uniform vec2 u_resolution;
uniform float u_time;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec3 col = 0.5 + 0.5 * cos(u_time + uv.xyx + vec3(0, 2, 4));
  gl_FragColor = vec4(col, 1.0);
}
```

### Common Shadertoy Patterns

**Centered UV coordinates:**
```glsl
// Shadertoy style: center at (0,0), aspect-correct
vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

// Three.js equivalent:
vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution) / u_resolution.y;
```

**Multiple buffer conversion:**
Shadertoy's Buffer A/B/C/D require separate render targets in Three.js:
```javascript
const bufferA = new THREE.WebGLRenderTarget(width, height);
// Render pass A to bufferA
// Use bufferA.texture as uniform in main pass
```

## glsl-easings

Easing functions for smooth animations.

### Direct Copy (No Build Tool)

```glsl
// Cubic
float easeInCubic(float t) { return t * t * t; }
float easeOutCubic(float t) { float t1 = t - 1.0; return t1 * t1 * t1 + 1.0; }
float easeInOutCubic(float t) {
  return t < 0.5 ? 4.0 * t * t * t : (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0;
}

// Exponential
float easeInExpo(float t) { return t == 0.0 ? 0.0 : pow(2.0, 10.0 * (t - 1.0)); }
float easeOutExpo(float t) { return t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t); }

// Elastic
float easeOutElastic(float t) {
  return sin(-13.0 * (t + 1.0) * 3.14159 * 0.5) * pow(2.0, -10.0 * t) + 1.0;
}

// Bounce
float easeOutBounce(float t) {
  if (t < 1.0/2.75) return 7.5625 * t * t;
  if (t < 2.0/2.75) { t -= 1.5/2.75; return 7.5625 * t * t + 0.75; }
  if (t < 2.5/2.75) { t -= 2.25/2.75; return 7.5625 * t * t + 0.9375; }
  t -= 2.625/2.75; return 7.5625 * t * t + 0.984375;
}
```

### glslify Usage

```glsl
#pragma glslify: easeOutElastic = require('glsl-easings/elastic-out')

float t = easeOutElastic(fract(u_time));
```

## When to Use Which

| Situation | Recommendation |
|-----------|----------------|
| Quick prototype | Copy code directly from Lygia/this skill |
| Production build | glslify with npm packages |
| Porting Shadertoy | Manual conversion using mapping table |
| Single function needed | Copy from code-library.md |
| Many shader files | glslify module system |
