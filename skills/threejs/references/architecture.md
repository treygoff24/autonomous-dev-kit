# Rendering Architecture for Large Projects

## Table of Contents
- [Scene Graph Organization](#scene-graph-organization)
- [Multiple Scenes and Cameras](#multiple-scenes-and-cameras)
- [Render Loop Design](#render-loop-design)
- [Systems Pattern](#systems-pattern)
- [Component-Based Approach](#component-based-approach)

## Scene Graph Organization

### Grouping and Layering

Partition scenes for manageability and performance:

```typescript
// Organize by category
const environment = new THREE.Group();
environment.name = 'Environment';

const dynamicObjects = new THREE.Group();
dynamicObjects.name = 'DynamicObjects';

const ui = new THREE.Group();
ui.name = 'UI';

scene.add(environment, dynamicObjects, ui);
```

### Three.js Layers

Layers allow toggling visibility per camera but have overhead—the renderer still checks every object:

```typescript
// Assign object to layer 1
mesh.layers.set(1);

// Camera sees layers 0 and 1
camera.layers.enable(1);
```

**Note:** For distinctly separate render needs (shadowmap vs main scene), using **separate scenes** can outperform layers.

## Multiple Scenes and Cameras

### Picture-in-Picture / Minimap

```typescript
// Main render
renderer.setViewport(0, 0, width, height);
renderer.render(mainScene, mainCamera);

// Minimap in corner
renderer.clearDepth();
renderer.setViewport(width - 200, height - 200, 200, 200);
renderer.setScissor(width - 200, height - 200, 200, 200);
renderer.setScissorTest(true);
renderer.render(mainScene, minimapCamera);
renderer.setScissorTest(false);
```

### Mirrors and Portals

Use `THREE.Reflector` for planar reflections:

```typescript
import { Reflector } from 'three/examples/jsm/objects/Reflector.js';

const mirror = new Reflector(geometry, {
  textureWidth: 1024,
  textureHeight: 1024,
  color: 0x889999
});
```

## Render Loop Design

### Variable vs Fixed Timestep

| Approach | Use Case |
|----------|----------|
| Variable (rAF delta) | Simple animations, camera movement |
| Fixed timestep | Physics, game logic requiring determinism |

### Fixed Timestep with Interpolation

```typescript
const PHYSICS_STEP = 1/60;
let accumulator = 0;
let previousState = new Map(); // Store previous positions

function gameLoop(timestamp) {
  const delta = clock.getDelta();
  accumulator += delta;

  // Store current state before physics step
  scene.traverse(obj => {
    if (obj.userData.physicsBody) {
      previousState.set(obj.uuid, obj.position.clone());
    }
  });

  // Fixed physics steps
  while (accumulator >= PHYSICS_STEP) {
    physicsWorld.step(PHYSICS_STEP);
    accumulator -= PHYSICS_STEP;
  }

  // Interpolate for smooth rendering
  const alpha = accumulator / PHYSICS_STEP;
  const currPos = new THREE.Vector3();
  scene.traverse(obj => {
    if (obj.userData.physicsBody) {
      const prev = previousState.get(obj.uuid);
      const trans = obj.userData.physicsBody.translation();
      currPos.set(trans.x, trans.y, trans.z); // Convert physics vector to THREE.Vector3
      obj.position.lerpVectors(prev, currPos, alpha);
    }
  });

  renderer.render(scene, camera);
  requestAnimationFrame(gameLoop);
}
```

## Systems Pattern

Organize code into independent systems:

```typescript
interface System {
  update(dt: number): void;
  dispose?(): void;
}

class PhysicsSystem implements System {
  update(dt: number) {
    this.world.step(dt);
    this.syncTransforms();
  }

  private syncTransforms() {
    for (const [mesh, body] of this.bodies) {
      mesh.position.copy(body.translation());
      mesh.quaternion.copy(body.rotation());
    }
  }
}

class AnimationSystem implements System {
  private mixers: THREE.AnimationMixer[] = [];

  update(dt: number) {
    for (const mixer of this.mixers) {
      mixer.update(dt);
    }
  }
}

class RenderSystem implements System {
  constructor(
    private renderer: THREE.WebGLRenderer,
    private scene: THREE.Scene,
    private camera: THREE.Camera,
    private composer?: EffectComposer
  ) {}

  update(dt: number) {
    if (this.composer) {
      this.composer.render(dt);
    } else {
      this.renderer.render(this.scene, this.camera);
    }
  }
}
```

## Component-Based Approach

Extend `Object3D` with custom behaviors:

```typescript
class InteractiveObject extends THREE.Mesh {
  userData: { hoverable: boolean; clickable: boolean } = {
    hoverable: true,
    clickable: true
  };

  update(dt: number) {
    // Per-frame logic
  }

  onHover() {
    this.material.emissive.setHex(0x333333);
  }

  onUnhover() {
    this.material.emissive.setHex(0x000000);
  }

  onClick() {
    console.log('Clicked:', this.name);
  }
}

// Propagate updates through scene graph
function updateScene(root: THREE.Object3D, dt: number) {
  root.traverse(obj => {
    if ('update' in obj && typeof obj.update === 'function') {
      obj.update(dt);
    }
  });
}
```

## Scene Node Conventions

### Naming
- Lights: `KEY_Light`, `FILL_Light`, `RIM_Light`
- Spawn points: `SpawnPoint_01`, `SpawnPoint_Player`
- Interactive: `Door_01`, `Switch_MainPower`

### userData for Metadata

```typescript
// In Blender: custom properties export to userData
mesh.userData = {
  type: 'collectible',
  value: 100,
  respawnTime: 30
};

// Query at runtime
scene.traverse(obj => {
  if (obj.userData.type === 'collectible') {
    collectibles.push(obj);
  }
});
```

### Origin and Scale

- Keep scene origin at (0,0,0) center of playable area
- **Never move the Scene object itself**—always move children
- For large worlds, consider origin shifting or tiling to avoid floating-point precision issues at extreme coordinates
