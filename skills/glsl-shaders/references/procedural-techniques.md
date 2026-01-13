# Procedural Techniques

## Table of Contents
- [Noise Functions](#noise-functions)
- [Signed Distance Fields (SDFs)](#signed-distance-fields-sdfs)
- [Pattern Generation](#pattern-generation)
- [Domain Operations](#domain-operations)

## Noise Functions

### Types of Noise

| Type | Characteristics | Use Cases |
|------|-----------------|-----------|
| Value | Simple, blocky | Basic variation |
| Perlin/Gradient | Smooth, flowing | Clouds, terrain |
| Simplex | Fast, fewer artifacts | Modern replacement for Perlin |
| Worley/Voronoi | Cellular, organic | Cracks, cells, water caustics |

### Hash Function (Pseudorandom)

```glsl
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
```

### 2D Value Noise

```glsl
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);  // Smoothstep

  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));

  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
```

### 3D Simplex Noise (Ashima)

```glsl
vec4 permute(vec4 x) { return mod(((x*34.0)+1.0)*x, 289.0); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314*r; }

float snoise(vec3 v) {
  const vec2 C = vec2(1.0/6.0, 1.0/3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

  vec3 i = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);

  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);

  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy;
  vec3 x3 = x0 - D.yyy;

  i = mod(i, 289.0);
  vec4 p = permute(permute(permute(
    i.z + vec4(0.0, i1.z, i2.z, 1.0))
  + i.y + vec4(0.0, i1.y, i2.y, 1.0))
  + i.x + vec4(0.0, i1.x, i2.x, 1.0));

  float n_ = 1.0/7.0;
  vec3 ns = n_ * D.wyz - D.xzx;
  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);

  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);

  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 s1 = floor(b1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);

  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
  p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;

  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}
```

### Fractal Brownian Motion (fBM)

Layer multiple octaves of noise:

```glsl
float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  float frequency = 1.0;

  for (int i = 0; i < 6; i++) {
    value += amplitude * noise(p * frequency);
    frequency *= 2.0;    // Lacunarity
    amplitude *= 0.5;    // Persistence
  }
  return value;
}

// 3D version
float fbm(vec3 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 5; i++) {
    value += amplitude * snoise(p);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}
```

### Domain Warping

Use noise to distort coordinates of another noise:

```glsl
float warpedNoise(vec2 p) {
  vec2 q = vec2(
    fbm(p + vec2(0.0, 0.0)),
    fbm(p + vec2(5.2, 1.3))
  );

  vec2 r = vec2(
    fbm(p + 4.0 * q + vec2(1.7, 9.2)),
    fbm(p + 4.0 * q + vec2(8.3, 2.8))
  );

  return fbm(p + 4.0 * r);
}
```

### Worley Noise (Voronoi)

```glsl
float worley(vec2 uv) {
  vec2 i = floor(uv);
  vec2 f = fract(uv);

  float minDist = 1.0;

  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 neighbor = vec2(float(x), float(y));
      vec2 point = hash2(i + neighbor);
      vec2 diff = neighbor + point - f;
      float dist = length(diff);
      minDist = min(minDist, dist);
    }
  }
  return minDist;
}

// For cell borders (second nearest - nearest)
float worleyEdge(vec2 uv) {
  vec2 i = floor(uv);
  vec2 f = fract(uv);

  float d1 = 1.0, d2 = 1.0;

  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 neighbor = vec2(float(x), float(y));
      vec2 point = hash2(i + neighbor);
      float d = length(neighbor + point - f);
      if (d < d1) { d2 = d1; d1 = d; }
      else if (d < d2) { d2 = d; }
    }
  }
  return d2 - d1;
}
```

## Signed Distance Fields (SDFs)

### 2D Primitives

```glsl
// Circle
float sdCircle(vec2 p, float r) {
  return length(p) - r;
}

// Box
float sdBox(vec2 p, vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Rounded Box
float sdRoundedBox(vec2 p, vec2 b, float r) {
  return sdBox(p, b) - r;
}

// Line Segment
float sdSegment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

// Equilateral Triangle
float sdTriangle(vec2 p, float r) {
  const float k = sqrt(3.0);
  p.x = abs(p.x) - r;
  p.y = p.y + r / k;
  if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
  p.x -= clamp(p.x, -2.0 * r, 0.0);
  return -length(p) * sign(p.y);
}
```

### 3D Primitives

```glsl
// Sphere
float sdSphere(vec3 p, float r) {
  return length(p) - r;
}

// Box
float sdBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Torus
float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

// Cylinder
float sdCylinder(vec3 p, float h, float r) {
  vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// Capsule
float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
  vec3 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - r;
}

// Plane
float sdPlane(vec3 p, vec3 n, float h) {
  return dot(p, n) + h;
}
```

### SDF Operations

```glsl
// Union (OR)
float opUnion(float d1, float d2) {
  return min(d1, d2);
}

// Intersection (AND)
float opIntersection(float d1, float d2) {
  return max(d1, d2);
}

// Subtraction (A - B)
float opSubtraction(float d1, float d2) {
  return max(d1, -d2);
}

// Smooth Union
float opSmoothUnion(float d1, float d2, float k) {
  float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Smooth Subtraction
float opSmoothSubtraction(float d1, float d2, float k) {
  float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
  return mix(d2, -d1, h) + k * h * (1.0 - h);
}

// Smooth Intersection
float opSmoothIntersection(float d1, float d2, float k) {
  float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) + k * h * (1.0 - h);
}
```

### Ray Marching

```glsl
float scene(vec3 p) {
  float ground = sdPlane(p, vec3(0, 1, 0), 0.0);
  float sphere = sdSphere(p - vec3(0, 1, 0), 1.0);
  return opUnion(ground, sphere);
}

vec3 calcNormal(vec3 p) {
  const float h = 0.0001;
  const vec2 k = vec2(1, -1);
  return normalize(
    k.xyy * scene(p + k.xyy * h) +
    k.yyx * scene(p + k.yyx * h) +
    k.yxy * scene(p + k.yxy * h) +
    k.xxx * scene(p + k.xxx * h)
  );
}

float raymarch(vec3 ro, vec3 rd) {
  float t = 0.0;
  for (int i = 0; i < 100; i++) {
    vec3 p = ro + rd * t;
    float d = scene(p);
    if (d < 0.001) return t;
    if (t > 100.0) break;
    t += d;
  }
  return -1.0;
}
```

## Pattern Generation

### Stripes

```glsl
// Horizontal stripes
float stripes(vec2 uv, float count) {
  return step(0.5, fract(uv.y * count));
}

// Diagonal stripes
float diagonalStripes(vec2 uv, float count, float angle) {
  vec2 rotated = vec2(
    uv.x * cos(angle) - uv.y * sin(angle),
    uv.x * sin(angle) + uv.y * cos(angle)
  );
  return step(0.5, fract(rotated.x * count));
}

// Smooth stripes
float smoothStripes(vec2 uv, float count) {
  return 0.5 + 0.5 * sin(uv.y * count * 6.28318);
}
```

### Checkerboard

```glsl
float checker(vec2 uv, float scale) {
  vec2 grid = floor(uv * scale);
  return mod(grid.x + grid.y, 2.0);
}
```

### Grid Lines

```glsl
// Note: fwidth requires material.extensions.derivatives = true in WebGL1
float grid(vec2 uv, float scale, float thickness) {
  vec2 grid = abs(fract(uv * scale - 0.5) - 0.5) / fwidth(uv * scale);
  float line = min(grid.x, grid.y);
  return 1.0 - min(line, 1.0);
}
```

### Polka Dots

```glsl
float dots(vec2 uv, float scale, float radius) {
  vec2 grid = fract(uv * scale) - 0.5;
  return 1.0 - step(radius, length(grid));
}
```

### Brick Pattern

```glsl
float brick(vec2 uv, vec2 size) {
  vec2 st = uv / size;
  st.x += step(1.0, mod(st.y, 2.0)) * 0.5;  // Offset every other row
  return (1.0 - step(0.92, fract(st.x))) * (1.0 - step(0.85, fract(st.y)));
}
```

## Domain Operations

### Repetition

```glsl
// Infinite repetition
vec2 repeat(vec2 p, vec2 c) {
  return mod(p + c * 0.5, c) - c * 0.5;
}

// Limited repetition (WebGL2/GLSL ES 3.00 - uses round())
vec2 repeatLimited(vec2 p, float s, vec2 limit) {
  return p - s * clamp(round(p / s), -limit, limit);
}

// ✅ WebGL1-compatible limited repetition
vec2 repeatLimitedES1(vec2 p, float s, vec2 limit) {
  return p - s * clamp(floor(p / s + 0.5), -limit, limit);
}
```

### Transformations

```glsl
// 2D Rotation
vec2 rotate2D(vec2 p, float a) {
  float s = sin(a), c = cos(a);
  return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// 3D Rotation around axis
vec3 rotateAxis(vec3 p, vec3 axis, float angle) {
  axis = normalize(axis);
  float c = cos(angle), s = sin(angle);
  return p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c);
}

// Symmetry (mirror) - apply abs() before SDF evaluation
// Example with circle:
float opSymmetryX(vec2 p, float radius) {
  p.x = abs(p.x);
  return sdCircle(p - vec2(0.3, 0.0), radius); // shifted circle mirrored on X
}
// Pattern: p.x = abs(p.x); then evaluate your SDF
```

### Distortions

```glsl
// Twist
vec3 opTwist(vec3 p, float k) {
  float c = cos(k * p.y);
  float s = sin(k * p.y);
  mat2 m = mat2(c, -s, s, c);
  return vec3(m * p.xz, p.y);
}

// Bend
vec3 opBend(vec3 p, float k) {
  float c = cos(k * p.x);
  float s = sin(k * p.x);
  mat2 m = mat2(c, -s, s, c);
  return vec3(m * p.xy, p.z);
}
```
