# Performance Optimization

## Table of Contents
- [Profiling Workflow](#profiling-workflow)
- [CPU vs GPU Bottleneck](#cpu-vs-gpu-bottleneck)
- [Draw Call Optimization](#draw-call-optimization)
- [Geometry Optimization](#geometry-optimization)
- [Material Optimization](#material-optimization)
- [Texture Optimization](#texture-optimization)
- [Shadow Optimization](#shadow-optimization)
- [Animation Optimization](#animation-optimization)
- [Memory Management](#memory-management)
- [CPU-GPU Synchronization](#cpu-gpu-synchronization)
- [Device-Tier Adaptation](#device-tier-adaptation)
- [Performance Checklist](#performance-checklist)

## Profiling Workflow

### Essential Tools

| Tool | Purpose |
|------|---------|
| `renderer.info` | Draw calls, triangles, memory |
| Stats.js | FPS/MS monitoring |
| Spector.js | WebGL frame debugger |
| Chrome DevTools Performance | CPU profiling, GC detection |
| Chrome Memory tab | Heap snapshots for leaks |

### Quick Stats Setup

```typescript
import Stats from 'stats.js';

const stats = new Stats();
stats.showPanel(0); // 0: fps, 1: ms, 2: mb
document.body.appendChild(stats.dom);

function animate() {
  stats.begin();
  // ... render ...
  stats.end();
  requestAnimationFrame(animate);
}
```

### Monitor renderer.info

```typescript
// Log periodically
setInterval(() => {
  const info = renderer.info;
  console.log({
    drawCalls: info.render.calls,
    triangles: info.render.triangles,
    geometries: info.memory.geometries,
    textures: info.memory.textures
  });
}, 5000);
```

## CPU vs GPU Bottleneck

### Diagnostic Test

Replace all materials with basic to isolate GPU cost:

```typescript
function testGPUBound() {
  const originalMats = new Map();
  const basic = new THREE.MeshBasicMaterial({ color: 0xff0000 });

  scene.traverse(obj => {
    if (obj.isMesh) {
      originalMats.set(obj, obj.material);
      obj.material = basic;
    }
  });

  // Measure FPS for 5 seconds
  // If FPS improves significantly → GPU-bound
  // If little change → CPU-bound

  // Restore
  scene.traverse(obj => {
    if (originalMats.has(obj)) {
      obj.material = originalMats.get(obj);
    }
  });
}
```

### Indicators

| Symptom | Likely Cause |
|---------|--------------|
| FPS improves with smaller window | Fill-rate limited (GPU) |
| FPS improves with basic materials | Fragment shader heavy (GPU) |
| High CPU in DevTools flame chart | JavaScript bottleneck (CPU) |
| Frequent GC events (purple bars) | Allocation issues (CPU) |

## Draw Call Optimization

### Target: Keep draw calls under 200

### Strategies

**1. Merge Static Geometry**

```typescript
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

const geometries = meshes.map(m => {
  const geo = m.geometry.clone();
  geo.applyMatrix4(m.matrixWorld);
  return geo;
});

const merged = mergeGeometries(geometries);
const mergedMesh = new THREE.Mesh(merged, sharedMaterial);
```

**2. Instancing for Repeated Objects**

```typescript
const instancedMesh = new THREE.InstancedMesh(geo, mat, 1000);
const matrix = new THREE.Matrix4();

for (let i = 0; i < 1000; i++) {
  matrix.setPosition(positions[i]);
  instancedMesh.setMatrixAt(i, matrix);
}
instancedMesh.instanceMatrix.needsUpdate = true;
```

**3. Texture Atlasing**

Combine multiple small textures into one atlas, adjust UVs per sprite.

## Geometry Optimization

### Level of Detail (LOD)

```typescript
const lod = new THREE.LOD();
lod.addLevel(highPolyMesh, 0);    // Distance 0
lod.addLevel(medPolyMesh, 50);   // Distance 50
lod.addLevel(lowPolyMesh, 100);  // Distance 100
scene.add(lod);
```

### Impostors for Distant Objects

Replace far meshes with billboards (sprites or camera-facing planes).

### Dynamic Geometry Updates

```typescript
// DON'T create new geometry every frame
// DO update existing attributes
geometry.attributes.position.array[idx] = newValue;
geometry.attributes.position.needsUpdate = true;

// Optionally hint which range changed
geometry.attributes.position.updateRange.offset = start;
geometry.attributes.position.updateRange.count = length;
```

## Material Optimization

### Complexity Hierarchy

| Material | Cost | Use For |
|----------|------|---------|
| MeshBasicMaterial | Lowest | Unlit, UI, distant |
| MeshLambertMaterial | Low | Matte surfaces |
| MeshPhongMaterial | Medium | Shiny surfaces |
| MeshStandardMaterial | High | PBR, main objects |
| MeshPhysicalMaterial | Highest | Clearcoat, transmission |

### Share Materials

```typescript
// Single instance for many meshes
const sharedMaterial = new THREE.MeshStandardMaterial({ color: 0xff0000 });
meshes.forEach(m => m.material = sharedMaterial);
```

### Avoid Expensive Features When Not Needed

- Skip normal maps on distant/small objects
- Use `flatShading: true` for low-poly aesthetic
- Disable `shadowSide` unless needed

## Texture Optimization

### Memory Formula

```
GPU Memory = width × height × 4 bytes × (mipmap ? 1.33 : 1)
```

4K RGBA = 4096 × 4096 × 4 × 1.33 ≈ **89 MB**

### Best Practices

1. **Use KTX2/Basis** - Stays compressed on GPU
2. **Power of two dimensions** - Required for mipmaps
3. **Match resolution to screen usage** - 4K for ground, 512 for small props
4. **Enable mipmaps** - Better quality + cache performance
5. **Limit anisotropy** - `texture.anisotropy = Math.min(4, maxAniso)`

### KTX2 vs Uncompressed

| Format | File Size | GPU Memory | Upload Time |
|--------|-----------|------------|-------------|
| 4K PNG | 8 MB | 89 MB | 200+ ms |
| 4K KTX2 | 3 MB | 22 MB | ~20 ms |

## Shadow Optimization

### Resolution

```typescript
light.shadow.mapSize.width = 1024;  // Start low
light.shadow.mapSize.height = 1024;
// Only increase if shadows look blocky
```

### Tight Frustum

```typescript
const d = 50; // Fit to scene
light.shadow.camera.left = -d;
light.shadow.camera.right = d;
light.shadow.camera.top = d;
light.shadow.camera.bottom = -d;
light.shadow.camera.near = 0.5;
light.shadow.camera.far = 500;
```

### Selective Casting

```typescript
// Only important objects cast shadows
heroMesh.castShadow = true;
smallProps.castShadow = false;

// Point lights cost 6× (cube map)
// Prefer directional/spot for shadows
```

### Static Shadow Caching

```typescript
// For static scenes
light.shadow.autoUpdate = false;

// Manually update when needed
renderer.shadowMap.needsUpdate = true;
```

## Animation Optimization

### Bone Count

- Keep under 64 bones for best performance
- Separate rigid parts (helmet, weapon) from skinned mesh

### Shared Skeletons

Multiple meshes can share one skeleton to save updates.

### AnimationMixer Pooling

```typescript
// Reuse mixers rather than creating per character
const mixerPool: THREE.AnimationMixer[] = [];
```

## Memory Management

### Disposal Pattern

```typescript
function disposeMesh(mesh: THREE.Mesh) {
  mesh.geometry.dispose();

  if (Array.isArray(mesh.material)) {
    mesh.material.forEach(mat => disposeMaterial(mat));
  } else {
    disposeMaterial(mesh.material);
  }
}

function disposeMaterial(material: THREE.Material) {
  for (const key of Object.keys(material)) {
    const value = material[key];
    if (value?.isTexture) {
      value.dispose();
    }
  }
  material.dispose();
}
```

### Object Pooling

```typescript
class ObjectPool<T extends THREE.Object3D> {
  private pool: T[] = [];

  acquire(): T | null {
    const obj = this.pool.pop();
    if (obj) obj.visible = true;
    return obj ?? null;
  }

  release(obj: T) {
    obj.visible = false;
    this.pool.push(obj);
  }
}
```

### Avoid Per-Frame Allocations

```typescript
// BAD
function update() {
  const dir = new THREE.Vector3(); // Allocation!
}

// GOOD
const _dir = new THREE.Vector3();
function update() {
  _dir.set(0, 0, 0); // Reuse
}
```

## CPU-GPU Synchronization

### Avoid Blocking Reads

GPU reads stall the pipeline:

```typescript
// BAD: Blocks until GPU finishes
renderer.readRenderTargetPixels(rt, 0, 0, w, h, buffer);

// BETTER: Use async readback (WebGL2)
const pbo = gl.createBuffer();
gl.bindBuffer(gl.PIXEL_PACK_BUFFER, pbo);
gl.bufferData(gl.PIXEL_PACK_BUFFER, buffer.byteLength, gl.STREAM_READ);
gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, 0);

// Fence sync to know when data is ready
const sync = gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
gl.clientWaitSync(sync, 0, 0); // Poll in rAF, don't block
```

### Overdraw Control

Overdraw = pixels drawn multiple times per frame.

**Detection:**
```typescript
// Override all materials with flat color, alpha = 0.1
// Bright areas = high overdraw
scene.traverse(obj => {
  if (obj.isMesh) {
    obj.material = new THREE.MeshBasicMaterial({
      color: 0xff0000,
      transparent: true,
      opacity: 0.1,
      depthWrite: false
    });
  }
});
```

**Reduction strategies:**
- Sort opaque objects front-to-back (Three.js does this)
- Use depth pre-pass for complex scenes
- Avoid unnecessary transparent objects
- Keep alpha-tested geometry minimal

### Texture Upload Timing

Large texture uploads cause frame spikes:

```typescript
// Spread uploads across frames
const textures = [tex1, tex2, tex3, tex4];
let uploadIndex = 0;

function uploadNextTexture() {
  if (uploadIndex < textures.length) {
    renderer.initTexture(textures[uploadIndex]);
    uploadIndex++;
    requestAnimationFrame(uploadNextTexture);
  }
}
```

## Device-Tier Adaptation

### Detect GPU Capability

```typescript
function getDeviceTier(): 'low' | 'medium' | 'high' {
  const gl = renderer.getContext();
  const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');

  if (debugInfo) {
    const gpu = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL).toLowerCase();

    // Mobile/integrated GPUs
    if (gpu.includes('mali') || gpu.includes('adreno') ||
        gpu.includes('intel') || gpu.includes('apple gpu')) {
      return 'low';
    }
    // Mid-range
    if (gpu.includes('gtx 1') || gpu.includes('rtx 2') ||
        gpu.includes('radeon rx 5')) {
      return 'medium';
    }
  }

  // Check max texture size as fallback
  const maxTex = gl.getParameter(gl.MAX_TEXTURE_SIZE);
  if (maxTex < 4096) return 'low';
  if (maxTex < 16384) return 'medium';
  return 'high';
}
```

### Apply Quality Settings

```typescript
interface QualitySettings {
  pixelRatio: number;
  shadowMapSize: number;
  shadowsEnabled: boolean;
  ssao: boolean;
  bloom: boolean;
  textureQuality: 'low' | 'medium' | 'high';
}

const QUALITY_PRESETS: Record<string, QualitySettings> = {
  low: {
    pixelRatio: 1,
    shadowMapSize: 512,
    shadowsEnabled: false,
    ssao: false,
    bloom: false,
    textureQuality: 'low'
  },
  medium: {
    pixelRatio: Math.min(1.5, devicePixelRatio),
    shadowMapSize: 1024,
    shadowsEnabled: true,
    ssao: false,
    bloom: true,
    textureQuality: 'medium'
  },
  high: {
    pixelRatio: Math.min(2, devicePixelRatio),
    shadowMapSize: 2048,
    shadowsEnabled: true,
    ssao: true,
    bloom: true,
    textureQuality: 'high'
  }
};

function applyQuality(settings: QualitySettings) {
  renderer.setPixelRatio(settings.pixelRatio);
  renderer.shadowMap.enabled = settings.shadowsEnabled;

  lights.forEach(light => {
    if (light.shadow) {
      light.shadow.mapSize.setScalar(settings.shadowMapSize);
    }
  });

  if (composer) {
    ssaoPass.enabled = settings.ssao;
    bloomPass.enabled = settings.bloom;
  }
}
```

### Power Preference

```typescript
// Request high-performance GPU on laptops with dual GPUs
const renderer = new THREE.WebGLRenderer({
  canvas,
  powerPreference: 'high-performance' // or 'low-power' for battery
});
```

### Adaptive Quality

```typescript
class AdaptiveQuality {
  private fpsHistory: number[] = [];
  private currentTier: 'low' | 'medium' | 'high' = 'high';

  update(fps: number) {
    this.fpsHistory.push(fps);
    if (this.fpsHistory.length > 60) this.fpsHistory.shift();

    const avgFps = this.fpsHistory.reduce((a, b) => a + b) / this.fpsHistory.length;

    // Downgrade if struggling
    if (avgFps < 30 && this.currentTier !== 'low') {
      this.currentTier = this.currentTier === 'high' ? 'medium' : 'low';
      applyQuality(QUALITY_PRESETS[this.currentTier]);
      this.fpsHistory = [];
    }

    // Upgrade if headroom exists
    if (avgFps > 55 && this.currentTier !== 'high') {
      this.currentTier = this.currentTier === 'low' ? 'medium' : 'high';
      applyQuality(QUALITY_PRESETS[this.currentTier]);
      this.fpsHistory = [];
    }
  }
}
```

## Performance Checklist

1. ☐ Draw calls < 200
2. ☐ Device pixel ratio capped at 2
3. ☐ Shadows only on key lights
4. ☐ Textures use KTX2/power-of-two
5. ☐ LOD for distant objects
6. ☐ Instancing for repeated geometry
7. ☐ BVH for large mesh raycasting
8. ☐ Object pooling for dynamic spawns
9. ☐ No per-frame allocations in hot paths
10. ☐ Stats.js visible during development
