# Interaction: Picking, Controls, UI

## Table of Contents
- [Raycasting](#raycasting)
- [BVH Acceleration](#bvh-acceleration)
- [GPU Picking](#gpu-picking)
- [Camera Controls](#camera-controls)
- [Advanced Camera Systems](#advanced-camera-systems)
- [Input Handling](#input-handling)
- [Gamepad Support](#gamepad-support)
- [2D UI Overlays](#2d-ui-overlays)
- [In-Scene UI](#in-scene-ui)
- [Transform Controls](#transform-controls)

## Raycasting

### Basic Setup

```typescript
const raycaster = new THREE.Raycaster();
const mouse = new THREE.Vector2();

function onMouseMove(event: MouseEvent) {
  // Convert to NDC (-1 to +1)
  mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
  mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;
}

function checkIntersections() {
  raycaster.setFromCamera(mouse, camera);
  const intersects = raycaster.intersectObjects(scene.children, true);

  if (intersects.length > 0) {
    const hit = intersects[0];
    console.log('Hit:', hit.object.name, 'at', hit.point);
  }
}
```

### Filtering Intersections

```typescript
// Only check specific objects
const interactables = scene.children.filter(c => c.userData.interactive);
const intersects = raycaster.intersectObjects(interactables, false);

// Filter by layer
raycaster.layers.set(1); // Only layer 1
```

## BVH Acceleration

Essential for large meshes (100k+ triangles):

```typescript
import { MeshBVH, acceleratedRaycast } from 'three-mesh-bvh';

// One-time setup per geometry
geometry.boundsTree = new MeshBVH(geometry);

// Override raycast method
mesh.raycast = acceleratedRaycast;

// Now standard raycasting is BVH-accelerated
const intersects = raycaster.intersectObject(mesh);
```

### BVH Options

```typescript
import { MeshBVH } from 'three-mesh-bvh';

const bvh = new MeshBVH(geometry, {
  maxLeafTris: 10,                          // Triangles per leaf
  strategy: MeshBVH.BUILD_STRATEGY.CENTER,  // SAH, CENTER, AVERAGE
  setBoundingBox: true                      // Auto-compute bounds
});
```

## GPU Picking

For thousands of objects or per-pixel precision:

```typescript
class GPUPicker {
  private pickingScene = new THREE.Scene();
  private pickingTexture: THREE.WebGLRenderTarget;
  private idToObject = new Map<number, THREE.Object3D>();
  private savedToneMapping: THREE.ToneMapping;
  private savedBackground: THREE.Color | THREE.Texture | null;

  constructor(private renderer: THREE.WebGLRenderer, private camera: THREE.Camera) {
    // Use nearest filtering to avoid color interpolation
    this.pickingTexture = new THREE.WebGLRenderTarget(1, 1, {
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      format: THREE.RGBAFormat,
      type: THREE.UnsignedByteType
    });
  }

  register(object: THREE.Mesh, id: number) {
    const pickingMaterial = new THREE.MeshBasicMaterial({
      color: new THREE.Color(id)
    });
    const pickingMesh = object.clone();
    pickingMesh.material = pickingMaterial;
    this.pickingScene.add(pickingMesh);
    this.idToObject.set(id, object);
  }

  pick(x: number, y: number): THREE.Object3D | null {
    // Account for device pixel ratio
    const pixelRatio = this.renderer.getPixelRatio();
    const px = Math.floor(x * pixelRatio);
    const py = Math.floor(y * pixelRatio);

    // Save and disable tone mapping (would corrupt ID colors)
    this.savedToneMapping = this.renderer.toneMapping;
    this.savedBackground = this.pickingScene.background;
    this.renderer.toneMapping = THREE.NoToneMapping;
    this.pickingScene.background = new THREE.Color(0x000000);

    // Set camera to look at single pixel
    this.camera.setViewOffset(
      this.renderer.domElement.width,
      this.renderer.domElement.height,
      px, py, 1, 1
    );

    this.renderer.setRenderTarget(this.pickingTexture);
    this.renderer.render(this.pickingScene, this.camera);

    const pixelBuffer = new Uint8Array(4);
    this.renderer.readRenderTargetPixels(
      this.pickingTexture, 0, 0, 1, 1, pixelBuffer
    );

    // Restore state
    this.camera.clearViewOffset();
    this.renderer.setRenderTarget(null);
    this.renderer.toneMapping = this.savedToneMapping;
    this.pickingScene.background = this.savedBackground;

    const id = (pixelBuffer[0] << 16) | (pixelBuffer[1] << 8) | pixelBuffer[2];
    return this.idToObject.get(id) ?? null;
  }
}
```

**Note:** GPU picking requires a second render pass. For most cases, BVH-accelerated CPU raycasting is simpler and sufficient.

## Camera Controls

### OrbitControls

```typescript
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.05;

// Limits
controls.minDistance = 5;
controls.maxDistance = 100;
controls.minPolarAngle = 0;
controls.maxPolarAngle = Math.PI / 2; // No going below ground

// In render loop
controls.update();
```

### Smooth Target Transition

```typescript
function focusOn(target: THREE.Vector3) {
  const startTarget = controls.target.clone();
  const startPosition = camera.position.clone();
  const endPosition = target.clone().add(new THREE.Vector3(5, 5, 5));

  let t = 0;
  function animate() {
    t += 0.02;
    if (t > 1) t = 1;

    controls.target.lerpVectors(startTarget, target, t);
    camera.position.lerpVectors(startPosition, endPosition, t);

    if (t < 1) requestAnimationFrame(animate);
  }
  animate();
}
```

### PointerLockControls (FPS)

```typescript
import { PointerLockControls } from 'three/examples/jsm/controls/PointerLockControls.js';

const controls = new PointerLockControls(camera, document.body);

document.addEventListener('click', () => controls.lock());

controls.addEventListener('lock', () => console.log('Pointer locked'));
controls.addEventListener('unlock', () => console.log('Pointer unlocked'));

// Movement
const velocity = new THREE.Vector3();
const direction = new THREE.Vector3();

function updateMovement(delta: number) {
  direction.z = Number(moveForward) - Number(moveBackward);
  direction.x = Number(moveRight) - Number(moveLeft);
  direction.normalize();

  velocity.x -= velocity.x * 10.0 * delta;
  velocity.z -= velocity.z * 10.0 * delta;

  if (moveForward || moveBackward) velocity.z -= direction.z * 400.0 * delta;
  if (moveLeft || moveRight) velocity.x -= direction.x * 400.0 * delta;

  controls.moveRight(-velocity.x * delta);
  controls.moveForward(-velocity.z * delta);
}
```

### Third-Person Follow Camera

```typescript
class FollowCamera {
  private offset = new THREE.Vector3(0, 5, -10);
  private smoothness = 0.1;

  update(target: THREE.Object3D) {
    const idealPosition = target.position.clone()
      .add(this.offset.clone().applyQuaternion(target.quaternion));

    camera.position.lerp(idealPosition, this.smoothness);
    camera.lookAt(target.position);
  }
}
```

## Advanced Camera Systems

### Camera Blending

Smoothly transition between camera states:

```typescript
interface CameraState {
  position: THREE.Vector3;
  target: THREE.Vector3;
  fov: number;
}

class CameraBlender {
  private fromState: CameraState;
  private toState: CameraState;
  private progress = 1;
  private duration = 0;

  transitionTo(state: CameraState, duration: number) {
    this.fromState = {
      position: camera.position.clone(),
      target: controls.target.clone(),
      fov: camera.fov
    };
    this.toState = state;
    this.duration = duration;
    this.progress = 0;
  }

  update(dt: number) {
    if (this.progress >= 1) return;

    this.progress = Math.min(1, this.progress + dt / this.duration);
    const t = this.easeInOutCubic(this.progress);

    camera.position.lerpVectors(this.fromState.position, this.toState.position, t);
    controls.target.lerpVectors(this.fromState.target, this.toState.target, t);
    camera.fov = THREE.MathUtils.lerp(this.fromState.fov, this.toState.fov, t);
    camera.updateProjectionMatrix();
  }

  private easeInOutCubic(t: number): number {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }
}
```

### Rail Camera

Follow a predefined path:

```typescript
class RailCamera {
  private curve: THREE.CatmullRomCurve3;
  private progress = 0;

  constructor(points: THREE.Vector3[]) {
    this.curve = new THREE.CatmullRomCurve3(points, false, 'centripetal');
  }

  update(speed: number, lookAhead = 0.01) {
    this.progress = (this.progress + speed) % 1;

    const point = this.curve.getPointAt(this.progress);
    const lookPoint = this.curve.getPointAt((this.progress + lookAhead) % 1);

    camera.position.copy(point);
    camera.lookAt(lookPoint);
  }

  // Visualize the rail
  createHelper(): THREE.Line {
    const points = this.curve.getPoints(50);
    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    return new THREE.Line(geometry, new THREE.LineBasicMaterial({ color: 0xff0000 }));
  }
}
```

### Camera Collision

Prevent camera from clipping through geometry:

```typescript
class CollisionCamera {
  private raycaster = new THREE.Raycaster();
  private desiredDistance: number;
  private minDistance = 0.5;
  private collisionLayers: THREE.Layers;

  constructor(distance: number, collisionMask = 0) {
    this.desiredDistance = distance;
    this.collisionLayers = new THREE.Layers();
    if (collisionMask) this.collisionLayers.mask = collisionMask;
  }

  update(target: THREE.Vector3, direction: THREE.Vector3, scene: THREE.Scene) {
    // Cast ray from target toward desired camera position
    const dir = direction.clone().normalize();
    this.raycaster.set(target, dir);
    this.raycaster.layers = this.collisionLayers;

    const intersects = this.raycaster.intersectObjects(scene.children, true);
    let actualDistance = this.desiredDistance;

    for (const hit of intersects) {
      if (hit.distance < this.desiredDistance) {
        actualDistance = Math.max(this.minDistance, hit.distance - 0.1);
        break;
      }
    }

    // Position camera at safe distance
    camera.position.copy(target).addScaledVector(dir, actualDistance);
    camera.lookAt(target);
  }
}
```

### Cinematic Dolly Zoom (Vertigo Effect)

```typescript
function dollyZoom(targetDistance: number, targetFov: number, duration: number) {
  const startDistance = camera.position.distanceTo(controls.target);
  const startFov = camera.fov;
  let elapsed = 0;

  function animate(dt: number) {
    elapsed += dt;
    const t = Math.min(1, elapsed / duration);

    const distance = THREE.MathUtils.lerp(startDistance, targetDistance, t);
    const fov = THREE.MathUtils.lerp(startFov, targetFov, t);

    // Move camera along look direction
    const dir = new THREE.Vector3().subVectors(camera.position, controls.target).normalize();
    camera.position.copy(controls.target).addScaledVector(dir, distance);
    camera.fov = fov;
    camera.updateProjectionMatrix();

    return t < 1;
  }

  return animate;
}
```

## Input Handling

### Unified Input Manager

```typescript
class InputManager {
  keys: Record<string, boolean> = {};
  mouse = { x: 0, y: 0, buttons: 0 };
  touches: Touch[] = [];

  constructor() {
    window.addEventListener('keydown', e => this.keys[e.code] = true);
    window.addEventListener('keyup', e => this.keys[e.code] = false);

    window.addEventListener('pointermove', e => {
      this.mouse.x = e.clientX;
      this.mouse.y = e.clientY;
    });

    window.addEventListener('pointerdown', e => this.mouse.buttons = e.buttons);
    window.addEventListener('pointerup', e => this.mouse.buttons = e.buttons);

    window.addEventListener('touchstart', e => this.touches = [...e.touches]);
    window.addEventListener('touchmove', e => this.touches = [...e.touches]);
    window.addEventListener('touchend', e => this.touches = [...e.touches]);
  }

  isPressed(key: string) { return !!this.keys[key]; }
  isMouseDown(button = 0) { return (this.mouse.buttons & (1 << button)) !== 0; }
}
```

### Touch Gestures

```typescript
// Pinch zoom detection
let initialPinchDistance = 0;

function onTouchStart(e: TouchEvent) {
  if (e.touches.length === 2) {
    const dx = e.touches[0].clientX - e.touches[1].clientX;
    const dy = e.touches[0].clientY - e.touches[1].clientY;
    initialPinchDistance = Math.sqrt(dx * dx + dy * dy);
  }
}

function onTouchMove(e: TouchEvent) {
  if (e.touches.length === 2) {
    const dx = e.touches[0].clientX - e.touches[1].clientX;
    const dy = e.touches[0].clientY - e.touches[1].clientY;
    const distance = Math.sqrt(dx * dx + dy * dy);
    const scale = distance / initialPinchDistance;
    // Apply zoom based on scale
  }
}
```

## Gamepad Support

### Basic Gamepad API

```typescript
class GamepadManager {
  private gamepad: Gamepad | null = null;
  private deadzone = 0.15;

  constructor() {
    window.addEventListener('gamepadconnected', (e) => {
      console.log('Gamepad connected:', e.gamepad.id);
      this.gamepad = e.gamepad;
    });

    window.addEventListener('gamepaddisconnected', () => {
      console.log('Gamepad disconnected');
      this.gamepad = null;
    });
  }

  update(): GamepadState | null {
    // Must re-fetch gamepad state each frame
    const gamepads = navigator.getGamepads();
    this.gamepad = gamepads[0] ?? null;

    if (!this.gamepad) return null;

    return {
      leftStick: this.applyDeadzone(this.gamepad.axes[0], this.gamepad.axes[1]),
      rightStick: this.applyDeadzone(this.gamepad.axes[2], this.gamepad.axes[3]),
      buttons: this.gamepad.buttons.map(b => ({
        pressed: b.pressed,
        value: b.value
      }))
    };
  }

  private applyDeadzone(x: number, y: number): { x: number; y: number } {
    const mag = Math.sqrt(x * x + y * y);
    if (mag < this.deadzone) return { x: 0, y: 0 };

    const normalized = (mag - this.deadzone) / (1 - this.deadzone);
    return {
      x: (x / mag) * normalized,
      y: (y / mag) * normalized
    };
  }
}

interface GamepadState {
  leftStick: { x: number; y: number };
  rightStick: { x: number; y: number };
  buttons: Array<{ pressed: boolean; value: number }>;
}
```

### Standard Gamepad Mapping

```typescript
// Xbox/PlayStation button indices (Standard Gamepad)
enum GamepadButton {
  A = 0, // Cross
  B = 1, // Circle
  X = 2, // Square
  Y = 3, // Triangle
  LB = 4,
  RB = 5,
  LT = 6,
  RT = 7,
  Back = 8,
  Start = 9,
  LeftStick = 10,
  RightStick = 11,
  DPadUp = 12,
  DPadDown = 13,
  DPadLeft = 14,
  DPadRight = 15
}

// Usage
function handleGamepadInput(state: GamepadState) {
  // Movement from left stick
  const moveX = state.leftStick.x;
  const moveZ = state.leftStick.y;

  // Camera from right stick
  const lookX = state.rightStick.x;
  const lookY = state.rightStick.y;

  // Jump on A button
  if (state.buttons[GamepadButton.A].pressed) {
    jump();
  }

  // Run while holding LT
  const runMultiplier = 1 + state.buttons[GamepadButton.LT].value;
}
```

### Vibration/Haptics

```typescript
function vibrate(gamepad: Gamepad, duration: number, intensity: number) {
  if (!gamepad.vibrationActuator) return;

  gamepad.vibrationActuator.playEffect('dual-rumble', {
    duration,
    strongMagnitude: intensity,
    weakMagnitude: intensity * 0.5
  });
}

// Usage: vibrate on hit
vibrate(gamepad, 200, 0.8);
```

## 2D UI Overlays

### CSS2DRenderer

```typescript
import { CSS2DRenderer, CSS2DObject } from 'three/examples/jsm/renderers/CSS2DRenderer.js';

const labelRenderer = new CSS2DRenderer();
labelRenderer.setSize(window.innerWidth, window.innerHeight);
labelRenderer.domElement.style.position = 'absolute';
labelRenderer.domElement.style.top = '0';
labelRenderer.domElement.style.pointerEvents = 'none';
document.body.appendChild(labelRenderer.domElement);

// Create label
const div = document.createElement('div');
div.className = 'label';
div.textContent = 'Player';
const label = new CSS2DObject(div);
label.position.set(0, 2, 0);
playerMesh.add(label);

// In render loop
labelRenderer.render(scene, camera);
```

### Projecting 3D to 2D

```typescript
function worldToScreen(position: THREE.Vector3): { x: number; y: number } {
  const vector = position.clone().project(camera);
  return {
    x: (vector.x + 1) / 2 * window.innerWidth,
    y: -(vector.y - 1) / 2 * window.innerHeight
  };
}
```

## In-Scene UI

### CanvasTexture for Dynamic Text

```typescript
function createTextTexture(text: string, options: {
  fontSize?: number;
  fontFamily?: string;
  color?: string;
  backgroundColor?: string;
  padding?: number;
} = {}): THREE.CanvasTexture {
  const {
    fontSize = 64,
    fontFamily = 'Arial',
    color = '#ffffff',
    backgroundColor = 'transparent',
    padding = 20
  } = options;

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d')!;

  ctx.font = `${fontSize}px ${fontFamily}`;
  const metrics = ctx.measureText(text);

  canvas.width = Math.ceil(metrics.width + padding * 2);
  canvas.height = fontSize + padding * 2;

  // Background
  if (backgroundColor !== 'transparent') {
    ctx.fillStyle = backgroundColor;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }

  // Text
  ctx.font = `${fontSize}px ${fontFamily}`;
  ctx.fillStyle = color;
  ctx.textBaseline = 'top';
  ctx.fillText(text, padding, padding);

  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;
  return texture;
}

// Create a text sprite
function createTextSprite(text: string): THREE.Sprite {
  const texture = createTextTexture(text, { fontSize: 48, color: '#00ff00' });
  const material = new THREE.SpriteMaterial({ map: texture, transparent: true });
  const sprite = new THREE.Sprite(material);

  // Scale based on texture aspect ratio
  const aspect = texture.image.width / texture.image.height;
  sprite.scale.set(aspect * 0.5, 0.5, 1);

  return sprite;
}
```

### Updating CanvasTexture

```typescript
class DynamicLabel {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private texture: THREE.CanvasTexture;
  public mesh: THREE.Sprite;

  constructor(initialText: string) {
    this.canvas = document.createElement('canvas');
    this.canvas.width = 256;
    this.canvas.height = 64;
    this.ctx = this.canvas.getContext('2d')!;

    this.texture = new THREE.CanvasTexture(this.canvas);
    const material = new THREE.SpriteMaterial({ map: this.texture, transparent: true });
    this.mesh = new THREE.Sprite(material);

    this.setText(initialText);
  }

  setText(text: string) {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    this.ctx.roundRect(0, 0, this.canvas.width, this.canvas.height, 8);
    this.ctx.fill();

    this.ctx.fillStyle = '#ffffff';
    this.ctx.font = '24px Arial';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillText(text, this.canvas.width / 2, this.canvas.height / 2);

    this.texture.needsUpdate = true;
  }
}
```

### SDF Text Rendering

For crisp text at any scale, use SDF (Signed Distance Field):

```typescript
// Using troika-three-text (recommended library)
import { Text } from 'troika-three-text';

const textMesh = new Text();
textMesh.text = 'Hello World';
textMesh.fontSize = 0.5;
textMesh.color = 0xffffff;
textMesh.anchorX = 'center';
textMesh.anchorY = 'middle';

// Must sync after changing properties
textMesh.sync();

scene.add(textMesh);
```

### Billboard (Always Face Camera)

```typescript
class Billboard extends THREE.Mesh {
  update(camera: THREE.Camera) {
    // Copy camera rotation to always face viewer
    this.quaternion.copy(camera.quaternion);
  }
}

// Or use sprite (auto-billboards)
const sprite = new THREE.Sprite(material);
```

### World-Space Health Bar

```typescript
function createHealthBar(): THREE.Group {
  const group = new THREE.Group();

  // Background
  const bgGeo = new THREE.PlaneGeometry(1, 0.1);
  const bgMat = new THREE.MeshBasicMaterial({ color: 0x333333 });
  const bg = new THREE.Mesh(bgGeo, bgMat);
  group.add(bg);

  // Fill
  const fillGeo = new THREE.PlaneGeometry(1, 0.1);
  const fillMat = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
  const fill = new THREE.Mesh(fillGeo, fillMat);
  fill.position.z = 0.001; // Prevent z-fighting

  group.add(fill);
  group.userData.fill = fill;

  return group;
}

function updateHealthBar(bar: THREE.Group, health: number) {
  const fill = bar.userData.fill as THREE.Mesh;
  fill.scale.x = Math.max(0, Math.min(1, health));
  fill.position.x = (fill.scale.x - 1) / 2;

  // Color gradient: green → yellow → red
  const mat = fill.material as THREE.MeshBasicMaterial;
  if (health > 0.5) {
    mat.color.setHex(0x00ff00);
  } else if (health > 0.25) {
    mat.color.setHex(0xffff00);
  } else {
    mat.color.setHex(0xff0000);
  }
}
```

## Transform Controls

### Setup

```typescript
import { TransformControls } from 'three/examples/jsm/controls/TransformControls.js';

const transformControls = new TransformControls(camera, renderer.domElement);
scene.add(transformControls);

// Attach to selected object
transformControls.attach(selectedMesh);

// Mode switching
window.addEventListener('keydown', (e) => {
  switch (e.key) {
    case 'w': transformControls.setMode('translate'); break;
    case 'e': transformControls.setMode('rotate'); break;
    case 'r': transformControls.setMode('scale'); break;
  }
});

// Disable orbit controls while transforming
transformControls.addEventListener('dragging-changed', (event) => {
  orbitControls.enabled = !event.value;
});
```

### Snapping

```typescript
transformControls.setTranslationSnap(1);    // 1 unit grid
transformControls.setRotationSnap(Math.PI / 12); // 15 degrees
transformControls.setScaleSnap(0.1);        // 0.1 increments
```

### Selection System

```typescript
let selectedObject: THREE.Object3D | null = null;

function onClick(event: MouseEvent) {
  raycaster.setFromCamera(mouse, camera);
  const intersects = raycaster.intersectObjects(selectableObjects, true);

  if (intersects.length > 0) {
    selectedObject = intersects[0].object;
    transformControls.attach(selectedObject);
    outlinePass.selectedObjects = [selectedObject];
  } else {
    selectedObject = null;
    transformControls.detach();
    outlinePass.selectedObjects = [];
  }
}
```
