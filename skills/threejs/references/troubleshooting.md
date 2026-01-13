# Troubleshooting Guide

## Table of Contents
- [Visual Issues](#visual-issues)
- [Performance Issues](#performance-issues)
- [Loading Issues](#loading-issues)
- [Memory Issues](#memory-issues)
- [Physics Issues](#physics-issues)
- [WebGL Context Issues](#webgl-context-issues)
- [Debugging Tools](#debugging-tools)
- [Upgrade Migration Checklist](#upgrade-migration-checklist)

## Visual Issues

### Scene is All Black

**Causes and fixes:**

1. **No lights**
   ```typescript
   scene.add(new THREE.AmbientLight(0xffffff, 0.5));
   scene.add(new THREE.DirectionalLight(0xffffff, 1));
   ```

2. **Metalness without environment map**
   ```typescript
   // Metals reflect environment—need envMap
   material.metalness = 1.0;
   scene.environment = pmremTexture; // Required!
   ```

3. **Camera inside object or wrong position**
   ```typescript
   camera.position.set(0, 5, 10);
   camera.lookAt(0, 0, 0);
   ```

4. **Wrong output color space**
   ```typescript
   renderer.outputColorSpace = THREE.SRGBColorSpace;
   ```

### Objects Appear Too Dark

**Fixes:**

1. **Increase tone mapping exposure**
   ```typescript
   renderer.toneMappingExposure = 1.5;
   ```

2. **Check light intensities** (with physical lights, values are different)
   ```typescript
   directionalLight.intensity = 3; // Not 1
   ```

3. **Verify texture color space**
   ```typescript
   colorTexture.colorSpace = THREE.SRGBColorSpace;
   ```

### Z-Fighting / Flickering

**Cause:** Two surfaces at nearly the same depth.

**Fixes:**

1. **Adjust near/far planes**
   ```typescript
   camera.near = 0.1;  // Not 0.001
   camera.far = 1000;  // Not 100000
   ```

2. **Use logarithmic depth buffer** (for huge scenes)
   ```typescript
   const renderer = new THREE.WebGLRenderer({ logarithmicDepthBuffer: true });
   ```

3. **Offset one surface slightly**
   ```typescript
   material.polygonOffset = true;
   material.polygonOffsetFactor = 1;
   material.polygonOffsetUnits = 1;
   ```

### Shadow Acne (Striped Shadows)

**Fix:** Adjust shadow bias

```typescript
light.shadow.bias = -0.0005;
light.shadow.normalBias = 0.02;
```

### Colors Look Washed Out or Wrong

**Causes:**

1. **Missing sRGB color space on color textures**
   ```typescript
   texture.colorSpace = THREE.SRGBColorSpace;
   ```

2. **Double gamma correction**
   - Don't manually gamma correct if renderer handles it

3. **ACES tone mapping color shift**
   ```typescript
   renderer.toneMapping = THREE.ReinhardToneMapping; // Less color shift
   ```

### Banding in Gradients

**Fix:** Enable dithering

```typescript
material.dithering = true;
```

## Performance Issues

### Low FPS Despite Simple Scene

**Check:**

1. **Device pixel ratio**
   ```typescript
   renderer.setPixelRatio(Math.min(2, window.devicePixelRatio));
   ```

2. **Shadow map resolution**
   ```typescript
   light.shadow.mapSize.width = 1024;  // Not 4096
   light.shadow.mapSize.height = 1024;
   ```

3. **Postprocessing chain**
   - Disable passes one by one to find culprit

### High Draw Call Count

**Diagnostic:**
```typescript
console.log(renderer.info.render.calls);
```

**Fixes:**
- Merge static meshes
- Use InstancedMesh for repeated geometry
- Reduce material count (atlas textures)

### Stuttering / Jank

**Causes:**

1. **Garbage collection**
   - Avoid `new` in render loop
   - Reuse objects: `vector.set()` not `new Vector3()`

2. **Asset loading on main thread**
   - Use `LoadingManager` with progress
   - Load critical assets before gameplay

3. **Heavy computation in render loop**
   - Move to Web Worker
   - Spread over multiple frames

## Loading Issues

### Model Doesn't Appear

**Check:**

1. **Scale** (might be too small or huge)
   ```typescript
   gltf.scene.scale.setScalar(0.01); // or 100
   ```

2. **Position** (might be off-camera)
   ```typescript
   const box = new THREE.Box3().setFromObject(gltf.scene);
   console.log('Model bounds:', box);
   ```

3. **Check for errors in console**

### Textures Missing

**Verify:**

1. **Paths are correct** (relative to HTML or absolute)
2. **Server serves files** (CORS issues?)
3. **File exists** (404?)

```typescript
loader.load(url, onLoad, onProgress, (error) => {
  console.error('Load error:', error);
});
```

### Animations Not Playing

**Check:**

1. **AnimationMixer created correctly**
   ```typescript
   const mixer = new THREE.AnimationMixer(gltf.scene);
   ```

2. **Clip action started**
   ```typescript
   const action = mixer.clipAction(gltf.animations[0]);
   action.play();
   ```

3. **Mixer updated in loop**
   ```typescript
   mixer.update(delta); // Must call every frame!
   ```

4. **Material has morphTargets enabled** (for shape keys)
   ```typescript
   material.morphTargets = true;
   ```

## Memory Issues

### Memory Keeps Growing

**Cause:** Not disposing resources.

**Fix:**
```typescript
function dispose(object: THREE.Object3D) {
  object.traverse(child => {
    if (child instanceof THREE.Mesh) {
      child.geometry.dispose();

      if (Array.isArray(child.material)) {
        child.material.forEach(mat => disposeMaterial(mat));
      } else {
        disposeMaterial(child.material);
      }
    }
  });
}

function disposeMaterial(material: THREE.Material) {
  Object.values(material).forEach(value => {
    if (value instanceof THREE.Texture) {
      value.dispose();
    }
  });
  material.dispose();
}
```

### Monitor Memory

```typescript
setInterval(() => {
  const info = renderer.info;
  console.log({
    geometries: info.memory.geometries,
    textures: info.memory.textures
  });
}, 5000);
```

## Physics Issues

### Objects Fall Through Floor

**Causes:**

1. **Tunneling** (moving too fast)
   - Use continuous collision detection
   - Reduce timestep

2. **Collision shapes don't match**
   - Verify shape dimensions match visual mesh

3. **Scale mismatch**
   - Physics engines prefer objects 0.1-10 units
   - Scale your scene appropriately

### Jittery Physics

**Fixes:**

1. **Use fixed timestep**
   ```typescript
   while (accumulator >= FIXED_DT) {
     world.step();
     accumulator -= FIXED_DT;
   }
   ```

2. **Interpolate transforms** for rendering

3. **Enable sleeping** for settled objects

### Objects Explode on Contact

**Cause:** Overlapping bodies at spawn.

**Fix:**
- Spawn bodies with clearance
- Use collision queries before spawning

## WebGL Context Issues

### "WebGL context lost"

**Cause:** GPU overload or driver issues.

**Handling:**
```typescript
canvas.addEventListener('webglcontextlost', (e) => {
  e.preventDefault();
  // Pause rendering
  isContextLost = true;
});

canvas.addEventListener('webglcontextrestored', () => {
  // Re-initialize everything
  initRenderer();
  initScene();
  isContextLost = false;
});
```

### "Too many WebGL contexts"

**Cause:** Creating multiple renderers without disposing.

**Fix:**
```typescript
renderer.dispose();
renderer.forceContextLoss();
```

## Debugging Tools

### Essential Setup

```typescript
// Stats panel
import Stats from 'stats.js';
const stats = new Stats();
document.body.appendChild(stats.dom);

// GUI controls
import { GUI } from 'lil-gui';
const gui = new GUI();
gui.add(renderer, 'toneMappingExposure', 0, 3);

// Helpers
scene.add(new THREE.AxesHelper(5));
scene.add(new THREE.GridHelper(10, 10));
```

### Visualize Bounding Boxes

```typescript
const helper = new THREE.BoxHelper(mesh, 0xff0000);
scene.add(helper);
```

### Visualize Normals

```typescript
import { VertexNormalsHelper } from 'three/examples/jsm/helpers/VertexNormalsHelper.js';
const normalsHelper = new VertexNormalsHelper(mesh, 0.1);
scene.add(normalsHelper);
```

### Visualize Shadow Camera

```typescript
const shadowHelper = new THREE.CameraHelper(light.shadow.camera);
scene.add(shadowHelper);
```

### Spector.js

Capture and inspect WebGL frames:
- Install browser extension
- Click capture
- Analyze draw calls, shaders, state

### Log Renderer Info

```typescript
function logRendererInfo() {
  const info = renderer.info;
  console.table({
    'Draw Calls': info.render.calls,
    'Triangles': info.render.triangles,
    'Points': info.render.points,
    'Lines': info.render.lines,
    'Geometries': info.memory.geometries,
    'Textures': info.memory.textures
  });
}
```

### Common Debug Snippets

```typescript
// Find object by name
const obj = scene.getObjectByName('MyObject');

// List all materials
scene.traverse(o => {
  if (o.isMesh) console.log(o.name, o.material);
});

// Override all materials (test GPU vs CPU bound)
scene.overrideMaterial = new THREE.MeshBasicMaterial({ color: 'red' });

// Wireframe mode
scene.traverse(o => {
  if (o.isMesh) o.material.wireframe = true;
});
```

## Upgrade Migration Checklist

### Three.js Version Upgrades

When upgrading Three.js versions, check for these common breaking changes:

#### r150+ Color Management

```typescript
// OLD (deprecated)
renderer.outputEncoding = THREE.sRGBEncoding;
texture.encoding = THREE.sRGBEncoding;

// NEW (r150+)
renderer.outputColorSpace = THREE.SRGBColorSpace;
texture.colorSpace = THREE.SRGBColorSpace;
```

#### r155+ Physical Lights

```typescript
// OLD (deprecated)
renderer.physicallyCorrectLights = true;

// NEW (r155+)
renderer.useLegacyLights = false; // Physical lights are now default
```

#### r152+ Lightmap UV Channel

```typescript
// OLD (automatic UV2 for lightmaps)
material.lightMap = lightmapTexture;

// NEW (r152+): Explicit channel assignment
lightmapTexture.channel = 1;
material.lightMap = lightmapTexture;
```

### Pre-Upgrade Checklist

Before upgrading Three.js:

1. **Check changelog**
   - [Three.js releases](https://github.com/mrdoob/three.js/releases)
   - Search for "BREAKING" in release notes

2. **Audit deprecated API usage**
   ```bash
   # Search for common deprecated patterns
   grep -r "outputEncoding\|sRGBEncoding\|physicallyCorrectLights" src/
   ```

3. **Lock example imports version**
   ```typescript
   // Match examples to core version
   import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
   // NOT from a different version
   ```

4. **Test critical paths**
   - Model loading (glTF, FBX)
   - Material appearance (PBR, lighting)
   - Postprocessing (EffectComposer)
   - Physics sync (if using external engine)

### Post-Upgrade Verification

After upgrading:

1. ☐ Colors look correct (not washed out or too dark)
2. ☐ Lighting intensity unchanged
3. ☐ Shadows render properly
4. ☐ Postprocessing effects work
5. ☐ Models load without errors
6. ☐ Animations play correctly
7. ☐ No console warnings about deprecated APIs
8. ☐ Performance similar to before

### Common Upgrade Fixes

#### "X is not a constructor" Error

```typescript
// Example imports changed location
// OLD
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer';
// NEW (with .js extension for ES modules)
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
```

#### Materials Look Different

```typescript
// Check tone mapping (defaults may have changed)
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;

// Verify color space on all textures
colorTexture.colorSpace = THREE.SRGBColorSpace;
normalTexture.colorSpace = THREE.LinearSRGBColorSpace; // NOT sRGB
```

#### Lights Too Bright/Dim

```typescript
// Physical light units changed in r155
// Convert legacy intensity to physical
// DirectionalLight: lux (lm/m²)
// PointLight: candela (cd)

// Old intensity 1.0 ≈ New intensity ~3.0 for indoor scenes
directionalLight.intensity = 3;
```

### Version Compatibility Matrix

| Feature | Min Version | Notes |
|---------|-------------|-------|
| `outputColorSpace` | r150 | Replaces `outputEncoding` |
| `useLegacyLights` | r155 | Physical lights default |
| `texture.channel` | r152 | For UV2 lightmaps |
| WebGPU renderer | r157 | Experimental |
| `MeshBVH` (built-in) | N/A | Use three-mesh-bvh library |

### Dependency Compatibility

When upgrading Three.js, also check:

- **postprocessing** library version
- **three-mesh-bvh** version
- **@react-three/fiber** (if using React)
- **drei** helpers
- Physics engines (rapier3d, cannon-es)
