# Code Library

Copy-paste ready GLSL code snippets organized by category.

## Table of Contents
- [Noise Functions](#noise-functions)
- [SDF Primitives](#sdf-primitives)
- [SDF Operations](#sdf-operations)
- [Utility Functions](#utility-functions)
- [Color Functions](#color-functions)
- [Easing Functions](#easing-functions)
- [Complete Shader Templates](#complete-shader-templates)

## Noise Functions

### Hash (Pseudorandom)

```glsl
float hash(float n) {
  return fract(sin(n) * 43758.5453123);
}

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 hash2(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash3(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// 3D hash - required for 3D noise
float hash(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.zyx + 31.32);
  return fract((p.x + p.y) * p.z);
}
```

### 2D Value Noise

```glsl
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);

  return mix(
    mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}
```

### 3D Value Noise

```glsl
float noise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  vec3 u = f * f * (3.0 - 2.0 * f);

  return mix(
    mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), u.x),
        mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), u.x), u.y),
    mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), u.x),
        mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), u.x), u.y),
    u.z
  );
}
```

### Fractal Brownian Motion (fBM)

```glsl
// ⚠️ WebGL2/GLSL ES 3.00 only - dynamic loop bounds not allowed in ES 1.00
float fbm(vec2 p, int octaves) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < octaves; i++) {
    value += amplitude * noise(p);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

// ✅ WebGL1-compatible: Fixed 5-octave version (no dynamic loop)
float fbm5(vec2 p) {
  float v = 0.0;
  v += 0.5000 * noise(p); p *= 2.0;
  v += 0.2500 * noise(p); p *= 2.0;
  v += 0.1250 * noise(p); p *= 2.0;
  v += 0.0625 * noise(p); p *= 2.0;
  v += 0.03125 * noise(p);
  return v;
}
```

### Worley Noise (Voronoi)

```glsl
float worley(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);

  float minDist = 1.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 neighbor = vec2(float(x), float(y));
      vec2 point = hash2(i + neighbor);
      float d = length(neighbor + point - f);
      minDist = min(minDist, d);
    }
  }
  return minDist;
}
```

## SDF Primitives

### 2D Shapes

```glsl
float sdCircle(vec2 p, float r) {
  return length(p) - r;
}

float sdBox(vec2 p, vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdRoundedBox(vec2 p, vec2 b, float r) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

float sdHexagon(vec2 p, float r) {
  const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
  p = abs(p);
  p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
  p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
  return length(p) * sign(p.y);
}

float sdTriangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
  vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
  vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
  vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
  vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
  vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
  float s = sign(e0.x * e2.y - e0.y * e2.x);
  vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                   vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                   vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
  return -sqrt(d.x) * sign(d.y);
}
```

### 3D Shapes

```glsl
float sdSphere(vec3 p, float r) {
  return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdRoundBox(vec3 p, vec3 b, float r) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

float sdCylinder(vec3 p, float h, float r) {
  vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
  vec3 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - r;
}

float sdCone(vec3 p, vec2 c, float h) {
  vec2 q = h * vec2(c.x / c.y, -1.0);
  vec2 w = vec2(length(p.xz), p.y);
  vec2 a = w - q * clamp(dot(w, q) / dot(q, q), 0.0, 1.0);
  vec2 b = w - q * vec2(clamp(w.x / q.x, 0.0, 1.0), 1.0);
  float k = sign(q.y);
  float d = min(dot(a, a), dot(b, b));
  float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
  return sqrt(d) * sign(s);
}

float sdPlane(vec3 p, vec3 n, float h) {
  return dot(p, n) + h;
}
```

## SDF Operations

```glsl
// Boolean operations
float opUnion(float d1, float d2) { return min(d1, d2); }
float opSubtraction(float d1, float d2) { return max(d1, -d2); }
float opIntersection(float d1, float d2) { return max(d1, d2); }

// Smooth boolean operations
float opSmoothUnion(float d1, float d2, float k) {
  float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

float opSmoothSubtraction(float d1, float d2, float k) {
  float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
  return mix(d2, -d1, h) + k * h * (1.0 - h);
}

float opSmoothIntersection(float d1, float d2, float k) {
  float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) + k * h * (1.0 - h);
}

// Domain operations
vec2 opRepeat(vec2 p, vec2 c) {
  return mod(p + 0.5 * c, c) - 0.5 * c;
}

vec3 opRepeat(vec3 p, vec3 c) {
  return mod(p + 0.5 * c, c) - 0.5 * c;
}

float opRound(float d, float r) { return d - r; }
float opOnion(float d, float t) { return abs(d) - t; }
```

## Utility Functions

```glsl
// Constants
#define PI 3.14159265359
#define TAU 6.28318530718
#define E 2.71828182846

// Saturate (clamp 0-1)
float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3 saturate(vec3 x) { return clamp(x, 0.0, 1.0); }

// Remap value from one range to another
float remap(float value, float inMin, float inMax, float outMin, float outMax) {
  return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

// 2D Rotation
vec2 rotate2D(vec2 p, float angle) {
  float s = sin(angle), c = cos(angle);
  return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// 3D Rotation around axis (Rodrigues' formula)
vec3 rotateAxis(vec3 p, vec3 axis, float angle) {
  axis = normalize(axis);
  float c = cos(angle), s = sin(angle);
  return p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c);
}

// Polar coordinates
vec2 toPolar(vec2 p) {
  return vec2(length(p), atan(p.y, p.x));
}

vec2 fromPolar(vec2 polar) {
  return vec2(cos(polar.y), sin(polar.y)) * polar.x;
}

// Smooth minimum (for blending)
float smin(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

// Smooth maximum
float smax(float a, float b, float k) {
  return -smin(-a, -b, k);
}
```

## Color Functions

```glsl
// RGB to HSV
vec3 rgb2hsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Hue shift
vec3 hueShift(vec3 color, float shift) {
  vec3 hsv = rgb2hsv(color);
  hsv.x = fract(hsv.x + shift);
  return hsv2rgb(hsv);
}

// Luminance
float luminance(vec3 color) {
  return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// Contrast
vec3 contrast(vec3 color, float amount) {
  return (color - 0.5) * amount + 0.5;
}

// Saturation
vec3 saturation(vec3 color, float amount) {
  float gray = luminance(color);
  return mix(vec3(gray), color, amount);
}

// Palette (IQ's technique)
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
  return a + b * cos(TAU * (c * t + d));
}
```

## Easing Functions

```glsl
float easeInQuad(float t) { return t * t; }
float easeOutQuad(float t) { return t * (2.0 - t); }
float easeInOutQuad(float t) {
  return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t;
}

float easeInCubic(float t) { return t * t * t; }
float easeOutCubic(float t) { float t1 = t - 1.0; return t1 * t1 * t1 + 1.0; }
float easeInOutCubic(float t) {
  return t < 0.5 ? 4.0 * t * t * t : (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0;
}

float easeInExpo(float t) { return t == 0.0 ? 0.0 : pow(2.0, 10.0 * (t - 1.0)); }
float easeOutExpo(float t) { return t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t); }

float easeInSine(float t) { return 1.0 - cos(t * PI * 0.5); }
float easeOutSine(float t) { return sin(t * PI * 0.5); }
float easeInOutSine(float t) { return 0.5 * (1.0 - cos(PI * t)); }

float easeOutElastic(float t) {
  return sin(-13.0 * (t + 1.0) * PI * 0.5) * pow(2.0, -10.0 * t) + 1.0;
}

float easeOutBounce(float t) {
  if (t < 1.0/2.75) return 7.5625 * t * t;
  if (t < 2.0/2.75) { t -= 1.5/2.75; return 7.5625 * t * t + 0.75; }
  if (t < 2.5/2.75) { t -= 2.25/2.75; return 7.5625 * t * t + 0.9375; }
  t -= 2.625/2.75;
  return 7.5625 * t * t + 0.984375;
}
```

## Complete Shader Templates

### Basic Lit ShaderMaterial

```javascript
const material = new THREE.ShaderMaterial({
  uniforms: {
    u_color: { value: new THREE.Color(0x4488ff) },
    u_lightDir: { value: new THREE.Vector3(0.5, 1.0, 0.3).normalize() }
  },
  vertexShader: `
    varying vec3 vNormal;
    varying vec2 vUv;
    void main() {
      vNormal = normalize(normalMatrix * normal);
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    precision highp float;
    uniform vec3 u_color;
    uniform vec3 u_lightDir;
    varying vec3 vNormal;
    varying vec2 vUv;

    void main() {
      vec3 normal = normalize(vNormal);
      float diff = max(dot(normal, u_lightDir), 0.0);
      float ambient = 0.2;
      vec3 color = u_color * (ambient + diff * 0.8);
      gl_FragColor = vec4(color, 1.0);
    }
  `
});
```

### Post-Processing Pass

```javascript
const postMaterial = new THREE.ShaderMaterial({
  uniforms: {
    tDiffuse: { value: null },
    u_resolution: { value: new THREE.Vector2() }
  },
  vertexShader: `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    precision highp float;
    uniform sampler2D tDiffuse;
    uniform vec2 u_resolution;
    varying vec2 vUv;

    void main() {
      vec4 color = texture2D(tDiffuse, vUv);
      // Apply effect here
      gl_FragColor = color;
    }
  `
});
```

### Fullscreen Quad (Raw)

```javascript
const geometry = new THREE.PlaneGeometry(2, 2);
const material = new THREE.RawShaderMaterial({
  uniforms: {
    u_time: { value: 0 },
    u_resolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) }
  },
  vertexShader: `
    precision highp float;
    attribute vec3 position;
    attribute vec2 uv;
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = vec4(position.xy, 0.0, 1.0);
    }
  `,
  fragmentShader: `
    precision highp float;
    uniform float u_time;
    uniform vec2 u_resolution;
    varying vec2 vUv;

    void main() {
      vec2 uv = vUv;
      // Shadertoy-style: vec2 uv = gl_FragCoord.xy / u_resolution.xy;
      gl_FragColor = vec4(uv, 0.5 + 0.5 * sin(u_time), 1.0);
    }
  `
});

const mesh = new THREE.Mesh(geometry, material);
scene.add(mesh);
```
