# Performance Optimization

## Table of Contents
- [Understanding the Render Cycle](#understanding-the-render-cycle)
- [React Optimizations](#react-optimizations)
- [Three.js Optimizations](#threejs-optimizations)
- [Frame Loop Control](#frame-loop-control)
- [Profiling Workflow](#profiling-workflow)

## Understanding the Render Cycle

Each frame (in `always` mode):
1. Run all `useFrame` callbacks
2. Render scene with WebGLRenderer
3. React reconciliation **only if state changed**

**Key insight**: Most frames involve zero React work.

### Where Performance Issues Come From

1. **React side**: Too many re-renders, expensive computations in render
2. **GPU side**: Too many draw calls, high resolution, complex shaders
3. **CPU side**: Heavy physics, too many raycast tests, GC pressure

## React Optimizations

### Preventing Unnecessary Re-renders

```tsx
// BAD: New array every render triggers update
<mesh position={[x, y, z]} />

// GOOD: Stable reference
const position = useMemo(() => [x, y, z], [x, y, z])
<mesh position={position} />

// GOOD: Primitives are fine (compared by value)
<mesh position-x={x} position-y={y} position-z={z} />
```

### React.memo for Static Components

```tsx
// Prevent re-render when parent changes
const StaticTree = memo(function Tree({ position }) {
  return (
    <group position={position}>
      {/* 1000 leaves that never need to update */}
    </group>
  )
})
```

### Isolate Dynamic Parts

```tsx
// BAD: Entire scene re-renders when score changes
function Game() {
  const [score, setScore] = useState(0)
  return (
    <>
      <ScoreDisplay score={score} />
      <Player />
      <Environment />  {/* Re-renders unnecessarily */}
    </>
  )
}

// GOOD: Score isolated in its own component
function Game() {
  return (
    <>
      <ScoreTracker />  {/* Has its own useState */}
      <Player />
      <Environment />  {/* Never re-renders */}
    </>
  )
}
```

## Three.js Optimizations

### Draw Call Reduction

**Target**: <100 draw calls for smooth performance

```tsx
// BAD: 100 draw calls
{items.map(item => (
  <mesh key={item.id}>
    <boxGeometry />
    <meshStandardMaterial />
  </mesh>
))}

// GOOD: 1 draw call
<Instances limit={100}>
  <boxGeometry />
  <meshStandardMaterial />
  {items.map(item => (
    <Instance key={item.id} position={item.position} />
  ))}
</Instances>
```

### Geometry Merging

For static objects that share material:

```tsx
import { mergeBufferGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils'

const mergedGeometry = useMemo(() => {
  const geometries = positions.map(pos => {
    const geo = new BoxGeometry()
    geo.translate(...pos)
    return geo
  })
  return mergeBufferGeometries(geometries)
}, [positions])

<mesh geometry={mergedGeometry}>
  <meshStandardMaterial />
</mesh>
```

### Level of Detail (LOD)

```tsx
import { Detailed } from '@react-three/drei'

<Detailed distances={[0, 20, 50]}>
  <HighPolyModel />   {/* < 20 units away */}
  <MediumPolyModel /> {/* 20-50 units */}
  <LowPolyModel />    {/* > 50 units */}
</Detailed>
```

### Frustum Culling

Automatic in Three.js - objects outside camera view aren't rendered. Ensure:
- `mesh.frustumCulled = true` (default)
- Bounding boxes are correct for custom geometries

### Raycast Optimization with meshBounds

For interactive meshes, use `meshBounds` to replace expensive triangle intersection tests with fast bounding box checks:

```tsx
import { meshBounds } from '@react-three/drei'

function ClickableObject() {
  return (
    <mesh
      raycast={meshBounds}  // Use bounding box instead of triangle intersection
      onClick={handleClick}
    >
      <complexGeometry />
      <meshStandardMaterial />
    </mesh>
  )
}
```

Use when:
- Complex meshes with many triangles
- Precise hit location isn't needed
- Performance matters more than accuracy

For even more control, use raycaster layers:

```tsx
// Set up layers
const CLICKABLE_LAYER = 1

function Scene() {
  const { raycaster } = useThree()

  useEffect(() => {
    raycaster.layers.set(CLICKABLE_LAYER)  // Only check this layer
  }, [raycaster])

  return (
    <>
      {/* This mesh will be checked */}
      <mesh layers={CLICKABLE_LAYER} onClick={...}>...</mesh>

      {/* This mesh won't be checked (different layer) */}
      <mesh layers={2}>...</mesh>
    </>
  )
}
```

### Material Optimization

```tsx
// Reuse materials across meshes
const sharedMaterial = useMemo(() => new MeshStandardMaterial({ color: 'red' }), [])

{items.map(item => (
  <mesh key={item.id} material={sharedMaterial}>
    <boxGeometry />
  </mesh>
))}

// Simpler materials for distant/unimportant objects
<mesh>
  <meshBasicMaterial />  {/* No lighting calculations */}
</mesh>
```

## Frame Loop Control

### Demand Mode

Zero GPU cost when nothing changes:

```tsx
<Canvas frameloop="demand">
  <OrbitControls makeDefault />  {/* Auto-invalidates on change */}
  <StaticScene />
</Canvas>
```

### Manual Invalidation

```tsx
const { invalidate } = useThree()

// After external state change
useEffect(() => {
  socket.on('update', (data) => {
    updateStore(data)
    invalidate()  // Request re-render
  })
}, [invalidate])

// In animation (continuous)
useFrame((state) => {
  if (isAnimating) {
    mesh.rotation.y += 0.01
    state.invalidate()  // Keep rendering
  }
})
```

### Adaptive Performance

```tsx
import { PerformanceMonitor, AdaptiveDpr } from '@react-three/drei'

<Canvas>
  <PerformanceMonitor
    onIncline={() => setQuality('high')}
    onDecline={() => setQuality('low')}
    flipflops={3}  // Stop after 3 quality changes
  >
    <AdaptiveDpr pixelated />
  </PerformanceMonitor>
  <Scene quality={quality} />
</Canvas>

// In Scene, conditionally disable effects:
{quality === 'high' && <ExpensiveEffects />}
```

### Manual Performance Regression

Use `state.performance.regress()` to signal that performance needs adjustment (e.g., during heavy interactions):

```tsx
function HeavyInteraction() {
  const regress = useThree((state) => state.performance.regress)

  const onPointerMove = () => {
    // Signal that we're doing heavy work
    regress()
  }

  return <mesh onPointerMove={onPointerMove}>...</mesh>
}

// Or access via useFrame
useFrame((state) => {
  if (isDoingHeavyWork) {
    state.performance.regress()
  }
})
```

The `performance` object from `useThree` includes:
- `current`: Current performance factor (0-1)
- `min`: Minimum allowed (from Canvas `performance.min`)
- `max`: Maximum allowed (from Canvas `performance.max`)
- `debounce`: Debounce time for changes
- `regress()`: Signal performance pressure

## Profiling Workflow

### 1. Measure Baseline

```tsx
import { Perf } from 'r3f-perf'

<Canvas>
  <Perf position="top-left" />
  <Scene />
</Canvas>
```

Shows: FPS, CPU/GPU time, memory, draw calls, triangles

### 2. React Profiler

Open React DevTools Profiler:
- Record while interacting
- Look for components re-rendering every frame
- Check "Highlight updates" to see re-renders

### 3. Chrome Performance Tab

Record 2-5 seconds:
- **Scripting**: JS execution time
- **Rendering**: DOM/layout work
- **GPU**: WebGL operations

### 4. Three.js Stats

```tsx
useFrame(({ gl }) => {
  console.log(gl.info.render)
  // { calls: 45, triangles: 120000, points: 0, lines: 0 }
})
```

### Quick Diagnostic Tests

**Test 1: Is it React?**
- Disable all `useState` updates → FPS improves? React bottleneck.

**Test 2: Is it GPU fragment-bound?**
- Use `<meshBasicMaterial />` everywhere → FPS improves? Shader/fill-rate issue.
- Lower `dpr` → FPS improves? Resolution issue.

**Test 3: Is it draw calls?**
- Check `gl.info.render.calls`
- Instance or merge if >100

**Test 4: Is it geometry?**
- Check triangle count
- Use LOD or simplify models if >1-2M triangles

### Common Fixes Summary

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| FPS drops on hover | setState in pointer events | Use refs |
| Constant 30fps | Too many draw calls | Instance/merge |
| Stutters on load | Shader compilation | Preload materials |
| Memory climbing | Objects not disposed | Check dispose calls |
| Mobile lag | High DPR | Cap at 1.5 or use AdaptiveDpr |
