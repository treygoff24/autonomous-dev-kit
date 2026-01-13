# R3F Architecture & Mental Model

## Table of Contents
- [The React-Three Bridge](#the-react-three-bridge)
- [Canvas Internals](#canvas-internals)
- [Lifecycle Differences](#lifecycle-differences)
- [useFrame Priority](#useframe-priority)
- [The Reconciler](#the-reconciler)
- [Ref Patterns](#ref-patterns)
- [View Pattern (tunnel-rat)](#view-pattern-tunnel-rat)

## The React-Three Bridge

R3F maps JSX to Three.js objects:

```tsx
// JSX
<mesh position={[0, 1, 0]}>
  <boxGeometry args={[1, 1, 1]} />
  <meshStandardMaterial color="red" />
</mesh>

// Creates Three.js equivalent:
const mesh = new THREE.Mesh()
mesh.position.set(0, 1, 0)
mesh.geometry = new THREE.BoxGeometry(1, 1, 1)
mesh.material = new THREE.MeshStandardMaterial({ color: 'red' })
scene.add(mesh)
```

**Key insight**: JSX is a declaration of what should exist. R3F translates props to Three.js constructor args and property setters.

### Prop Translation Rules

| JSX Prop | Three.js Equivalent |
|----------|---------------------|
| `args={[...]}` | Constructor arguments |
| `position={[x,y,z]}` | `object.position.set(x,y,z)` |
| `rotation-x={Math.PI}` | `object.rotation.x = Math.PI` |
| `scale={2}` | `object.scale.setScalar(2)` |
| `castShadow` | `object.castShadow = true` |
| `attach="material"` | Parent attachment point |

### The `attach` Prop

Controls where child attaches to parent:

```tsx
<mesh>
  <boxGeometry attach="geometry" />          {/* mesh.geometry = this */}
  <meshStandardMaterial attach="material" /> {/* mesh.material = this */}
</mesh>

// For arrays (multi-material):
<mesh>
  <meshStandardMaterial attach="material-0" />
  <meshStandardMaterial attach="material-1" />
</mesh>
```

### The `primitive` Component

Use existing Three.js objects in JSX:

```tsx
const geometry = new THREE.TorusKnotGeometry()
const material = new THREE.MeshPhysicalMaterial()

<primitive object={geometry} attach="geometry" />
<primitive object={mesh} position={[1, 0, 0]} />
```

## Canvas Internals

The `<Canvas>` component:
1. Creates a WebGLRenderer, Scene, Camera
2. Sets up the render loop
3. Provides context via `useThree()`
4. Manages resize handling
5. Handles pointer events → raycasting

### Canvas Props

```tsx
<Canvas
  // Rendering
  frameloop="always" | "demand" | "never"
  dpr={[1, 2]}  // Device pixel ratio bounds
  gl={{ antialias: true, alpha: false }}  // WebGLRenderer options
  shadows  // Enable shadow maps

  // Camera
  camera={{ position: [0, 0, 5], fov: 75 }}
  orthographic  // Use OrthographicCamera

  // Events
  events={...}  // Custom event system
  eventSource={domElement}  // Event target
  eventPrefix="offset" | "client" | "page"

  // Performance
  performance={{ min: 0.5, max: 1, debounce: 200 }}

  // Lifecycle
  onCreated={(state) => {}}
  onPointerMissed={() => {}}
/>
```

### useThree Hook

Access R3F state anywhere in the tree:

```tsx
const {
  gl,           // WebGLRenderer
  scene,        // Scene
  camera,       // Active camera
  raycaster,    // Raycaster instance
  pointer,      // Normalized pointer position
  clock,        // THREE.Clock
  size,         // { width, height } of canvas
  viewport,     // { width, height, factor } in world units
  set,          // Mutate state
  get,          // Get state snapshot
  invalidate,   // Request frame (demand mode)
  advance,      // Force single frame (never mode)
  setSize,      // Resize canvas
  setDpr,       // Set pixel ratio
  setFrameloop, // Change frameloop mode
  events,       // Event handlers
  xr,           // WebXR manager
} = useThree()

// Selective subscription (prevents re-render on other changes)
const camera = useThree(state => state.camera)
```

## Lifecycle Differences

### React vs R3F

| React | R3F Equivalent |
|-------|----------------|
| `useEffect` | One-time setup, cleanup |
| `useLayoutEffect` | Before first paint |
| `useState` | UI-triggering state only |
| N/A | `useFrame` (every frame) |

### useFrame vs useEffect

```tsx
// useEffect: Runs once (or when deps change)
useEffect(() => {
  console.log('Component mounted')
  return () => console.log('Unmounted')
}, [])

// useFrame: Runs every frame (60+ times/sec)
useFrame((state, delta) => {
  meshRef.current.rotation.y += delta
})
```

**Critical rule**: Never use `useEffect` for per-frame updates. Never use `useFrame` for one-time setup.

### Frame Execution Order

1. All `useFrame` callbacks (in priority order)
2. Three.js render pass
3. React reconciliation only if state changed

This means most frames have **zero** React overhead.

## useFrame Priority

`useFrame(callback, priority)` - the second argument controls execution order.

### Priority Rules

- **Lower numbers run first** (priority -2 runs before -1, 0 runs before 1)
- **Default priority is 0**
- **Positive priorities (1+) take over the render loop** - you must call `gl.render()` manually
- **Negative and zero priorities** run before the automatic render pass

**Important**: If you use a positive priority, R3F won't auto-render - you're responsible for calling `state.gl.render(state.scene, state.camera)`. Use this for custom render passes or post-processing.

### Common Priority Patterns

```tsx
// Physics sync (runs first)
useFrame(() => {
  playerRef.current.position.copy(physicsBody.position)
}, -2)

// Camera follow (runs after physics)
useFrame(({ camera }) => {
  camera.position.lerp(playerRef.current.position, 0.1)
}, -1)

// Default (most animations) - runs right before render
useFrame(() => {
  meshRef.current.rotation.y += 0.01
}, 0)
```

### When to Use Positive Priority (Custom Render Pass)

```tsx
// Priority 1+: Takes over rendering - you MUST call gl.render()
useFrame(({ gl, scene, camera }) => {
  // Custom multi-pass rendering
  gl.setRenderTarget(renderTarget)
  gl.render(scene, camera)
  gl.setRenderTarget(null)
  gl.render(scene, camera)  // Final pass to screen
}, 1)
```

### Priority Example: Follow Camera

```tsx
function Player() {
  const ref = useRef()
  // Priority -1: Player moves first
  useFrame((_, delta) => {
    ref.current.position.x += velocity * delta
  }, -1)
  return <mesh ref={ref}>...</mesh>
}

function FollowCamera({ target }) {
  // Priority 0: Camera follows after player moved (still before auto-render)
  useFrame(({ camera }) => {
    camera.position.lerp(
      target.current.position.clone().add(new Vector3(0, 5, 10)),
      0.1
    )
    camera.lookAt(target.current.position)
  }, 0)
  return null
}
```

## The Reconciler

R3F uses a custom React reconciler (like react-dom, react-native).

### What the Reconciler Does

1. Creates Three.js objects from JSX elements
2. Updates properties when props change
3. Manages parent-child relationships
4. Handles mounting/unmounting
5. Disposes resources on unmount

### Prop Diffing

R3F compares props to avoid unnecessary updates:

```tsx
// These are equivalent (no update on re-render):
<mesh position={[0, 1, 0]} />
<mesh position={[0, 1, 0]} />

// This triggers update (new array reference):
const pos = [0, 1, 0]  // Created fresh each render
<mesh position={pos} />

// Fix: memoize or use stable reference
const pos = useMemo(() => [0, 1, 0], [])
```

### Extending the Reconciler

Add custom Three.js classes to JSX:

```tsx
import { extend } from '@react-three/fiber'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls'

extend({ OrbitControls })

// Now usable as JSX (lowercase):
<orbitControls args={[camera, domElement]} />
```

## Ref Patterns

### Basic Ref

```tsx
const meshRef = useRef<THREE.Mesh>(null!)

useFrame(() => {
  meshRef.current.rotation.y += 0.01
})

return <mesh ref={meshRef}>...</mesh>
```

### Multiple Refs with useRef Array

```tsx
const refs = useRef<THREE.Mesh[]>([])

return items.map((item, i) => (
  <mesh
    key={item.id}
    ref={el => { if (el) refs.current[i] = el }}
  />
))
```

### Forwarding Refs

```tsx
const Box = forwardRef<THREE.Mesh, BoxProps>((props, ref) => (
  <mesh ref={ref} {...props}>
    <boxGeometry />
    <meshStandardMaterial />
  </mesh>
))

// Parent can now access the mesh:
const boxRef = useRef<THREE.Mesh>(null!)
<Box ref={boxRef} position={[1, 0, 0]} />
```

### Imperative Handle

Expose custom API from child:

```tsx
const Box = forwardRef((props, ref) => {
  const meshRef = useRef()

  useImperativeHandle(ref, () => ({
    spin: () => { meshRef.current.rotation.y += Math.PI },
    getMesh: () => meshRef.current,
  }))

  return <mesh ref={meshRef}>...</mesh>
})

// Parent:
const boxApi = useRef()
<Box ref={boxApi} />
boxApi.current.spin()
```

### Callback Refs for Immediate Access

```tsx
const [mesh, setMesh] = useState<THREE.Mesh | null>(null)

useEffect(() => {
  if (mesh) {
    // Mesh is available immediately after mount
    console.log(mesh.geometry.boundingBox)
  }
}, [mesh])

return <mesh ref={setMesh}>...</mesh>
```

## View Pattern (tunnel-rat)

The `<View>` component (powered by `tunnel-rat`) solves the "multiple Canvas" problem for embedding 3D content in scrollable DOM layouts.

### The Problem

Creating multiple `<Canvas>` elements for each 3D widget is expensive:
- Each Canvas = separate WebGL context
- Browser limits contexts (~8-16)
- No shared resources between contexts
- Heavy memory overhead

### The Solution: Single Canvas with Views

```tsx
import { Canvas } from '@react-three/fiber'
import { View } from '@react-three/drei'

function App() {
  const container1 = useRef()
  const container2 = useRef()

  return (
    <div className="scroll-container">
      {/* DOM content with embedded 3D "slots" */}
      <section>
        <h1>Product A</h1>
        <div ref={container1} className="w-full h-64" />
      </section>

      <section>
        <h1>Product B</h1>
        <div ref={container2} className="w-full h-64" />
      </section>

      {/* Single Canvas renders into multiple views */}
      <Canvas
        style={{ position: 'fixed', top: 0, left: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
      >
        <View track={container1}>
          <ProductAScene />
          <OrbitControls />
        </View>

        <View track={container2}>
          <ProductBScene />
          <OrbitControls />
        </View>
      </Canvas>
    </div>
  )
}
```

### How It Works

1. Single Canvas covers the viewport (fixed position, behind DOM)
2. Each `<View>` uses scissor/viewport to render into a specific DOM element
3. `track={ref}` follows the DOM element's position and size
4. Result: appears as multiple separate 3D views, but it's one Canvas

### Use Cases

- **Scrollytelling**: 3D scenes that appear as you scroll through content
- **E-commerce**: Multiple product viewers on one page
- **Dashboards**: 3D widgets scattered throughout DOM layout
- **Portfolio sites**: 3D elements mixed with text/images

### Performance Benefits

- Single WebGL context shared across all views
- Shared textures, geometries, materials
- No context switching overhead
- Efficient batch rendering

### View Props

```tsx
<View
  track={domRef}           // DOM element to render into
  index={0}                // Render order (lower = first)
  frames={1}               // Render every N frames (1 = always)
  children                 // Scene contents for this view
>
  <mesh>...</mesh>
  <OrbitControls />
</View>
```

### With Next.js/React Router

```tsx
// Layout component with persistent Canvas
function Layout({ children }) {
  return (
    <>
      {children}
      <Canvas style={{ position: 'fixed', inset: 0, pointerEvents: 'none' }}>
        {/* Views are rendered here from anywhere in the tree */}
      </Canvas>
    </>
  )
}

// Page component
function ProductPage() {
  const viewRef = useRef()
  return (
    <div>
      <h1>Product</h1>
      <div ref={viewRef} className="aspect-square" />
      <View track={viewRef}>
        <ProductModel />
      </View>
    </div>
  )
}
```
