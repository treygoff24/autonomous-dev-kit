# Asset Pipeline (Blender to Three.js)

## Table of Contents
- [glTF Workflow](#gltf-workflow)
- [Mesh Compression](#mesh-compression)
- [Texture Compression](#texture-compression)
- [Blender Export Settings](#blender-export-settings)
- [Animation Export](#animation-export)
  - [AnimationMixer Fundamentals](#animationmixer-fundamentals)
  - [Animation Blending](#animation-blending)
  - [Additive Animations](#additive-animations)
  - [Root Motion](#root-motion)
  - [Animation Events](#animation-events)
- [Lightmap Baking](#lightmap-baking)
- [Asset Validation](#asset-validation)
- [Automation Pipeline](#automation-pipeline)

## glTF Workflow

### Why glTF?

- Efficient binary format (.glb) or JSON + bin (.gltf)
- PBR materials, skinning, morphs, animations
- First-class Three.js support via GLTFLoader

### Basic Loading

```typescript
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

const loader = new GLTFLoader();
loader.load('model.glb', (gltf) => {
  scene.add(gltf.scene);

  // Access animations
  const mixer = new THREE.AnimationMixer(gltf.scene);
  gltf.animations.forEach(clip => {
    mixer.clipAction(clip).play();
  });
});
```

## Mesh Compression

### Draco vs Meshopt

| Feature | Draco | Meshopt (gltfpack) |
|---------|-------|-------------------|
| Compression ratio | Best (5-10×) | Good (3-4×) |
| Decode speed | Slow | Fast |
| Animation support | No | Yes |
| Best for | High-poly static | General purpose |

### Using Draco

```typescript
import { DRACOLoader } from 'three/examples/jsm/loaders/DRACOLoader.js';

const dracoLoader = new DRACOLoader();
dracoLoader.setDecoderPath('/draco/');
dracoLoader.setDecoderConfig({ type: 'js' }); // or 'wasm'

const gltfLoader = new GLTFLoader();
gltfLoader.setDRACOLoader(dracoLoader);
```

### Using Meshopt

```bash
# Install gltfpack
npm install -g gltfpack

# Compress
gltfpack -i model.glb -o model-opt.glb -cc
```

```typescript
import { MeshoptDecoder } from 'three/examples/jsm/libs/meshopt_decoder.module.js';

const loader = new GLTFLoader();
loader.setMeshoptDecoder(MeshoptDecoder);
```

### When to Use Which

- **Draco**: CAD models, architectural visualization, static high-poly
- **Meshopt**: Games, animated characters, general use
- **Neither**: Small models (<0.5MB) where decode overhead isn't worth it

## Texture Compression

### KTX2 / Basis Universal

GPU-compressed textures that stay compressed in VRAM:

```typescript
import { KTX2Loader } from 'three/examples/jsm/loaders/KTX2Loader.js';

const ktx2Loader = new KTX2Loader();
ktx2Loader.setTranscoderPath('/basis/');
ktx2Loader.detectSupport(renderer);

const gltfLoader = new GLTFLoader();
gltfLoader.setKTX2Loader(ktx2Loader);
```

### ETC1S vs UASTC

| Mode | Quality | Size | Use For |
|------|---------|------|---------|
| ETC1S | Good | Smallest | Diffuse, lightmaps |
| UASTC | Excellent | Larger | Normal maps, roughness |

### Converting Textures

```bash
# Using gltf-transform
npx gltf-transform etc1s input.glb output.glb --slots baseColor
npx gltf-transform uastc input.glb output.glb --slots normal

# Using toktx
toktx --encode etc1s diffuse.ktx2 diffuse.png
toktx --encode uastc normal.ktx2 normal.png
```

## Blender Export Settings

### Transform Settings

- **Apply Modifiers**: Yes
- **+Y Up**: Yes (glTF is Y-up, Blender is Z-up)
- **Apply Transform**: Yes (or transforms baked in)

### Material Settings

- Use Principled BSDF shader
- Connect textures to correct slots:
  - Base Color → baseColorTexture
  - Metallic → metallicRoughnessTexture.B
  - Roughness → metallicRoughnessTexture.G
  - Normal Map → normalTexture

### Scale Conventions

1 Blender unit = 1 meter in glTF (with default scale)

Maintain consistent scale across all assets.

## Animation Export

### Action Management

```
Blender:
1. Create multiple Actions (Walk, Run, Jump)
2. Push each to NLA as strips, or
3. Use "Export all Actions" in glTF exporter
```

### AnimationMixer Fundamentals

```typescript
loader.load('character.glb', (gltf) => {
  const mixer = new THREE.AnimationMixer(gltf.scene);

  // Find clip by name
  const walkClip = gltf.animations.find(a => a.name === 'Walk');
  const walkAction = mixer.clipAction(walkClip);

  // Crossfade between animations
  function switchToRun() {
    const runClip = gltf.animations.find(a => a.name === 'Run');
    const runAction = mixer.clipAction(runClip);

    walkAction.crossFadeTo(runAction, 0.3, true);
    runAction.play();
  }
});
```

### Action States and Control

```typescript
// Action configuration
action.setLoop(THREE.LoopRepeat, Infinity);  // LoopOnce, LoopRepeat, LoopPingPong
action.clampWhenFinished = true;             // Hold last frame
action.timeScale = 1.5;                      // Playback speed
action.weight = 1.0;                         // Blend weight (0-1)

// Play states
action.play();
action.stop();
action.reset();                              // Return to start
action.paused = true;

// Time control
action.time = 0.5;                           // Jump to time
const duration = action.getClip().duration;
```

### Animation Blending

```typescript
class AnimationController {
  private mixer: THREE.AnimationMixer;
  private actions: Map<string, THREE.AnimationAction> = new Map();
  private currentAction: THREE.AnimationAction | null = null;

  constructor(model: THREE.Object3D, clips: THREE.AnimationClip[]) {
    this.mixer = new THREE.AnimationMixer(model);

    for (const clip of clips) {
      const action = this.mixer.clipAction(clip);
      action.enabled = true;
      action.setEffectiveWeight(0);
      this.actions.set(clip.name, action);
    }
  }

  play(name: string, fadeTime = 0.3) {
    const newAction = this.actions.get(name);
    if (!newAction || newAction === this.currentAction) return;

    newAction.reset();
    newAction.setEffectiveWeight(1);
    newAction.play();

    if (this.currentAction) {
      this.currentAction.crossFadeTo(newAction, fadeTime, true);
    }

    this.currentAction = newAction;
  }

  update(dt: number) {
    this.mixer.update(dt);
  }
}
```

### Additive Animations

Layer animations on top of base:

```typescript
// Base locomotion
const walkAction = mixer.clipAction(walkClip);
walkAction.play();

// Additive layer (e.g., breathing, looking around)
const breatheAction = mixer.clipAction(breatheClip);
breatheAction.blendMode = THREE.AdditiveAnimationBlendMode;
breatheAction.setEffectiveWeight(0.5);
breatheAction.play();
```

### Root Motion

Extract translation/rotation from animation:

```typescript
class RootMotionExtractor {
  private prevPos = new THREE.Vector3();
  private prevRot = new THREE.Quaternion();
  private rootBone: THREE.Bone;

  constructor(skeleton: THREE.Skeleton) {
    this.rootBone = skeleton.bones[0]; // Usually hip/root
    this.captureTransform();
  }

  private captureTransform() {
    this.prevPos.copy(this.rootBone.position);
    this.prevRot.copy(this.rootBone.quaternion);
  }

  extractDelta(): { position: THREE.Vector3; rotation: THREE.Quaternion } {
    const deltaPos = new THREE.Vector3().subVectors(this.rootBone.position, this.prevPos);
    const deltaRot = this.prevRot.clone().invert().multiply(this.rootBone.quaternion);

    // Reset root to origin (baked motion)
    this.rootBone.position.set(0, this.rootBone.position.y, 0); // Keep Y for jumps
    this.captureTransform();

    return { position: deltaPos, rotation: deltaRot };
  }
}

// In update loop
const delta = rootMotion.extractDelta();
character.position.add(delta.position.applyQuaternion(character.quaternion));
```

### Animation Events

Trigger callbacks at specific times:

```typescript
// Add event markers to clip
const clip = gltf.animations[0];
const footstepEvent = new THREE.AnimationClipEvent('footstep', 0.4);
clip.events.push(footstepEvent);

// Listen for events
mixer.addEventListener('animationEvent', (e) => {
  if (e.event.name === 'footstep') {
    playFootstepSound();
  }
});

// Alternative: poll time-based events
class AnimationEventEmitter {
  private markers: { time: number; name: string; fired: boolean }[] = [];

  addMarker(time: number, name: string) {
    this.markers.push({ time, name, fired: false });
  }

  update(action: THREE.AnimationAction, callback: (name: string) => void) {
    const t = action.time;
    for (const marker of this.markers) {
      if (!marker.fired && t >= marker.time) {
        marker.fired = true;
        callback(marker.name);
      }
    }

    // Reset on loop
    if (t < 0.1) {
      this.markers.forEach(m => m.fired = false);
    }
  }
}
```

### Morph Targets (Shape Keys)

```typescript
// Access after loading
const mesh = gltf.scene.getObjectByName('Face');
mesh.morphTargetInfluences[0] = 0.5; // First shape key at 50%

// Animate via mixer
const morphAction = mixer.clipAction(gltf.animations.find(a => a.name === 'Smile'));
```

**Note:** Material must have `morphTargets: true` (GLTFLoader handles this automatically).

## Lightmap Baking

### Blender Workflow

1. Create second UV channel (Lightmap UV)
2. Unwrap with no overlapping (use Smart UV Project or Lightmap Pack)
3. Bake with Cycles: Diffuse (Color only) or Combined
4. Export baked texture

### Three.js Usage

```typescript
const lightmapTexture = textureLoader.load('lightmap.jpg');
lightmapTexture.channel = 1; // UV2 (Three.js r152+)
lightmapTexture.flipY = false; // Often needed for baked lightmaps

material.lightMap = lightmapTexture;
material.lightMapIntensity = 1.0;

// Ensure geometry has uv2 attribute
if (!geometry.attributes.uv2) {
  // Clone the buffer to avoid aliasing issues
  geometry.setAttribute('uv2', geometry.attributes.uv.clone());
}
```

**Note:** `texture.channel` requires Three.js r152+. For older versions, the second UV set is automatically used for lightmaps.

## Asset Validation

### glTF Validator

```bash
# Install
npm install -g gltf-validator

# Validate
gltf-validator model.glb
```

### Automated Checks

```typescript
// Budget thresholds
const BUDGET = {
  maxTriangles: 50000,
  maxDrawCalls: 10,
  maxTextureSize: 2048,
  maxFileSize: 5 * 1024 * 1024 // 5MB
};

async function validateAsset(url: string) {
  const gltf = await loader.loadAsync(url);
  const errors: string[] = [];

  let totalTris = 0;
  let drawCalls = 0;

  gltf.scene.traverse(obj => {
    if (obj.isMesh) {
      drawCalls++;
      const geo = obj.geometry;
      const count = geo.index
        ? geo.index.count / 3
        : geo.attributes.position.count / 3;
      totalTris += count;
    }
  });

  if (totalTris > BUDGET.maxTriangles) {
    errors.push(`Triangles: ${totalTris} exceeds ${BUDGET.maxTriangles}`);
  }
  if (drawCalls > BUDGET.maxDrawCalls) {
    errors.push(`Draw calls: ${drawCalls} exceeds ${BUDGET.maxDrawCalls}`);
  }

  return errors;
}
```

## Automation Pipeline

### CI Asset Processing

```bash
#!/bin/bash
# process-assets.sh

for file in assets/*.glb; do
  # Validate
  gltf-validator "$file" || exit 1

  # Optimize
  gltfpack -i "$file" -o "dist/${file##*/}" -cc -tc

  # Compress textures
  npx gltf-transform etc1s "dist/${file##*/}" "dist/${file##*/}" --slots baseColor
done
```

### Custom Properties (Blender → userData)

```python
# In Blender: Object > Custom Properties
# Add: "interactable" = True, "health" = 100
```

Enable "Custom Properties" in glTF export settings.

```typescript
// In Three.js
gltf.scene.traverse(obj => {
  if (obj.userData.interactable) {
    interactables.push(obj);
  }
  if (obj.userData.health !== undefined) {
    obj.userData.currentHealth = obj.userData.health;
  }
});
```

### Pipeline Tools Summary

| Tool | Purpose |
|------|---------|
| gltf-validator | Spec compliance checking |
| gltf-transform | Compression, texture conversion |
| gltfpack | Meshopt compression |
| Blender glTF exporter | DCC to glTF |
| Draco encoder | Geometry compression |
| toktx | KTX2 texture conversion |
