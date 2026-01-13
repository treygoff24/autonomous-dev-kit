# Physics Integration

## Table of Contents
- [Engine Comparison](#engine-comparison)
- [Rapier Integration](#rapier-integration)
- [Ammo.js Integration](#ammojs-integration)
- [Fixed Timestep](#fixed-timestep)
- [Transform Syncing](#transform-syncing)
- [Collision Shapes](#collision-shapes)
- [Constraints and Joints](#constraints-and-joints)
- [Character Controllers](#character-controllers)

## Engine Comparison

| Engine | Size | Performance | Features |
|--------|------|-------------|----------|
| Rapier | ~500KB WASM | Excellent | Rigid bodies, joints |
| Ammo.js | ~1MB WASM | Good | Full Bullet physics, soft bodies |
| Cannon-es | ~150KB JS | Moderate | Simple, no WASM |
| Oimo.js | ~100KB JS | Moderate | Lightweight, basic |

**Recommendation:**
- Rapier for most games (fast, modern)
- Ammo for complex physics (soft bodies, vehicles)

## Rapier Integration

### Setup

```typescript
import RAPIER from '@dimforge/rapier3d-compat';

let world: RAPIER.World;

async function initPhysics() {
  await RAPIER.init();
  const gravity = { x: 0, y: -9.81, z: 0 };
  world = new RAPIER.World(gravity);
}
```

### Creating Bodies

```typescript
// Ground (static)
const groundDesc = RAPIER.RigidBodyDesc.fixed();
const groundBody = world.createRigidBody(groundDesc);

const groundColliderDesc = RAPIER.ColliderDesc.cuboid(50, 0.1, 50);
world.createCollider(groundColliderDesc, groundBody);

// Dynamic box
const boxDesc = RAPIER.RigidBodyDesc.dynamic()
  .setTranslation(0, 10, 0);
const boxBody = world.createRigidBody(boxDesc);

const boxColliderDesc = RAPIER.ColliderDesc.cuboid(0.5, 0.5, 0.5)
  .setRestitution(0.5)
  .setFriction(0.7);
world.createCollider(boxColliderDesc, boxBody);
```

### Stepping and Syncing

```typescript
const FIXED_DT = 1 / 60;
let accumulator = 0;

function update(dt: number) {
  accumulator += dt;

  while (accumulator >= FIXED_DT) {
    world.step();
    accumulator -= FIXED_DT;
  }

  // Sync Three.js meshes
  physicsObjects.forEach(({ mesh, body }) => {
    const pos = body.translation();
    const rot = body.rotation();

    mesh.position.set(pos.x, pos.y, pos.z);
    mesh.quaternion.set(rot.x, rot.y, rot.z, rot.w);
  });
}
```

## Ammo.js Integration

### Setup

```typescript
import Ammo from 'ammo.js';

let physicsWorld: Ammo.btDiscreteDynamicsWorld;
let tmpTrans: Ammo.btTransform;

async function initAmmo() {
  await Ammo();

  const collisionConfig = new Ammo.btDefaultCollisionConfiguration();
  const dispatcher = new Ammo.btCollisionDispatcher(collisionConfig);
  const broadphase = new Ammo.btDbvtBroadphase();
  const solver = new Ammo.btSequentialImpulseConstraintSolver();

  physicsWorld = new Ammo.btDiscreteDynamicsWorld(
    dispatcher, broadphase, solver, collisionConfig
  );
  physicsWorld.setGravity(new Ammo.btVector3(0, -9.81, 0));

  tmpTrans = new Ammo.btTransform();
}
```

### Creating Bodies

```typescript
function createRigidBody(
  mesh: THREE.Mesh,
  shape: Ammo.btCollisionShape,
  mass: number
): Ammo.btRigidBody {
  const transform = new Ammo.btTransform();
  transform.setIdentity();
  transform.setOrigin(new Ammo.btVector3(
    mesh.position.x, mesh.position.y, mesh.position.z
  ));
  transform.setRotation(new Ammo.btQuaternion(
    mesh.quaternion.x, mesh.quaternion.y, mesh.quaternion.z, mesh.quaternion.w
  ));

  const motionState = new Ammo.btDefaultMotionState(transform);
  const localInertia = new Ammo.btVector3(0, 0, 0);

  if (mass > 0) {
    shape.calculateLocalInertia(mass, localInertia);
  }

  const rbInfo = new Ammo.btRigidBodyConstructionInfo(
    mass, motionState, shape, localInertia
  );
  const body = new Ammo.btRigidBody(rbInfo);

  physicsWorld.addRigidBody(body);

  return body;
}
```

### Syncing

```typescript
function syncPhysics() {
  physicsObjects.forEach(({ mesh, body }) => {
    const motionState = body.getMotionState();
    if (motionState) {
      motionState.getWorldTransform(tmpTrans);
      const pos = tmpTrans.getOrigin();
      const rot = tmpTrans.getRotation();

      mesh.position.set(pos.x(), pos.y(), pos.z());
      mesh.quaternion.set(rot.x(), rot.y(), rot.z(), rot.w());
    }
  });
}
```

## Fixed Timestep

### Why Fixed Timestep?

Variable timesteps cause:
- Non-deterministic physics
- Tunneling at low FPS
- Jittery behavior

### Implementation

```typescript
const PHYSICS_STEP = 1 / 60;
const MAX_SUBSTEPS = 10;
let accumulator = 0;

function gameLoop(timestamp: number) {
  const dt = clock.getDelta();
  accumulator += dt;

  // Cap substeps to prevent spiral of death
  const steps = Math.min(Math.floor(accumulator / PHYSICS_STEP), MAX_SUBSTEPS);

  for (let i = 0; i < steps; i++) {
    physicsWorld.step(); // or world.stepSimulation(PHYSICS_STEP)
    accumulator -= PHYSICS_STEP;
  }

  // Interpolation factor for rendering
  const alpha = accumulator / PHYSICS_STEP;
  interpolateTransforms(alpha);

  renderer.render(scene, camera);
  requestAnimationFrame(gameLoop);
}
```

### Interpolation

```typescript
function interpolateTransforms(alpha: number) {
  physicsObjects.forEach(({ mesh, prevState, currState }) => {
    mesh.position.lerpVectors(prevState.position, currState.position, alpha);
    mesh.quaternion.slerpQuaternions(prevState.quaternion, currState.quaternion, alpha);
  });
}
```

## Transform Syncing

### Mesh to Body

```typescript
// Move physics body to match mesh (e.g., after teleport)
function setBodyTransform(body: RAPIER.RigidBody, mesh: THREE.Mesh) {
  body.setTranslation(
    { x: mesh.position.x, y: mesh.position.y, z: mesh.position.z },
    true // wake up
  );
  body.setRotation(
    { x: mesh.quaternion.x, y: mesh.quaternion.y, z: mesh.quaternion.z, w: mesh.quaternion.w },
    true
  );
}
```

### Body to Mesh

```typescript
// After physics step
function syncBodyToMesh(body: RAPIER.RigidBody, mesh: THREE.Mesh) {
  const pos = body.translation();
  const rot = body.rotation();

  mesh.position.set(pos.x, pos.y, pos.z);
  mesh.quaternion.set(rot.x, rot.y, rot.z, rot.w);
}
```

## Collision Shapes

### Shape Selection

| Geometry | Shape | Notes |
|----------|-------|-------|
| Box | Cuboid/Box | Fastest |
| Sphere | Sphere | Fast |
| Capsule | Capsule | Good for characters |
| Cylinder | Cylinder | Moderate |
| Complex | Convex Hull | Moderate, max ~256 verts |
| Very Complex | Trimesh | Slow, static only |

### Convex Hull from Mesh

```typescript
// Rapier
const points = new Float32Array(geometry.attributes.position.array);
const colliderDesc = RAPIER.ColliderDesc.convexHull(points);

// Ammo
const hull = new Ammo.btConvexHullShape();
const positions = geometry.attributes.position.array;
for (let i = 0; i < positions.length; i += 3) {
  hull.addPoint(new Ammo.btVector3(positions[i], positions[i+1], positions[i+2]));
}
```

### Compound Shapes

```typescript
// Rapier: multiple colliders on one body
const bodyDesc = RAPIER.RigidBodyDesc.dynamic();
const body = world.createRigidBody(bodyDesc);

// Body part 1
world.createCollider(
  RAPIER.ColliderDesc.cuboid(1, 0.5, 0.5).setTranslation(0, 0.5, 0),
  body
);

// Body part 2
world.createCollider(
  RAPIER.ColliderDesc.ball(0.5).setTranslation(0, 1.5, 0),
  body
);
```

## Constraints and Joints

### Rapier Joints

```typescript
// Ball joint (point-to-point)
const params = RAPIER.JointData.spherical(
  { x: 0, y: 1, z: 0 },  // Anchor on body1
  { x: 0, y: -1, z: 0 }  // Anchor on body2
);
const joint = world.createImpulseJoint(params, body1, body2);

// Hinge joint
const hingeParams = RAPIER.JointData.revolute(
  { x: 0, y: 0, z: 0 },  // Anchor on body1
  { x: 0, y: 0, z: 0 },  // Anchor on body2
  { x: 0, y: 1, z: 0 }   // Axis
);
world.createImpulseJoint(hingeParams, doorFrame, door);
```

### Ammo Constraints

```typescript
// Hinge constraint
const pivotA = new Ammo.btVector3(0, 1, 0);
const pivotB = new Ammo.btVector3(0, -1, 0);
const axisA = new Ammo.btVector3(0, 1, 0);
const axisB = new Ammo.btVector3(0, 1, 0);

const hinge = new Ammo.btHingeConstraint(
  bodyA, bodyB, pivotA, pivotB, axisA, axisB
);
hinge.setLimit(-Math.PI / 4, Math.PI / 4, 0.9, 0.3);
physicsWorld.addConstraint(hinge);
```

## Character Controllers

### Kinematic Character (Rapier)

```typescript
const characterDesc = RAPIER.RigidBodyDesc.kinematicPositionBased()
  .setTranslation(0, 1, 0);
const characterBody = world.createRigidBody(characterDesc);

const capsuleColliderDesc = RAPIER.ColliderDesc.capsule(0.5, 0.3);
const characterCollider = world.createCollider(capsuleColliderDesc, characterBody);

// Character controller
const characterController = world.createCharacterController(0.01); // offset

function updateCharacter(input: { x: number; z: number }, dt: number) {
  const movement = new RAPIER.Vector3(
    input.x * speed * dt,
    -9.81 * dt, // gravity
    input.z * speed * dt
  );

  characterController.computeColliderMovement(
    characterCollider,
    movement,
    RAPIER.QueryFilterFlags.EXCLUDE_SENSORS
  );

  const correctedMovement = characterController.computedMovement();
  const pos = characterBody.translation();

  characterBody.setNextKinematicTranslation({
    x: pos.x + correctedMovement.x,
    y: pos.y + correctedMovement.y,
    z: pos.z + correctedMovement.z
  });
}
```

### Ground Detection

```typescript
function isGrounded(characterBody: RAPIER.RigidBody): boolean {
  const origin = characterBody.translation();
  origin.y -= 0.1; // Start slightly below feet

  const ray = new RAPIER.Ray(origin, { x: 0, y: -1, z: 0 });
  const hit = world.castRay(ray, 0.2, true);

  return hit !== null;
}
```
