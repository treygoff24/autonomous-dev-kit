# GLSL Language Fundamentals

## Table of Contents
- [Data Types](#data-types)
- [Built-in Functions](#built-in-functions)
- [Precision Qualifiers](#precision-qualifiers)
- [Preprocessor Directives](#preprocessor-directives)
- [Uniforms and Varyings](#uniforms-and-varyings)
- [Common Patterns](#common-patterns)

## Data Types

### Scalars and Vectors

```glsl
float f = 1.0;       // Always use decimal point
int i = 5;           // Integer
bool b = true;

vec2 v2 = vec2(1.0, 2.0);           // 2D vector
vec3 v3 = vec3(1.0, 2.0, 3.0);      // 3D vector (positions, colors)
vec4 v4 = vec4(1.0, 2.0, 3.0, 1.0); // 4D vector (RGBA, homogeneous coords)

// Shorthand constructors
vec3 allOnes = vec3(1.0);           // (1.0, 1.0, 1.0)
vec4 fromVec3 = vec4(v3, 1.0);      // Extend vec3 with w=1.0
```

### Swizzling

Access and rearrange vector components:

```glsl
vec4 color = vec4(1.0, 0.5, 0.2, 1.0);
vec3 rgb = color.rgb;      // (1.0, 0.5, 0.2)
vec3 bgr = color.bgr;      // (0.2, 0.5, 1.0) - reorder
vec2 rg = color.rg;        // (1.0, 0.5)
float r = color.r;         // 1.0

// Can use xyzw or rgba interchangeably
vec3 pos = v4.xyz;
vec2 uv = v4.xy;

// Swizzle for assignment (no repeated components)
color.rg = vec2(0.5);      // OK
// color.rr = vec2(0.5);   // ERROR - can't assign to same component twice
```

### Matrices

```glsl
mat2 m2;  // 2x2
mat3 m3;  // 3x3 (often for normal transforms)
mat4 m4;  // 4x4 (transformations)

// Column-major: m[col][row]
mat4 identity = mat4(1.0);  // Identity matrix

// Matrix-vector multiplication
vec4 transformed = m4 * vec4(position, 1.0);
```

### Samplers

```glsl
uniform sampler2D diffuseMap;     // 2D texture
uniform samplerCube envMap;       // Cubemap
// WebGL2 also: sampler3D, sampler2DArray
```

## Built-in Functions

### Scalar/Vector Math

```glsl
// Clamping and interpolation
mix(a, b, t)          // Linear interpolate: a*(1-t) + b*t
clamp(x, min, max)    // Constrain to range
step(edge, x)         // 0 if x < edge, else 1
smoothstep(e0, e1, x) // Smooth Hermite interpolation 0→1

// Common math
abs(x)        sign(x)       floor(x)      ceil(x)
fract(x)      // x - floor(x)
mod(x, y)     // x - y * floor(x/y)
min(a, b)     max(a, b)
pow(x, y)     sqrt(x)       inversesqrt(x)
exp(x)        log(x)        exp2(x)       log2(x)
```

### Trigonometry

```glsl
sin(x)    cos(x)    tan(x)
asin(x)   acos(x)   atan(y, x)  // atan2
radians(degrees)    degrees(radians)
```

### Vector Operations

```glsl
length(v)           // Euclidean length
distance(a, b)      // length(a - b)
dot(a, b)           // Dot product
cross(a, b)         // Cross product (vec3 only)
normalize(v)        // Unit vector
reflect(I, N)       // Reflect I about normal N
refract(I, N, eta)  // Refract through surface
faceforward(N, I, Nref) // Flip N if facing away
```

### Texture Sampling

```glsl
// GLSL ES 1.0 (WebGL1)
texture2D(sampler, uv)           // Sample 2D texture
textureCube(sampler, direction)  // Sample cubemap

// GLSL ES 3.0 (WebGL2)
texture(sampler, coords)         // Unified for all sampler types
textureLod(sampler, coords, lod) // Explicit mipmap level
```

### Derivatives (Fragment Only)

```glsl
dFdx(f)   // Rate of change in screen X
dFdy(f)   // Rate of change in screen Y
fwidth(f) // abs(dFdx(f)) + abs(dFdy(f))

// WebGL1: Requires material.extensions.derivatives = true in Three.js
// WebGL2: Built-in, no extension needed
// Use for anti-aliasing procedural patterns:
float edge = smoothstep(0.5 - fwidth(value), 0.5 + fwidth(value), value);
```

## Precision Qualifiers

```glsl
precision highp float;   // Default for vertex, declare in fragment
precision mediump float; // Good for colors, UVs on mobile
precision lowp float;    // Rarely used

// Per-variable precision
highp vec3 worldPos;     // Large coordinates need highp
mediump vec3 color;      // Colors fine with mediump
```

**Guidelines:**
- Desktop GPUs typically use highp for all precisions (qualifiers still required in shader)
- Mobile: `mediump` = ~16-bit float, `highp` = ~32-bit (real performance impact)
- Use `highp` for: positions, accumulated values, large ranges
- Use `mediump` for: colors, UVs, normalized values

**Common precision bugs:**
- Banding/artifacts on mobile = precision too low
- Large coordinates becoming NaN = overflow in mediump

## Preprocessor Directives

```glsl
#define PI 3.14159265359
#define EPSILON 0.001

#ifdef USE_FOG
  // Fog code
#endif

#ifndef SOME_DEFINE
  #define SOME_DEFINE
#endif

// Three.js uses defines for material options:
#ifdef USE_NORMALMAP
  // Normal mapping code
#endif
```

**Three.js-specific:**
```glsl
// Include Three.js shader chunks
#include <common>           // PI, saturate(), etc.
#include <fog_pars_fragment> // Fog uniforms
#include <fog_fragment>      // Apply fog
```

**Enable extensions (WebGL1):**
```glsl
#extension GL_OES_standard_derivatives : enable
```

## Uniforms and Varyings

### Uniforms

Constant per draw call, set from JavaScript:

```glsl
uniform float u_time;
uniform vec2 u_resolution;
uniform vec3 u_color;
uniform sampler2D u_texture;
uniform mat4 u_customMatrix;
```

```javascript
// JavaScript setup
material.uniforms = {
  u_time: { value: 0 },
  u_resolution: { value: new THREE.Vector2(width, height) },
  u_color: { value: new THREE.Color(0xff0000) },
  u_texture: { value: myTexture }
};

// Update each frame
material.uniforms.u_time.value = clock.getElapsedTime();
```

### Varyings

Interpolated from vertex to fragment shader:

```glsl
// Vertex shader
varying vec2 vUv;
varying vec3 vNormal;
varying vec3 vPosition;

void main() {
  vUv = uv;
  vNormal = normalize(normalMatrix * normal);
  vPosition = (modelMatrix * vec4(position, 1.0)).xyz;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}

// Fragment shader
varying vec2 vUv;
varying vec3 vNormal;
varying vec3 vPosition;

void main() {
  // vUv, vNormal, vPosition are now interpolated per-pixel
}
```

### GLSL ES 3.0 (WebGL2) Syntax

```glsl
#version 300 es

// Vertex shader
in vec3 position;    // Instead of attribute
out vec2 vUv;        // Instead of varying

// Fragment shader
in vec2 vUv;         // Instead of varying
out vec4 fragColor;  // Instead of gl_FragColor
```

## Common Patterns

### Value Remapping

```glsl
// Remap x from [a,b] to [0,1]
float remap01(float x, float a, float b) {
  return clamp((x - a) / (b - a), 0.0, 1.0);
}

// Remap x from [a,b] to [c,d]
float remap(float x, float a, float b, float c, float d) {
  return mix(c, d, (x - a) / (b - a));
}
```

### Soft Threshold

```glsl
// Hard threshold
float hard = step(0.5, value);

// Soft threshold (anti-aliased)
float soft = smoothstep(0.5 - edge, 0.5 + edge, value);

// Using derivatives for consistent edge width
float aa = smoothstep(0.5 - fwidth(value), 0.5 + fwidth(value), value);
```

### Polar Coordinates

```glsl
vec2 toPolar(vec2 uv) {
  vec2 centered = uv - 0.5;
  float r = length(centered);
  float theta = atan(centered.y, centered.x);
  return vec2(r, theta);
}

vec2 fromPolar(float r, float theta) {
  return vec2(cos(theta), sin(theta)) * r + 0.5;
}
```

### 2D Rotation

```glsl
vec2 rotate2D(vec2 p, float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}
```
