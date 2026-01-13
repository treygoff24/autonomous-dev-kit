# Advanced WebGL Topics

WebGL2 (GLSL ES 3.00) features and GPGPU techniques.

## Table of Contents
- [WebGL2 Features](#webgl2-features)
- [Multiple Render Targets (MRT)](#multiple-render-targets-mrt)
- [Float Textures](#float-textures)
- [Transform Feedback (GPGPU)](#transform-feedback-gpgpu)
- [Texture Arrays](#texture-arrays)
- [Instanced Rendering](#instanced-rendering)

## WebGL2 Features

**WebGL2 Requirements:**
- GLSL ES 3.00 (`#version 300 es`)
- `attribute` → `in`, `varying` → `out/in`
- `texture2D()` → `texture()`
- `gl_FragColor` → declared `out vec4 fragColor`

```glsl
#version 300 es
precision highp float;

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D u_texture;

void main() {
  fragColor = texture(u_texture, vUv);
}
```

### Three.js WebGL2 Setup

```javascript
const canvas = document.querySelector('#canvas');
const renderer = new THREE.WebGLRenderer({
  canvas,
  context: canvas.getContext('webgl2')
});

// Check WebGL2 support
if (!renderer.capabilities.isWebGL2) {
  console.warn('WebGL2 not supported, falling back to WebGL1');
}
```

## Multiple Render Targets (MRT)

Render to multiple textures in a single pass. Useful for deferred rendering, G-buffers.

### Three.js Setup

```javascript
const renderTarget = new THREE.WebGLMultipleRenderTargets(
  window.innerWidth,
  window.innerHeight,
  3 // number of textures
);

// Configure each texture (these are COLOR attachments, not depth)
renderTarget.texture[0].name = 'diffuse';
renderTarget.texture[1].name = 'normal';
renderTarget.texture[2].name = 'position'; // Store world position; for true depth use renderTarget.depthTexture

// Set format for each (optional)
renderTarget.texture.forEach(tex => {
  tex.minFilter = THREE.NearestFilter;
  tex.magFilter = THREE.NearestFilter;
});
```

### Fragment Shader (GLSL ES 3.00)

```glsl
#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vWorldPosition;
in vec2 vUv;

layout(location = 0) out vec4 gDiffuse;
layout(location = 1) out vec4 gNormal;
layout(location = 2) out vec4 gPosition;

uniform sampler2D u_albedo;

void main() {
  gDiffuse = texture(u_albedo, vUv);
  gNormal = vec4(normalize(vNormal) * 0.5 + 0.5, 1.0);
  gPosition = vec4(vWorldPosition, 1.0);
}
```

### Using MRT Output

```javascript
// After rendering to MRT, use textures in composite pass
compositeMaterial.uniforms.tDiffuse.value = renderTarget.texture[0];
compositeMaterial.uniforms.tNormal.value = renderTarget.texture[1];
compositeMaterial.uniforms.tPosition.value = renderTarget.texture[2];
```

## Float Textures

Store floating-point data in textures for physics, particles, GPGPU.

### Creating Float Textures

```javascript
// Check support
const floatSupport = renderer.capabilities.floatFragmentTextures;
const halfFloatSupport = renderer.capabilities.halfFloatFragmentTextures;

// Create data texture
const width = 256;
const height = 256;
const data = new Float32Array(width * height * 4); // RGBA

// Initialize with positions
for (let i = 0; i < width * height; i++) {
  const i4 = i * 4;
  data[i4 + 0] = Math.random() * 2 - 1; // x
  data[i4 + 1] = Math.random() * 2 - 1; // y
  data[i4 + 2] = Math.random() * 2 - 1; // z
  data[i4 + 3] = 1.0;                   // w
}

const texture = new THREE.DataTexture(
  data,
  width,
  height,
  THREE.RGBAFormat,
  THREE.FloatType
);
texture.needsUpdate = true;
```

### Float Render Target

```javascript
const floatRT = new THREE.WebGLRenderTarget(width, height, {
  type: THREE.FloatType,
  format: THREE.RGBAFormat,
  minFilter: THREE.NearestFilter,
  magFilter: THREE.NearestFilter
});
```

### GPGPU Pattern (Ping-Pong)

```javascript
// Two render targets for double-buffering
const rtA = createFloatRT();
const rtB = createFloatRT();
let read = rtA, write = rtB;

function gpgpuUpdate() {
  // Swap buffers
  [read, write] = [write, read];

  // Read from previous, write to current
  updateMaterial.uniforms.tPrevious.value = read.texture;
  renderer.setRenderTarget(write);
  renderer.render(gpgpuScene, gpgpuCamera);
  renderer.setRenderTarget(null);

  // Use result
  particleMaterial.uniforms.tPositions.value = write.texture;
}
```

## Transform Feedback (GPGPU)

WebGL2 feature for GPU-side particle/physics updates without render targets.

### Basic Setup

```javascript
// Raw WebGL2 approach (Three.js doesn't wrap this directly)
const gl = renderer.getContext();

// Create transform feedback object
const tf = gl.createTransformFeedback();
gl.bindTransformFeedback(gl.TRANSFORM_FEEDBACK, tf);

// Specify output varyings BEFORE linking program
gl.transformFeedbackVaryings(program, ['v_position', 'v_velocity'], gl.INTERLEAVED_ATTRIBS);
gl.linkProgram(program);
```

### Vertex Shader for Transform Feedback

```glsl
#version 300 es

in vec3 a_position;
in vec3 a_velocity;

out vec3 v_position;  // Transform feedback output
out vec3 v_velocity;  // Transform feedback output

uniform float u_delta;
uniform vec3 u_gravity;

void main() {
  vec3 vel = a_velocity + u_gravity * u_delta;
  vec3 pos = a_position + vel * u_delta;

  // Output for transform feedback
  v_position = pos;
  v_velocity = vel;

  gl_Position = vec4(pos, 1.0);
}
```

### Execute Transform Feedback

```javascript
gl.enable(gl.RASTERIZER_DISCARD); // Don't render, just compute
gl.beginTransformFeedback(gl.POINTS);
gl.drawArrays(gl.POINTS, 0, particleCount);
gl.endTransformFeedback();
gl.disable(gl.RASTERIZER_DISCARD);

// Swap buffers for next frame
[inputBuffer, outputBuffer] = [outputBuffer, inputBuffer];
```

## Texture Arrays

Multiple textures in a single uniform. Useful for terrain, atlases.

### Creating Texture Arrays

```javascript
// WebGL2 only
const gl = renderer.getContext();
const texture = gl.createTexture();
gl.bindTexture(gl.TEXTURE_2D_ARRAY, texture);

// Allocate storage (width, height, layers)
gl.texStorage3D(gl.TEXTURE_2D_ARRAY, 1, gl.RGBA8, 512, 512, 4);

// Upload each layer
for (let i = 0; i < 4; i++) {
  gl.texSubImage3D(
    gl.TEXTURE_2D_ARRAY,
    0, 0, 0, i,          // level, x, y, layer
    512, 512, 1,         // width, height, depth
    gl.RGBA, gl.UNSIGNED_BYTE,
    imageData[i]
  );
}
```

### Sampling in Shader

```glsl
#version 300 es
precision highp float;
precision highp sampler2DArray;

uniform sampler2DArray u_textures;
in vec2 vUv;
flat in int vTextureIndex;

out vec4 fragColor;

void main() {
  fragColor = texture(u_textures, vec3(vUv, float(vTextureIndex)));
}
```

## Instanced Rendering

Render many copies efficiently with per-instance data.

### Three.js InstancedMesh

```javascript
const geometry = new THREE.BoxGeometry(1, 1, 1);
const material = new THREE.ShaderMaterial({
  vertexShader: `
    attribute vec3 instanceColor;
    attribute float instanceScale;

    varying vec3 vColor;

    void main() {
      vColor = instanceColor;
      vec3 pos = position * instanceScale;
      vec4 mvPosition = modelViewMatrix * instanceMatrix * vec4(pos, 1.0);
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  fragmentShader: `
    precision highp float;
    varying vec3 vColor;
    void main() {
      gl_FragColor = vec4(vColor, 1.0);
    }
  `
});

const mesh = new THREE.InstancedMesh(geometry, material, 1000);

// Set transforms
const matrix = new THREE.Matrix4();
const color = new THREE.Color();
for (let i = 0; i < 1000; i++) {
  matrix.setPosition(Math.random() * 10, Math.random() * 10, Math.random() * 10);
  mesh.setMatrixAt(i, matrix);
  mesh.setColorAt(i, color.setHSL(Math.random(), 0.8, 0.5));
}
mesh.instanceMatrix.needsUpdate = true;
mesh.instanceColor.needsUpdate = true;
```

### Custom Instance Attributes

```javascript
// Add custom per-instance data
const scales = new Float32Array(1000);
for (let i = 0; i < 1000; i++) scales[i] = 0.5 + Math.random();

geometry.setAttribute('instanceScale',
  new THREE.InstancedBufferAttribute(scales, 1)
);
```

### gl_InstanceID (WebGL2)

```glsl
#version 300 es

void main() {
  int id = gl_InstanceID;
  float t = float(id) / float(u_instanceCount);
  // Use t for per-instance variation
}
```

## Performance Considerations

| Feature | When to Use | Overhead |
|---------|-------------|----------|
| MRT | Deferred rendering, G-buffers | Medium (more bandwidth) |
| Float Textures | GPGPU, HDR, physics | Low (GPU support varies) |
| Transform Feedback | Particles, physics | Low (WebGL2 only) |
| Texture Arrays | Terrain, atlas lookup | Low |
| Instancing | Many identical objects | Very low |

**General guidance:**
- Prefer instancing over individual draw calls for >10 similar objects
- Use float textures for GPGPU when transform feedback is too complex
- MRT reduces passes but increases memory bandwidth
- Always test on target hardware (mobile has different constraints)
