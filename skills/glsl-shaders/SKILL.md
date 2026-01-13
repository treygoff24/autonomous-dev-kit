---
name: glsl-shaders
description: This skill should be used when the user asks to write/debug GLSL shaders, create custom materials/effects, implement procedural noise/SDFs, port Shadertoy/Unity/HLSL shaders, optimize shader performance, or build post-processing effects in Three.js/WebGL.
---

# GLSL Shader Mastery for Three.js

Use this workflow to create, debug, and optimize GLSL shaders. Load the reference file that matches the task.

## Quick Reference

### Shader Pipeline Mental Model

```
Vertex Shader (per vertex)          Fragment Shader (per pixel)
─────────────────────────           ───────────────────────────
Input: attributes (position,        Input: varyings (interpolated),
       normal, uv)                         uniforms, samplers
       uniforms (matrices)

Output: gl_Position (clip space)    Output: gl_FragColor (RGBA)
        varyings to fragment
```

### Essential GLSL Functions

| Category | Functions |
|----------|-----------|
| Math | `mix`, `clamp`, `step`, `smoothstep`, `fract`, `mod`, `abs`, `sign`, `floor`, `ceil` |
| Trig | `sin`, `cos`, `tan`, `atan`, `radians`, `degrees` |
| Vector | `dot`, `cross`, `normalize`, `length`, `distance`, `reflect`, `refract` |
| Texture | `texture2D` (GLSL100) / `texture` (GLSL300) |
| Derivatives | `dFdx`, `dFdy`, `fwidth` (fragment only) |

### Three.js Built-in Uniforms (ShaderMaterial)

```glsl
// Matrices (auto-provided)
uniform mat4 modelMatrix;      // object → world
uniform mat4 viewMatrix;       // world → camera
uniform mat4 projectionMatrix; // camera → clip
uniform mat4 modelViewMatrix;  // object → camera
uniform mat3 normalMatrix;     // for transforming normals

// Camera
uniform vec3 cameraPosition;   // world space

// Attributes (auto-provided)
attribute vec3 position;
attribute vec3 normal;
attribute vec2 uv;
```

## Decision Tree: Which Approach?

```
Need custom shader?
├─ Full control, unlit effect → ShaderMaterial
├─ Bare metal, no Three.js helpers → RawShaderMaterial
├─ Tweak built-in material (Standard, Phong) → onBeforeCompile
└─ Full-screen post-process → EffectComposer + ShaderPass
```

## Core Patterns

### 1. Basic ShaderMaterial Template

```javascript
const mat = new THREE.ShaderMaterial({
  vertexShader: `
    varying vec2 vUv;
    varying vec3 vNormal;
    void main() {
      vUv = uv;
      vNormal = normalize(normalMatrix * normal);
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    precision highp float;
    uniform float u_time;
    uniform sampler2D u_texture;
    varying vec2 vUv;
    varying vec3 vNormal;
    void main() {
      vec4 tex = texture2D(u_texture, vUv);
      gl_FragColor = vec4(tex.rgb, 1.0);
    }
  `,
  uniforms: {
    u_time: { value: 0 },
    u_texture: { value: myTexture }
  }
});
// Update each frame: mat.uniforms.u_time.value = clock.getElapsedTime();
```

### 2. Extending Built-in Materials (onBeforeCompile)

```javascript
const mat = new THREE.MeshStandardMaterial({ map: texture });
mat.onBeforeCompile = (shader) => {
  shader.uniforms.u_time = { value: 0 };

  // Inject uniform declaration
  shader.fragmentShader = shader.fragmentShader.replace(
    '#include <common>',
    `#include <common>
     uniform float u_time;`
  );

  // Modify output (after dithering is a good hook point)
  shader.fragmentShader = shader.fragmentShader.replace(
    '#include <dithering_fragment>',
    `#include <dithering_fragment>
     gl_FragColor.rgb *= 0.5 + 0.5 * sin(u_time);`
  );

  mat.userData.shader = shader; // Store for updating
};
// Update: mat.userData.shader.uniforms.u_time.value = time;
```

### 3. Common Effect Formulas

```glsl
// Fresnel (rim lighting)
float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 3.0);

// Dissolve threshold
float noise = texture2D(noiseTex, vUv).r;
if (noise > u_dissolve) discard;

// Toon shading (quantized lighting)
float NdotL = max(dot(normal, lightDir), 0.0);
float toon = floor(min(NdotL, 0.999) * 3.0) / 2.0; // 3 bands

// UV scrolling
vec2 scrollUV = vUv + u_time * vec2(0.1, 0.0);

// Pulsing glow
float pulse = 0.5 + 0.5 * sin(u_time * 3.0);
```

## Debugging Checklist

**Black screen?**
1. Check console for compile errors
2. Output solid color: `gl_FragColor = vec4(1,0,0,1);`
3. Check `gl_Position` is set correctly
4. Verify uniforms are bound (especially textures)
5. Check alpha isn't 0 with transparent material

**NaN/artifacts?**
- Look for: `0.0/0.0`, `sqrt(negative)`, `normalize(vec3(0))`
- Debug: `if(val != val) gl_FragColor = vec4(1,0,1,1);` (WebGL1: NaN != NaN)

**Visualize values:**
```glsl
gl_FragColor = vec4(vNormal * 0.5 + 0.5, 1.0); // normals
gl_FragColor = vec4(vec3(depth), 1.0);          // depth
gl_FragColor = vec4(vec3(fract(u_time)), 1.0);  // time flowing
```

## Reference Files

| Need | File |
|------|------|
| GLSL syntax, types, precision | [glsl-fundamentals.md](references/glsl-fundamentals.md) |
| Three.js integration patterns | [threejs-integration.md](references/threejs-integration.md) |
| Noise, SDFs, patterns | [procedural-techniques.md](references/procedural-techniques.md) |
| Effect recipes (dissolve, glow, etc.) | [visual-effects.md](references/visual-effects.md) |
| Performance & debugging | [optimization-debugging.md](references/optimization-debugging.md) |
| Copy-paste code snippets | [code-library.md](references/code-library.md) |
| Lygia, glslify, Shadertoy conversion | [shader-ecosystem.md](references/shader-ecosystem.md) |
| WebGL2, MRT, GPGPU, instancing | [advanced-topics.md](references/advanced-topics.md) |

## Porting Quick Reference

### Shadertoy → Three.js

| Shadertoy | Three.js |
|-----------|----------|
| `iResolution` | `uniform vec2 u_resolution` |
| `iTime` | `uniform float u_time` |
| `iMouse` | `uniform vec4 u_mouse` |
| `fragCoord` | `gl_FragCoord.xy` or `vUv * resolution` |
| `fragColor` | `gl_FragColor` |
| `mainImage(out vec4, in vec2)` | `void main()` |

### HLSL → GLSL

| HLSL | GLSL |
|------|------|
| `float4` | `vec4` |
| `lerp(a,b,t)` | `mix(a,b,t)` |
| `saturate(x)` | `clamp(x,0.0,1.0)` |
| `frac(x)` | `fract(x)` |
| `mul(M,v)` | `M * v` (may need transpose) |
| `clip(x)` | `if(x<0.0) discard;` |

## Performance Rules of Thumb

1. **Avoid per-pixel branches** on varying data (use `mix`/`step` instead)
2. **Minimize texture lookups** in loops
3. **Use `mediump`** for colors/UVs, `highp` for positions
4. **Compute per-vertex** when possible, interpolate to fragment
5. **Unroll small loops** or use fixed iteration counts
