# Three.js Shader Integration

## Table of Contents
- [ShaderMaterial vs RawShaderMaterial](#shadermaterial-vs-rawshadermaterial)
- [Built-in Uniforms and Attributes](#built-in-uniforms-and-attributes)
- [onBeforeCompile Hook](#onbeforecompile-hook)
- [ShaderChunks System](#shaderchunks-system)
- [Custom Attributes](#custom-attributes)
- [Instanced Rendering](#instanced-rendering)

## ShaderMaterial vs RawShaderMaterial

### ShaderMaterial

Three.js auto-injects common uniforms/attributes:

```javascript
const material = new THREE.ShaderMaterial({
  vertexShader: `
    // These are auto-injected, don't declare:
    // uniform mat4 projectionMatrix, modelViewMatrix, modelMatrix, viewMatrix;
    // uniform mat3 normalMatrix;
    // uniform vec3 cameraPosition;
    // attribute vec3 position, normal;
    // attribute vec2 uv;

    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    precision highp float;
    varying vec2 vUv;
    void main() {
      gl_FragColor = vec4(vUv, 0.0, 1.0);
    }
  `,
  uniforms: {
    // Your custom uniforms only
  }
});
```

### RawShaderMaterial

Full control, nothing auto-injected:

```javascript
const material = new THREE.RawShaderMaterial({
  vertexShader: `
    precision highp float;

    // Must declare everything
    uniform mat4 projectionMatrix;
    uniform mat4 modelViewMatrix;

    attribute vec3 position;
    attribute vec2 uv;

    varying vec2 vUv;

    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    precision highp float;
    varying vec2 vUv;
    void main() {
      gl_FragColor = vec4(vUv, 0.0, 1.0);
    }
  `
});
```

**When to use RawShaderMaterial:**
- Post-processing shaders on fullscreen quads
- WebGL2 with `#version 300 es`
- Maximum control over every line

## Built-in Uniforms and Attributes

### Transformation Matrices (ShaderMaterial)

```glsl
uniform mat4 modelMatrix;      // Local → World
uniform mat4 viewMatrix;       // World → Camera
uniform mat4 projectionMatrix; // Camera → Clip (NDC)
uniform mat4 modelViewMatrix;  // Local → Camera (viewMatrix * modelMatrix)
uniform mat3 normalMatrix;     // For transforming normals to view-space

// Common transforms
vec4 worldPos = modelMatrix * vec4(position, 1.0);
vec4 viewPos = modelViewMatrix * vec4(position, 1.0);
gl_Position = projectionMatrix * viewPos;

// Normal transform (normalMatrix gives VIEW-space normals, not world-space)
vec3 viewNormal = normalize(normalMatrix * normal);
// For world-space normals, use: vec3 worldNormal = normalize((modelMatrix * vec4(normal, 0.0)).xyz);
```

### Camera Uniforms

```glsl
uniform vec3 cameraPosition;  // World-space camera position

// Calculate view direction in fragment
vec3 viewDir = normalize(cameraPosition - vWorldPosition);
```

### Standard Attributes

```glsl
attribute vec3 position;  // Vertex position
attribute vec3 normal;    // Vertex normal
attribute vec2 uv;        // Primary UV coordinates
attribute vec2 uv2;       // Secondary UVs (if present)
attribute vec3 color;     // Vertex colors (if vertexColors: true)
```

## onBeforeCompile Hook

Modify built-in materials while keeping their features:

### Basic Pattern

```javascript
const material = new THREE.MeshStandardMaterial({
  map: texture,
  roughness: 0.5
});

material.onBeforeCompile = (shader) => {
  // Add custom uniforms
  shader.uniforms.u_time = { value: 0 };
  shader.uniforms.u_intensity = { value: 1.0 };

  // Store reference for updates
  material.userData.shader = shader;

  // Modify vertex shader
  shader.vertexShader = shader.vertexShader.replace(
    '#include <common>',
    `#include <common>
     uniform float u_time;
     varying vec3 vWorldPos;`
  );

  shader.vertexShader = shader.vertexShader.replace(
    '#include <begin_vertex>',
    `#include <begin_vertex>
     transformed.y += sin(position.x * 2.0 + u_time) * 0.1;`
  );

  // Modify fragment shader
  shader.fragmentShader = shader.fragmentShader.replace(
    '#include <common>',
    `#include <common>
     uniform float u_intensity;`
  );

  shader.fragmentShader = shader.fragmentShader.replace(
    '#include <dithering_fragment>',
    `#include <dithering_fragment>
     gl_FragColor.rgb *= u_intensity;`
  );
};

// Update in animation loop
function animate() {
  if (material.userData.shader) {
    material.userData.shader.uniforms.u_time.value = clock.getElapsedTime();
  }
}
```

### Common Hook Points

**Vertex shader:**
- `#include <common>` - Add uniforms/varyings
- `#include <begin_vertex>` - Modify vertex position (`transformed`)
- `#include <beginnormal_vertex>` - Modify normals

**Fragment shader:**
- `#include <common>` - Add uniforms
- `#include <map_fragment>` - After diffuse map applied
- `#include <normal_fragment_maps>` - After normal mapping
- `#include <dithering_fragment>` - Final output (near end)

### Debug: View Compiled Shader

```javascript
material.onBeforeCompile = (shader) => {
  console.log('VERTEX:\n', shader.vertexShader);
  console.log('FRAGMENT:\n', shader.fragmentShader);
};
```

## ShaderChunks System

Three.js exposes reusable shader code:

```javascript
// Access chunks
console.log(THREE.ShaderChunk.common);
console.log(THREE.ShaderChunk.fog_pars_fragment);
```

### Useful Chunks

```glsl
#include <common>           // PI, saturate, linearToGamma, etc.
#include <packing>          // packNormalToRGB, unpackRGBAToDepth, etc.
#include <fog_pars_fragment> // Fog uniform declarations
#include <fog_fragment>      // Apply fog to gl_FragColor
#include <lights_pars_begin> // Light uniforms (requires lights: true)
```

### Using Fog in Custom Shader

```javascript
const material = new THREE.ShaderMaterial({
  fog: true,  // Enable fog integration
  vertexShader: `
    #include <fog_pars_vertex>
    varying vec2 vUv;
    void main() {
      vUv = uv;
      #include <begin_vertex>
      #include <project_vertex>
      #include <fog_vertex>
    }
  `,
  fragmentShader: `
    precision highp float;
    #include <fog_pars_fragment>
    varying vec2 vUv;
    void main() {
      gl_FragColor = vec4(vUv, 0.0, 1.0);
      #include <fog_fragment>
    }
  `
});
```

## Custom Attributes

### Adding Per-Vertex Data

```javascript
const geometry = new THREE.BufferGeometry();
// ... set position, normal, uv attributes

// Add custom attribute
const customData = new Float32Array(vertexCount);
// ... fill customData
geometry.setAttribute('aCustom', new THREE.BufferAttribute(customData, 1));

// In shader
const material = new THREE.ShaderMaterial({
  vertexShader: `
    attribute float aCustom;
    varying float vCustom;
    void main() {
      vCustom = aCustom;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    varying float vCustom;
    void main() {
      gl_FragColor = vec4(vec3(vCustom), 1.0);
    }
  `
});
```

## Instanced Rendering

### InstancedMesh with Custom Data

```javascript
const geometry = new THREE.BoxGeometry();
const material = new THREE.ShaderMaterial({
  vertexShader: `
    // Built-in for InstancedMesh
    // attribute mat4 instanceMatrix;

    attribute vec3 instanceColor;  // Custom per-instance
    varying vec3 vColor;

    void main() {
      vColor = instanceColor;
      vec4 mvPosition = modelViewMatrix * instanceMatrix * vec4(position, 1.0);
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  fragmentShader: `
    varying vec3 vColor;
    void main() {
      gl_FragColor = vec4(vColor, 1.0);
    }
  `
});

const mesh = new THREE.InstancedMesh(geometry, material, count);

// Set transforms
const matrix = new THREE.Matrix4();
for (let i = 0; i < count; i++) {
  matrix.setPosition(x, y, z);
  mesh.setMatrixAt(i, matrix);
}
mesh.instanceMatrix.needsUpdate = true;

// Add custom instance attribute
const colors = new Float32Array(count * 3);
// ... fill colors
geometry.setAttribute('instanceColor',
  new THREE.InstancedBufferAttribute(colors, 3)
);
```

### WebGL2: gl_InstanceID

```glsl
#version 300 es
// Available in vertex shader
int id = gl_InstanceID;
```

## Material Properties

### Common Options

```javascript
new THREE.ShaderMaterial({
  uniforms: { ... },
  vertexShader: '...',
  fragmentShader: '...',

  // Rendering
  transparent: true,        // Enable alpha blending
  side: THREE.DoubleSide,   // Render both sides
  depthTest: true,          // Default
  depthWrite: true,         // Set false for transparent
  blending: THREE.NormalBlending,

  // Features
  fog: true,                // Integrate with scene fog
  lights: true,             // Receive lights (need light chunks)
  wireframe: false,

  // Extensions
  extensions: {
    derivatives: true,      // Enable dFdx/dFdy in WebGL1
    fragDepth: false,       // Write to gl_FragDepth
    drawBuffers: false,     // Multiple render targets
    shaderTextureLOD: false // textureLod in fragment
  }
});
```

## Color Management

Three.js r152+ uses linear color space by default. Custom shaders must handle this.

```javascript
// Renderer setup
renderer.outputColorSpace = THREE.SRGBColorSpace; // Default

// In custom shaders, colors from textures are in sRGB
// Convert to linear for lighting calculations, back to sRGB for output
```

**In fragment shader:**
```glsl
// sRGB to Linear (for input textures)
vec3 toLinear(vec3 srgb) {
  return pow(srgb, vec3(2.2));
}

// Linear to sRGB (for output)
vec3 toSRGB(vec3 linear) {
  return pow(linear, vec3(1.0 / 2.2));
}

// Or use Three.js built-in chunks:
// #include <colorspace_fragment>  // Converts gl_FragColor to output color space
// #include <tonemapping_fragment> // Applies tone mapping
```

## WebGL2 GLSL Version

For WebGL2 features in ShaderMaterial:

```javascript
const material = new THREE.ShaderMaterial({
  glslVersion: THREE.GLSL3, // Enable GLSL ES 3.00
  vertexShader: `#version 300 es
    in vec3 position;
    // ...
  `,
  fragmentShader: `#version 300 es
    precision highp float;
    out vec4 fragColor;
    // ...
  `
});
```

## Depth Texture Setup

Required for soft particles, SSAO, and depth-based effects:

```javascript
const renderTarget = new THREE.WebGLRenderTarget(width, height, {
  depthBuffer: true,
  depthTexture: new THREE.DepthTexture(width, height)
});
renderTarget.depthTexture.format = THREE.DepthFormat;
renderTarget.depthTexture.type = THREE.UnsignedIntType;

// Use in shader
material.uniforms.u_depthTexture = { value: renderTarget.depthTexture };
material.uniforms.u_cameraNear = { value: camera.near };
material.uniforms.u_cameraFar = { value: camera.far };
```

**WebGL1 note:** Requires `WEBGL_depth_texture` extension (widely supported).
