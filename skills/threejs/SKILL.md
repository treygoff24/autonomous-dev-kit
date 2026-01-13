---
name: threejs
description: This skill should be used when the user asks to "build a Three.js app", "optimize Three.js performance", "set up a 3D asset pipeline", "add postprocessing/particles/physics", or needs production-grade Three.js architecture and rendering guidance.
---

# Three.js Advanced 3D Workflow

Build complex, performant Three.js applications using production-proven patterns. Load the reference file that matches the task.

## Quick Reference: Top 10 Power Moves

1. **Minimize Draw Calls** - Use `InstancedMesh` for repeated geometry, merge static meshes by material
2. **Use BVH for Raycasting** - `three-mesh-bvh` for large meshes (100k+ triangles)
3. **Pool & Reuse Objects** - Never create/destroy per frame; use `.visible=false` or object pools
4. **Compressed Assets** - glTF + Draco/Meshopt for geometry, KTX2/BasisU for textures
5. **Linear Color Workflow** - `renderer.outputColorSpace = THREE.SRGBColorSpace`, set `texture.colorSpace = THREE.SRGBColorSpace` for color textures
6. **Physical Lights** - `renderer.useLegacyLights = false`, use real unit intensities (candelas/lux)
7. **Limit DPR** - `renderer.setPixelRatio(Math.min(2, window.devicePixelRatio))`
8. **Fixed-Step Physics** - Decouple physics from render rate, interpolate for smooth visuals
9. **Avoid Per-Frame Allocations** - Reuse `Vector3`, `Matrix4`; call `.set()` not `new`
10. **Profile Continuously** - `renderer.info`, Stats.js, Spector.js, Chrome DevTools

## Workflow Decision Tree

| Task | Reference |
|------|-----------|
| Building app architecture | [architecture.md](references/architecture.md) |
| Performance issues | [performance.md](references/performance.md) |
| Loading/exporting assets | [asset-pipeline.md](references/asset-pipeline.md) |
| Realistic lighting/materials | [lighting-materials.md](references/lighting-materials.md) |
| Picking, controls, UI | [interaction.md](references/interaction.md) |
| Particles, crowds, VFX | [effects.md](references/effects.md) |
| Postprocessing pipeline | [postprocessing.md](references/postprocessing.md) |
| Physics integration | [physics.md](references/physics.md) |
| Debugging issues | [troubleshooting.md](references/troubleshooting.md) |

## Project Structure Template

```
src/
├── core/
│   ├── Engine.ts       # Main loop, init, resize handling
│   └── AssetManager.ts # Loading textures, models with caching
├── systems/
│   ├── RenderSystem.ts    # Renderer, cameras, postprocessing
│   ├── PhysicsSystem.ts   # Physics engine step & sync
│   ├── InputSystem.ts     # KB/Mouse/Touch/Gamepad abstraction
│   └── AnimationSystem.ts # AnimationMixer updates
├── scenes/
│   └── WorldScene.ts      # Scene graph construction
└── utils/
    └── debug.ts           # Helpers, bounding boxes, stats
```

## Engine Loop Pattern

```typescript
class Engine {
  private systems: System[] = [];
  private lastTime = performance.now();

  start() {
    requestAnimationFrame(this.tick);
  }

  tick = (now: number) => {
    const dt = (now - this.lastTime) / 1000;
    for (const sys of this.systems) sys.update(dt);
    renderer.render(scene, camera);
    this.lastTime = now;
    requestAnimationFrame(this.tick);
  }
}
```

## Fixed Timestep Physics

```typescript
const SIM_STEP = 1/60;
let accum = 0;

function animate() {
  accum += clock.getDelta();
  while (accum >= SIM_STEP) {
    physicsWorld.step(SIM_STEP);
    accum -= SIM_STEP;
  }
  // Interpolate: lerp positions by accum/SIM_STEP for smooth visuals
  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}
```

## Asset Loading Pattern

```typescript
const loader = new GLTFLoader();
const dracoLoader = new DRACOLoader();
dracoLoader.setDecoderPath('/draco/');
loader.setDRACOLoader(dracoLoader);

// For KTX2 textures
const ktx2Loader = new KTX2Loader();
ktx2Loader.setTranscoderPath('/basis/');
ktx2Loader.detectSupport(renderer);
loader.setKTX2Loader(ktx2Loader);
```

## Instancing Example

```typescript
const count = 10000;
const mesh = new THREE.InstancedMesh(geometry, material, count);
const matrix = new THREE.Matrix4();

for (let i = 0; i < count; i++) {
  matrix.setPosition(x, y, z);
  mesh.setMatrixAt(i, matrix);
}
mesh.instanceMatrix.needsUpdate = true;
scene.add(mesh); // 1 draw call for 10k objects
```

## BVH-Accelerated Raycasting

```typescript
import { MeshBVH, acceleratedRaycast } from 'three-mesh-bvh';

geometry.boundsTree = new MeshBVH(geometry);
mesh.raycast = acceleratedRaycast;
// Now raycaster.intersectObject(mesh) uses BVH
```

## Resize & Context Handling

```typescript
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  composer?.setSize(window.innerWidth, window.innerHeight);
});

canvas.addEventListener('webglcontextlost', e => {
  e.preventDefault();
  console.warn('WebGL context lost');
});
```

## Common Dependencies

| Package | Purpose |
|---------|---------|
| `three` | Core library |
| `three-mesh-bvh` | Accelerated raycasting |
| `@gltf-transform/cli` | Asset optimization |
| `stats.js` | FPS monitoring |
| `lil-gui` | Debug controls |
| Rapier/Ammo.js | Physics engines |

## Quality Tiers Pattern

```typescript
const quality = detectDevice(); // 'low' | 'medium' | 'high'

const config = {
  low: { shadows: false, pixelRatio: 1, ssao: false },
  medium: { shadows: true, pixelRatio: 1.5, ssao: false },
  high: { shadows: true, pixelRatio: 2, ssao: true }
}[quality];
```

## Build Plan + Acceptance Tests (Terse)

Build plan:
- Scaffold engine loop + resize + render target.
- Load one representative glTF + texture pipeline (Draco/KTX2).
- Add interaction + camera + picking.
- Add one effect (particles/post) + physics if needed.
- Profile + cap DPR + verify device tiers.

Acceptance tests:
- Scene loads with correct color space and no console warnings.
- FPS meets target on a mid-tier device.
- Picking works reliably on 1k objects.
- Physics sync is stable (no visible jitter).
- Postprocessing toggles cleanly on/off.
