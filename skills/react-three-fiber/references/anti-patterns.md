# Common Mistakes & Anti-Patterns

## Table of Contents
- [Object Creation](#object-creation)
- [State Management](#state-management)
- [Event Handling](#event-handling)
- [Suspense & Loading](#suspense--loading)
- [Cleanup & Memory](#cleanup--memory)
- [Reconciler Conflicts](#reconciler-conflicts)

## Object Creation

### Creating Objects in Render

```tsx
// BAD: New geometry/material every render
function BadMesh() {
  return (
    <mesh
      geometry={new THREE.BoxGeometry()}
      material={new THREE.MeshStandardMaterial()}
    />
  )
}

// GOOD: Memoize or define outside
const geometry = new THREE.BoxGeometry()
const material = new THREE.MeshStandardMaterial()

function GoodMesh() {
  return <mesh geometry={geometry} material={material} />
}

// GOOD: useMemo for dynamic creation
function DynamicMesh({ size }) {
  const geometry = useMemo(() => new THREE.BoxGeometry(size, size, size), [size])
  return <mesh geometry={geometry} />
}
```

### Creating Vectors in useFrame

```tsx
// BAD: New Vector3 every frame = GC pressure
useFrame(() => {
  mesh.position.lerp(new THREE.Vector3(x, y, z), 0.1)
})

// GOOD: Reuse vector
const tempVec = useMemo(() => new THREE.Vector3(), [])

useFrame(() => {
  mesh.position.lerp(tempVec.set(x, y, z), 0.1)
})
```

### Creating Arrays in Props

```tsx
// BAD: New array reference every render
<mesh position={[x, y, z]} />

// GOOD: Stable reference
const position = useMemo(() => [x, y, z], [x, y, z])
<mesh position={position} />

// GOOD: Individual props (primitives compare by value)
<mesh position-x={x} position-y={y} position-z={z} />
```

## State Management

### Using setState in useFrame

```tsx
// BAD: 60 React renders per second
useFrame(() => {
  setRotation(r => r + 0.01)
})

// GOOD: Direct mutation via ref
const ref = useRef()
useFrame(() => {
  ref.current.rotation.y += 0.01
})
```

### Using useState for Transient State

```tsx
// BAD: Hover state causes re-renders
const [hovered, setHovered] = useState(false)
<mesh
  onPointerOver={() => setHovered(true)}
  onPointerOut={() => setHovered(false)}
  scale={hovered ? 1.2 : 1}
/>

// GOOD: Direct mutation for instant feedback
<mesh
  onPointerOver={(e) => {
    document.body.style.cursor = 'pointer'
    e.object.scale.setScalar(1.2)
  }}
  onPointerOut={(e) => {
    document.body.style.cursor = 'default'
    e.object.scale.setScalar(1)
  }}
/>

// GOOD: Zustand for shared state
const hovered = useStore(s => s.hoveredId === myId)
```

### Redux/Context in useFrame

```tsx
// BAD: useSelector causes re-render subscription
const value = useSelector(state => state.fastChangingValue)
useFrame(() => {
  mesh.position.x = value
})

// GOOD: Get state directly without subscription
useFrame(() => {
  const value = store.getState().fastChangingValue
  mesh.position.x = value
})

// GOOD: Zustand's getState()
useFrame(() => {
  const value = useStore.getState().fastChangingValue
  mesh.position.x = value
})
```

## Event Handling

### Missing stopPropagation

```tsx
// BAD: Both handlers fire on child click
<group onClick={() => deselectAll()}>
  <mesh onClick={() => selectThis()}>...</mesh>
</group>

// GOOD: Stop bubbling
<group onClick={() => deselectAll()}>
  <mesh onClick={(e) => {
    e.stopPropagation()
    selectThis()
  }}>...</mesh>
</group>
```

### Too Many Event Handlers

```tsx
// BAD: 1000 raycasts per frame on pointermove
{items.map(item => (
  <mesh
    key={item.id}
    onPointerMove={handleMove}  // Each gets raycasted
  />
))}

// GOOD: Single handler on parent
<group onPointerMove={(e) => {
  const hitObject = e.object
  handleMove(hitObject.userData.id)
}}>
  {items.map(item => (
    <mesh key={item.id} userData={{ id: item.id }} />
  ))}
</group>
```

### Event Handler in useEffect

```tsx
// BAD: Adding DOM events directly
useEffect(() => {
  window.addEventListener('click', handleClick)
  return () => window.removeEventListener('click', handleClick)
}, [])

// GOOD: Use R3F's event system or Canvas props
<Canvas onPointerMissed={handleClickBackground}>
  <mesh onClick={handleMeshClick} />
</Canvas>
```

## Suspense & Loading

### Missing Suspense

```tsx
// BAD: Throws unhandled promise
function Scene() {
  const model = useGLTF('/model.glb')  // Throws!
  return <primitive object={model.scene} />
}

// GOOD: Wrap in Suspense
<Suspense fallback={<Loader />}>
  <Scene />
</Suspense>
```

### Wrong Suspense Placement

```tsx
// BAD: Entire canvas blanks during load
<Suspense fallback={<div>Loading...</div>}>
  <Canvas>
    <Environment />
    <Model />  {/* Loading this blanks everything */}
  </Canvas>
</Suspense>

// GOOD: Suspense inside Canvas, scene stays visible
<Canvas>
  <Environment />
  <Suspense fallback={<LoadingSpinner />}>
    <Model />
  </Suspense>
</Canvas>
```

### Using Html in Suspense Fallback

```tsx
// BAD: Html requires Canvas context
<Suspense fallback={<Html>Loading...</Html>}>
  {/* Canvas might not be ready */}
</Suspense>

// GOOD: Use regular DOM for outer fallback
<Suspense fallback={<div className="loader">Loading...</div>}>
  <Canvas>
    <Suspense fallback={<Html center>Loading model...</Html>}>
      <Model />
    </Suspense>
  </Canvas>
</Suspense>
```

## Cleanup & Memory

### Not Disposing Custom Objects

```tsx
// BAD: RenderTarget leaks on unmount
function Effect() {
  const target = new THREE.WebGLRenderTarget(512, 512)
  // Never disposed!
}

// GOOD: Dispose in cleanup
function Effect() {
  const target = useMemo(() => new THREE.WebGLRenderTarget(512, 512), [])

  useEffect(() => {
    return () => target.dispose()
  }, [target])
}
```

### Forgetting Event Listener Cleanup

```tsx
// BAD: Listener persists after unmount
useEffect(() => {
  window.addEventListener('resize', handleResize)
}, [])

// GOOD: Clean up
useEffect(() => {
  window.addEventListener('resize', handleResize)
  return () => window.removeEventListener('resize', handleResize)
}, [])
```

### Leaking Subscriptions

```tsx
// BAD: Store subscription never cleaned up
useEffect(() => {
  useStore.subscribe(handleChange)
}, [])

// GOOD: Unsubscribe on unmount
useEffect(() => {
  const unsubscribe = useStore.subscribe(handleChange)
  return unsubscribe
}, [])
```

## Reconciler Conflicts

### Manual Scene Manipulation

```tsx
// BAD: Manually adding to scene
useEffect(() => {
  scene.add(myMesh)  // R3F doesn't know about this!
}, [])

// GOOD: Let R3F manage the scene graph
return <primitive object={myMesh} />
```

### Conflicting Props and Imperative

```tsx
// BAD: Both React and useFrame control position
<mesh ref={ref} position={[0, y, 0]}>  {/* React sets position */}
useFrame(() => {
  ref.current.position.y += 0.01  // useFrame also sets position
})

// GOOD: Choose one controller
// Option A: Only useFrame
<mesh ref={ref}>
useFrame(() => {
  ref.current.position.y += 0.01
})

// Option B: Only React
const [y, setY] = useState(0)
<mesh position={[0, y, 0]}>
// Update y via setState when needed
```

### Fighting OrbitControls

```tsx
// BAD: OrbitControls and manual camera updates
<OrbitControls />
useFrame(({ camera }) => {
  camera.position.set(x, y, z)  // Conflicts with OrbitControls!
})

// GOOD: Disable controls when manual control needed
const controlsRef = useRef()
useFrame(({ camera }) => {
  if (isManualMode) {
    controlsRef.current.enabled = false
    camera.position.set(x, y, z)
  } else {
    controlsRef.current.enabled = true
  }
})
<OrbitControls ref={controlsRef} />
```

### Excessive Mount/Unmount

```tsx
// BAD: Remounting Canvas (expensive WebGL context recreation)
{showCanvas ? <Canvas>...</Canvas> : null}

// GOOD: Keep Canvas, toggle contents
<Canvas>
  {showContent && <Scene />}
</Canvas>

// GOOD: Use visibility for temporary hide
<mesh visible={isVisible}>...</mesh>
```
