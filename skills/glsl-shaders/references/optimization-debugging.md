# Performance Optimization & Debugging

## Table of Contents
- [Performance Guidelines](#performance-guidelines)
- [Common Optimizations](#common-optimizations)
- [Debugging Techniques](#debugging-techniques)
- [Tools](#tools)
- [Porting Shaders](#porting-shaders)

## Performance Guidelines

### Avoid Divergent Branching

GPUs execute threads in groups (warps/wavefronts). If threads diverge on a branch, both paths execute:

```glsl
// BAD: Per-pixel branch on varying data
if (vUv.x > 0.5) {
  color = expensive1();
} else {
  color = expensive2();
}

// GOOD: Use mix/step for smooth transitions
float mask = step(0.5, vUv.x);
color = mix(result1, result2, mask);

// GOOD: Branch on uniform (same for all pixels)
if (u_useEffect) {
  // All pixels take same path
}
```

**When branching IS okay:**
- Condition based on uniform (coherent)
- Early exit that skips significant work
- Large spatial regions take same path

### Minimize Texture Lookups

```glsl
// BAD: Redundant fetches
vec4 tex1 = texture2D(map, uv);
float r = texture2D(map, uv).r;  // Fetches again!

// GOOD: Fetch once, reuse
vec4 tex = texture2D(map, uv);
float r = tex.r;
```

**Texture access tips:**
- Fetch once, store in variable
- Use mipmaps to avoid aliasing (reduces texture cache thrashing)
- Consider downsampled passes for blur/bloom
- Dependent texture reads (UV from another texture) can be slower

### Precision Selection

```glsl
precision highp float;  // Fragment shader default

// Per-variable precision
highp vec3 worldPos;    // Large coordinates need highp
mediump vec3 color;     // Colors fine with mediump
lowp float visibility;  // Simple flags
```

| Use Case | Precision |
|----------|-----------|
| World positions | highp |
| Accumulated values | highp |
| Colors (0-1) | mediump |
| UVs (0-1) | mediump |
| Normalized vectors | mediump |
| Simple flags | lowp |

**Desktop:** Ignores precision qualifiers (always highp)
**Mobile:** Real performance impact; mediump = ~16-bit float

### Math Optimizations

```glsl
// Prefer specialized over generic
x * x                  // Instead of pow(x, 2.0)
sqrt(x)                // Instead of pow(x, 0.5)
inversesqrt(x)         // Instead of 1.0/sqrt(x)

// Avoid division when possible
x * 0.5                // Instead of x / 2.0
x * invY               // Precompute inverse if dividing multiple times

// Distance comparison without sqrt
dot(v, v) < r*r        // Instead of length(v) < r
```

### Loop Optimization

```glsl
// Fixed count loops can be unrolled
for (int i = 0; i < 8; i++) { ... }  // Compiler may unroll

// Dynamic loops prevent unrolling
for (int i = 0; i < u_count; i++) { ... }  // Can't unroll

// Consider manual unrolling for critical paths
color += texture2D(map, uv + offset0) * weight0;
color += texture2D(map, uv + offset1) * weight1;
color += texture2D(map, uv + offset2) * weight2;
// ... instead of loop
```

### Move Work to Vertex Shader

Vertex shader runs per-vertex; fragment runs per-pixel (many more):

```glsl
// BAD: Expensive computation per pixel
void main() {
  vec3 lightDir = normalize(u_lightPos - vWorldPos);
  // ... if light position is constant
}

// GOOD: Compute per-vertex, interpolate
// Vertex:
vLightDir = normalize(u_lightPos - worldPos);
// Fragment:
vec3 lightDir = normalize(vLightDir);  // Just renormalize
```

## Common Optimizations

### Optimization Checklist

- [ ] Use appropriate precision (mediump for colors/UVs)
- [ ] Remove dead code and unused varyings
- [ ] Minimize texture lookups in loops
- [ ] Replace branches with mix/step where possible
- [ ] Compute per-vertex when result can be interpolated
- [ ] Use fixed loop counts for unrolling
- [ ] Consider downsampled passes for heavy effects
- [ ] Profile on target device (desktop != mobile)

### Mobile-Specific

- Tile-based GPUs (Mali, PowerVR, Adreno) have different bottlenecks
- `discard` can break early-z optimization on some GPUs
- Half precision (mediump) can double throughput on some hardware
- Minimize varying count (8 vec4 max on some devices)
- Avoid excessive overdraw with transparent materials

## Debugging Techniques

### Visualization Debugging

Output intermediate values as colors:

```glsl
// Debug normals
gl_FragColor = vec4(vNormal * 0.5 + 0.5, 1.0);

// Debug UVs
gl_FragColor = vec4(vUv, 0.0, 1.0);

// Debug depth
gl_FragColor = vec4(vec3(gl_FragCoord.z), 1.0);

// Debug scalar value
gl_FragColor = vec4(vec3(someValue), 1.0);

// Debug if value is in range
float v = clamp(someValue, 0.0, 1.0);
gl_FragColor = vec4(v, 1.0 - v, 0.0, 1.0);  // Green=low, Red=high

// Detect NaN (WebGL2/GLSL ES 3.00 only)
if (isnan(value)) {
  gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);  // Magenta = NaN
  return;
}
// ✅ WebGL1 alternative: NaN != NaN
if (value != value) { /* value is NaN */ }

// Detect Infinity (WebGL2/GLSL ES 3.00 only)
if (isinf(value)) {
  gl_FragColor = vec4(0.0, 1.0, 1.0, 1.0);  // Cyan = Inf
  return;
}
// ✅ WebGL1 alternative: Inf * 0.0 = NaN
if (value * 0.0 != 0.0) { /* value is Inf or NaN */ }
```

### Black Screen Troubleshooting

1. **Check console for compile errors**
   - Look for GLSL syntax errors
   - Missing precision declaration in fragment
   - Undeclared variables/functions

2. **Verify basic rendering**
   ```glsl
   gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);  // Should be solid red
   ```

3. **Check vertex transform**
   ```glsl
   // Ensure gl_Position is set correctly
   gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
   ```

4. **Verify uniforms are bound**
   ```javascript
   console.log(material.uniforms);  // Check values
   // Textures must be loaded before use
   ```

5. **Check alpha and blending**
   ```javascript
   material.transparent = true;  // If using alpha
   material.depthWrite = false;  // For transparent objects
   ```

6. **Check face culling**
   ```javascript
   material.side = THREE.DoubleSide;  // Rule out backface culling
   ```

### Common Causes of NaN

```glsl
// Division by zero
float bad = 1.0 / 0.0;  // Inf
float worse = 0.0 / 0.0;  // NaN

// Normalize zero vector
vec3 bad = normalize(vec3(0.0));  // NaN

// Square root of negative
float bad = sqrt(-1.0);  // NaN

// Fixes
vec3 safe = normalize(v + vec3(0.0001));  // Add epsilon
float safe = sqrt(max(x, 0.0));           // Clamp before sqrt
float safe = x / max(y, 0.0001);          // Prevent div by zero
```

### Precision Issues (Mobile)

Symptoms:
- Banding in gradients
- Flickering at large coordinates
- Values becoming zero or infinity

Fixes:
```glsl
// Use highp for large values
highp float worldX = vWorldPosition.x;

// Center coordinates to reduce magnitude
vec3 localPos = vWorldPosition - u_centerOffset;

// Scale down large numbers
float scaled = largeValue * 0.001;
```

## Tools

### Spector.js

WebGL inspector for Chrome/Firefox:
- Capture frame and inspect all draw calls
- View compiled shader source (with includes expanded)
- Check uniform values at draw time
- Debug texture bindings

```javascript
// Install: npm install spector.js
// Or browser extension
```

### Browser Shader Editor

**Firefox:** Built-in Shader Editor (F12 → Network → Shaders)
- Live edit and recompile shaders
- See changes immediately

**Chrome:** Shader Editor extension
- Similar functionality

### Debug Material Settings

```javascript
// Log compiled shader
material.onBeforeCompile = (shader) => {
  console.log('VERTEX:', shader.vertexShader);
  console.log('FRAGMENT:', shader.fragmentShader);
};

// Force shader error check
renderer.debug.checkShaderErrors = true;
```

### Performance Profiling

```javascript
// Chrome DevTools Performance tab
// Look for GPU time in frame breakdown

// Or use Spector.js timing per draw call
```

## Porting Shaders

### Shadertoy → Three.js

| Shadertoy | Three.js Equivalent |
|-----------|---------------------|
| `iResolution` | `uniform vec2 u_resolution` |
| `iTime` | `uniform float u_time` |
| `iTimeDelta` | `uniform float u_delta` |
| `iFrame` | `uniform int u_frame` |
| `iMouse` | `uniform vec4 u_mouse` |
| `iChannel0-3` | `uniform sampler2D u_texture0-3` |
| `fragCoord` | `gl_FragCoord.xy` |
| `fragColor` | `gl_FragColor` |
| `mainImage(out vec4, in vec2)` | `void main()` |

**Conversion template:**
```glsl
// Shadertoy
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  fragColor = vec4(uv, 0.0, 1.0);
}

// Three.js
precision highp float;
uniform vec2 u_resolution;
void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  gl_FragColor = vec4(uv, 0.0, 1.0);
}
```

### HLSL → GLSL

| HLSL | GLSL |
|------|------|
| `float4` | `vec4` |
| `float3` | `vec3` |
| `float2` | `vec2` |
| `float3x3` | `mat3` |
| `lerp(a,b,t)` | `mix(a,b,t)` |
| `saturate(x)` | `clamp(x,0.0,1.0)` |
| `frac(x)` | `fract(x)` |
| `mul(M,v)` | `M * v` |
| `clip(x)` | `if(x<0.0) discard;` |
| `tex2D(s,uv)` | `texture2D(s,uv)` |
| `ddx/ddy` | `dFdx/dFdy` |

**Matrix multiplication:** HLSL is often row-major, GLSL is column-major. May need to transpose or reverse multiplication order.

### GLSL ES 1.0 → 3.0 (WebGL1 → WebGL2)

| ES 1.0 | ES 3.0 |
|--------|--------|
| `attribute` | `in` (vertex) |
| `varying` | `out` (vertex), `in` (fragment) |
| `gl_FragColor` | `out vec4 fragColor` |
| `texture2D` | `texture` |
| `textureCube` | `texture` |

```glsl
// ES 3.0 requires version directive
#version 300 es
precision highp float;

// Vertex
in vec3 position;
out vec2 vUv;

// Fragment
in vec2 vUv;
out vec4 fragColor;

void main() {
  fragColor = vec4(vUv, 0.0, 1.0);
}
```
