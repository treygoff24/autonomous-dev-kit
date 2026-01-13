---
name: react-three-fiber
description: This skill should be used when the user asks to build Three.js scenes in React, use React Three Fiber/Drei, optimize R3F performance, integrate physics/animations/shaders, manage 3D assets in React, or mentions "R3F", "react-three-fiber", or "Drei".
---

# React Three Fiber (R3F) Advanced Workflow

Use this workflow to build production-grade R3F apps. Load the reference file that matches the task.

R3F is a React renderer for Three.js that enables declarative 3D scene building while preserving Three.js performance.

## Top 20 Power Moves

Essential patterns for complex R3F apps:

1. **On-Demand Rendering**: `<Canvas frameloop="demand">` + `invalidate()` for static scenes
2. **External Frame Loop**: Use `useFrame` for per-frame mutations, never `setState` at 60fps
3. **Stable Object References**: Memoize geometries/materials/vectors - never create in render
4. **Instancing**: Use `<Instances>` or `<Merged>` for repeated meshes (100k objects in one draw)
5. **Suspense Streaming**: Wrap loads in `<Suspense>`, layer low/high quality progressively
6. **Preloading**: Call `useGLTF.preload()` ahead of navigation
7. **Zustand State**: External store for shared state, `getState()` in `useFrame`
8. **Refs Over State**: Use refs for rapid changes, state only for UI-triggering updates
9. **Adaptive Quality**: `<PerformanceMonitor>` + `<AdaptiveDpr>` for device scaling
10. **LOD**: `<Detailed distances={[d1,d2]}>` for distance-based mesh swapping
11. **Environment Maps**: `<Environment preset="city">` for instant PBR lighting
12. **Physics**: `@react-three/rapier` with `<Physics>` + `<RigidBody>` wrappers
13. **Animation Springs**: `@react-spring/three` for physics-based interpolation
14. **shaderMaterial**: Custom GLSL with uniforms as React props via `extend()`
15. **Postprocessing**: `@react-three/postprocessing` for bloom/DOF/SSAO
16. **gltfjsx**: Generate typed React components from GLTF models
17. **Clone Pattern**: `<Clone object={scene}>` for model reuse without re-loading
18. **Event Bubbling**: `stopPropagation()` in nested click handlers
19. **BVH Raycasting**: `useBVH()` for complex mesh intersection performance
20. **SSR Avoidance**: `next/dynamic` with `ssr: false` for Canvas components

## Quick Start Pattern

```tsx
import { Canvas } from '@react-three/fiber'
import { OrbitControls, Environment, useGLTF } from '@react-three/drei'
import { Suspense } from 'react'

function Model({ url }) {
  const { scene } = useGLTF(url)
  return <primitive object={scene} />
}

export default function App() {
  return (
    <Canvas frameloop="demand" dpr={[1, 2]} shadows>
      <Suspense fallback={null}>
        <Model url="/model.glb" />
        <Environment preset="apartment" />
        <OrbitControls makeDefault />
      </Suspense>
    </Canvas>
  )
}
```

## Critical Anti-Patterns

**NEVER do these:**

```tsx
// BAD: Creates new objects every render (memory leak + shader recompile)
<mesh geometry={new BoxGeometry()} material={new MeshStandardMaterial()} />

// BAD: setState at 60fps causes React bottleneck
useFrame(() => setRotation(r => r + 0.01))

// BAD: New vector each frame causes GC spikes
useFrame(() => mesh.position.lerp(new Vector3(x,y,z), 0.1))
```

**DO this instead:**

```tsx
// GOOD: Memoize or define outside component
const geometry = useMemo(() => new BoxGeometry(), [])
const material = useMemo(() => new MeshStandardMaterial(), [])

// GOOD: Mutate ref directly in useFrame
const ref = useRef()
useFrame((_, delta) => { ref.current.rotation.y += delta })

// GOOD: Reuse temp vector
const tempVec = useMemo(() => new Vector3(), [])
useFrame(() => mesh.position.lerp(tempVec.set(x,y,z), 0.1))
```

## useFrame Patterns

The core animation hook - runs every frame outside React's render cycle:

```tsx
useFrame((state, delta) => {
  // state.clock.elapsedTime - total time
  // state.camera, state.scene, state.gl - Three objects
  // delta - time since last frame (use for framerate-independent animation)

  meshRef.current.rotation.y += delta * speed

  // For demand mode, call invalidate() when done animating
  if (animating) state.invalidate()
})
```

**Priority control**: `useFrame(callback, priority)` - lower runs first

## Drei Essentials

Key helpers from `@react-three/drei`:

| Component | Purpose |
|-----------|---------|
| `<OrbitControls makeDefault>` | Camera controls (auto-invalidates) |
| `<Environment preset="...">` | HDR environment maps |
| `<Html>` | DOM elements in 3D space |
| `<Text>` | SDF text rendering |
| `<View track={ref}>` | Embed 3D in DOM (scrollytelling, multi-view) |
| `<Instances>/<Instance>` | GPU instancing |
| `<Detailed distances={[]}>` | LOD switching |
| `<ContactShadows>` | Cheap dynamic soft shadows |
| `<AccumulativeShadows>` | High-quality static shadows (progressive) |
| `<Float>` | Gentle floating animation |
| `<PresentationControls>` | Drag-to-rotate for products |
| `<PivotControls>` | 3D gizmo for object manipulation |
| `<TransformControls>` | Translate/rotate/scale handles |
| `<GizmoHelper>` | Orientation cube overlay |
| `useGLTF` | Cached GLTF loading |
| `useTexture` | Cached texture loading |
| `useProgress` | Loading progress state |
| `useCursor` | Set cursor style based on hover state |
| `useIntersect` | Detect if mesh is in view |
| `<PerformanceMonitor>` | Auto quality adjustment |
| `<AdaptiveDpr>` | Dynamic pixel ratio |
| `<Preload all>` | Precompile all materials |
| `meshBounds` | Fast bounding-box raycasting |
| `<Stage>` | Quick lighting/environment setup |
| `<Bounds>` | Auto-fit camera to content |
| `<Sky>` / `<Stars>` / `<Cloud>` | Atmospheric effects |

## State Management

Use **Zustand** for R3F state - fast, minimal re-renders:

```tsx
import { create } from 'zustand'

const useStore = create((set, get) => ({
  selectedId: null,
  setSelected: (id) => set({ selectedId: id }),
  // For useFrame access without subscription:
  getSelected: () => get().selectedId,
}))

// In component - selective subscription
const selectedId = useStore(s => s.selectedId)

// In useFrame - no subscription, no re-render
useFrame(() => {
  const id = useStore.getState().selectedId
  // ... update based on id
})
```

**Rule**: If it updates >10fps, use ref/store.getState(). If it triggers UI, use React state.

## Asset Loading

```tsx
// Preload before render
useGLTF.preload('/model.glb')
useTexture.preload('/texture.jpg')

// Use with Suspense
function Model() {
  const { nodes, materials } = useGLTF('/model.glb')
  return <mesh geometry={nodes.Part.geometry} material={materials.Mat} />
}

// Progressive loading with nested Suspense
<Suspense fallback={<Loader />}>
  <Suspense fallback={<LowPolyModel />}>
    <HighPolyModel />
  </Suspense>
</Suspense>

// Generate typed component: npx gltfjsx model.glb --types
```

## Physics with Rapier

```tsx
import { Physics, RigidBody, CuboidCollider } from '@react-three/rapier'

<Physics gravity={[0, -9.81, 0]}>
  {/* Dynamic body */}
  <RigidBody>
    <mesh><boxGeometry /><meshStandardMaterial /></mesh>
  </RigidBody>

  {/* Static floor */}
  <RigidBody type="fixed">
    <CuboidCollider args={[10, 0.5, 10]} />
  </RigidBody>
</Physics>

// Apply forces via ref
const bodyRef = useRef()
const jump = () => bodyRef.current.applyImpulse({ x: 0, y: 5, z: 0 })
<RigidBody ref={bodyRef}>...</RigidBody>
```

## Custom Shaders

```tsx
import { shaderMaterial } from '@react-three/drei'
import { extend, useFrame } from '@react-three/fiber'

const WaveMaterial = shaderMaterial(
  { uTime: 0, uColor: new Color('#ff0000') },
  // vertex
  `varying vec2 vUv;
   void main() {
     vUv = uv;
     gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
   }`,
  // fragment
  `uniform float uTime;
   uniform vec3 uColor;
   varying vec2 vUv;
   void main() {
     gl_FragColor = vec4(uColor * sin(uTime + vUv.x * 10.0), 1.0);
   }`
)
extend({ WaveMaterial })

function WaveMesh() {
  const ref = useRef()
  useFrame((_, delta) => { ref.current.uTime += delta })
  return (
    <mesh>
      <planeGeometry args={[2, 2]} />
      <waveMaterial ref={ref} uColor="hotpink" transparent />
    </mesh>
  )
}
```

## Postprocessing

```tsx
import { EffectComposer, Bloom, DepthOfField } from '@react-three/postprocessing'

<Canvas>
  <Scene />
  <EffectComposer>
    <Bloom intensity={1.5} luminanceThreshold={0.4} />
    <DepthOfField focusDistance={0.01} focalLength={0.1} bokehScale={3} />
  </EffectComposer>
</Canvas>
```

## Performance Checklist

- [ ] `frameloop="demand"` for mostly-static scenes
- [ ] `<PerformanceMonitor>` with quality callbacks
- [ ] `<AdaptiveDpr>` or cap `dpr={[1, 1.5]}`
- [ ] Instance repeated meshes (`<Instances>`)
- [ ] LOD for distant objects (`<Detailed>`)
- [ ] Limit event handlers (raycast cost per handler)
- [ ] `useBVH()` for complex mesh raycasting
- [ ] Dispose unused assets (`useGLTF.clear()`)
- [ ] Profile with `<Perf>` from `r3f-perf`

## Detailed References

For in-depth coverage, see these reference files:

- **[architecture.md](references/architecture.md)** - R3F mental model, lifecycle, Canvas internals, View pattern
- **[performance.md](references/performance.md)** - Optimization strategies, profiling workflow
- **[state-management.md](references/state-management.md)** - Zustand patterns, event handling
- **[animation-physics.md](references/animation-physics.md)** - Springs, Rapier, skeletal animation
- **[shaders.md](references/shaders.md)** - ShaderMaterial, Drei materials, postprocessing
- **[assets.md](references/assets.md)** - GLTF loading, textures, streaming strategies
- **[testing-typescript.md](references/testing-typescript.md)** - Test renderer, mocking, TypeScript patterns
- **[anti-patterns.md](references/anti-patterns.md)** - Common mistakes with fixes
- **[production.md](references/production.md)** - SSR, code splitting, accessibility, mobile
