# Postprocessing Pipeline

## Table of Contents
- [EffectComposer Setup](#effectcomposer-setup)
- [Common Passes](#common-passes)
- [Anti-Aliasing](#anti-aliasing)
- [Bloom](#bloom)
- [SSAO](#ssao)
- [Depth of Field](#depth-of-field)
- [Custom Passes](#custom-passes)
- [Performance Tips](#performance-tips)
- [Multiple Render Targets](#multiple-render-targets)

## EffectComposer Setup

```typescript
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';

const composer = new EffectComposer(renderer);

// First pass: render scene
const renderPass = new RenderPass(scene, camera);
composer.addPass(renderPass);

// Add more passes...

// In render loop (replace renderer.render)
composer.render();
```

### Resize Handling

```typescript
window.addEventListener('resize', () => {
  const width = window.innerWidth;
  const height = window.innerHeight;

  camera.aspect = width / height;
  camera.updateProjectionMatrix();

  renderer.setSize(width, height);
  composer.setSize(width, height);
});
```

## Common Passes

### Pass Chain Example

```typescript
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { SSAOPass } from 'three/examples/jsm/postprocessing/SSAOPass.js';
import { SMAAPass } from 'three/examples/jsm/postprocessing/SMAAPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';

const composer = new EffectComposer(renderer);

// Order matters!
composer.addPass(new RenderPass(scene, camera));
composer.addPass(new SSAOPass(scene, camera, width, height));
composer.addPass(new UnrealBloomPass(resolution, strength, radius, threshold));
composer.addPass(new SMAAPass(width, height));
composer.addPass(new OutputPass()); // Handles tone mapping and encoding
```

## Anti-Aliasing

### FXAA (Fast, Low Quality)

```typescript
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { FXAAShader } from 'three/examples/jsm/shaders/FXAAShader.js';

const fxaaPass = new ShaderPass(FXAAShader);
// Account for device pixel ratio
const pixelRatio = renderer.getPixelRatio();
fxaaPass.uniforms['resolution'].value.set(
  1 / (width * pixelRatio),
  1 / (height * pixelRatio)
);
composer.addPass(fxaaPass);
```

### SMAA (Better Quality)

```typescript
import { SMAAPass } from 'three/examples/jsm/postprocessing/SMAAPass.js';

const smaaPass = new SMAAPass(width, height);
composer.addPass(smaaPass);
```

### TAA (Temporal, Best Quality)

No built-in pass, but the concept:
1. Jitter camera subpixel each frame
2. Accumulate results with exponential moving average
3. Use motion vectors to reject stale samples

## Bloom

### UnrealBloomPass

```typescript
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';

const bloomPass = new UnrealBloomPass(
  new THREE.Vector2(width, height),
  1.5,   // strength
  0.4,   // radius
  0.85   // threshold
);
composer.addPass(bloomPass);
```

### Parameters

| Parameter | Effect |
|-----------|--------|
| strength | Intensity of glow |
| radius | Blur spread |
| threshold | Brightness cutoff (below = no bloom) |

### Selective Bloom

Only bloom emissive objects by using layers:

```typescript
// Approach 1: Use high threshold + boost emissive
material.emissiveIntensity = 5.0; // Above threshold

// Approach 2: Separate render passes
const bloomLayer = new THREE.Layers();
bloomLayer.set(1);

// Render bloom objects separately
// Apply bloom only to that render
// Composite additively
```

## SSAO

### SSAOPass

```typescript
import { SSAOPass } from 'three/examples/jsm/postprocessing/SSAOPass.js';

const ssaoPass = new SSAOPass(scene, camera, width, height);
ssaoPass.kernelRadius = 16;
ssaoPass.minDistance = 0.005;
ssaoPass.maxDistance = 0.1;
composer.addPass(ssaoPass);
```

### Performance

SSAO is expensive. Tips:
- Render at half resolution
- Reduce kernel samples
- Use N8AO (newer, faster) if available

```typescript
// Half resolution
const ssaoPass = new SSAOPass(scene, camera, width / 2, height / 2);
ssaoPass.output = SSAOPass.OUTPUT.SSAO; // Debug: view AO only
```

## Depth of Field

### BokehPass

```typescript
import { BokehPass } from 'three/examples/jsm/postprocessing/BokehPass.js';

const bokehPass = new BokehPass(scene, camera, {
  focus: 10.0,      // Focus distance
  aperture: 0.025,  // Aperture size
  maxblur: 0.01     // Maximum blur amount
});
composer.addPass(bokehPass);
```

### Dynamic Focus

```typescript
// Focus on clicked object
raycaster.setFromCamera(mouse, camera);
const intersects = raycaster.intersectObjects(scene.children);
if (intersects.length > 0) {
  bokehPass.uniforms['focus'].value = intersects[0].distance;
}
```

## Custom Passes

### ShaderPass Template

```typescript
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';

const vignetteShader = {
  uniforms: {
    tDiffuse: { value: null },
    intensity: { value: 1.0 }
  },
  vertexShader: `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    uniform sampler2D tDiffuse;
    uniform float intensity;
    varying vec2 vUv;

    void main() {
      vec4 color = texture2D(tDiffuse, vUv);
      vec2 center = vec2(0.5);
      float dist = distance(vUv, center);
      float vignette = smoothstep(0.8, 0.4, dist * intensity);
      gl_FragColor = vec4(color.rgb * vignette, color.a);
    }
  `
};

const vignettePass = new ShaderPass(vignetteShader);
composer.addPass(vignettePass);
```

### Color Grading

```typescript
const colorGradeShader = {
  uniforms: {
    tDiffuse: { value: null },
    brightness: { value: 0 },
    contrast: { value: 1 },
    saturation: { value: 1 }
  },
  fragmentShader: `
    uniform sampler2D tDiffuse;
    uniform float brightness;
    uniform float contrast;
    uniform float saturation;
    varying vec2 vUv;

    void main() {
      vec4 color = texture2D(tDiffuse, vUv);

      // Brightness
      color.rgb += brightness;

      // Contrast
      color.rgb = (color.rgb - 0.5) * contrast + 0.5;

      // Saturation
      float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
      color.rgb = mix(vec3(gray), color.rgb, saturation);

      gl_FragColor = color;
    }
  `
};
```

## Performance Tips

### Resolution Scaling

```typescript
// Render at lower resolution, upscale
const pixelRatio = Math.min(window.devicePixelRatio, 1.5);
renderer.setPixelRatio(pixelRatio);
```

### Skip Passes Conditionally

```typescript
ssaoPass.enabled = qualitySettings.ssao;
bloomPass.enabled = qualitySettings.bloom;
```

### Cheaper Alternatives

| Effect | Heavy | Lighter Alternative |
|--------|-------|---------------------|
| SSAO | SSAOPass | Baked AO textures |
| Bloom | UnrealBloom | Simple blur on emissive |
| DoF | BokehPass | Simple radial blur |
| Motion Blur | Per-pixel vectors | Directional blur |

## Multiple Render Targets

### WebGL2 MRT

Write to multiple textures in one pass:

```typescript
const mrt = new THREE.WebGLMultipleRenderTargets(width, height, 3);
mrt.texture[0].name = 'color';
mrt.texture[1].name = 'normal';
mrt.texture[2].name = 'depth';

// Custom material outputs to all targets (requires GLSL3)
const mrtMaterial = new THREE.RawShaderMaterial({
  glslVersion: THREE.GLSL3,
  vertexShader: `
    in vec3 position;
    in vec3 normal;
    uniform mat4 modelViewMatrix;
    uniform mat4 projectionMatrix;
    uniform mat3 normalMatrix;
    out vec3 vNormal;

    void main() {
      vNormal = normalMatrix * normal;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    precision highp float;
    in vec3 vNormal;
    layout(location = 0) out vec4 color;
    layout(location = 1) out vec4 normal;
    layout(location = 2) out vec4 depth;

    void main() {
      color = vec4(1.0, 0.0, 0.0, 1.0);
      normal = vec4(normalize(vNormal) * 0.5 + 0.5, 1.0);
      depth = vec4(vec3(gl_FragCoord.z), 1.0);
    }
  `
});
```

### Deferred Shading Pattern

1. G-Buffer pass: Output albedo, normal, depth, material properties
2. Lighting pass: Read G-Buffer, calculate lighting per pixel
3. Composite: Combine with forward-rendered transparent objects

Benefits: Many lights at constant cost (per light is a fullscreen quad).

```typescript
// Simplified deferred setup
const gBuffer = new THREE.WebGLMultipleRenderTargets(width, height, 4);

// G-Buffer pass
renderer.setRenderTarget(gBuffer);
scene.overrideMaterial = gBufferMaterial;
renderer.render(scene, camera);

// Lighting pass
renderer.setRenderTarget(null);
lightingQuad.material.uniforms.albedo.value = gBuffer.texture[0];
lightingQuad.material.uniforms.normal.value = gBuffer.texture[1];
// etc.
renderer.render(lightingScene, orthoCamera);
```
