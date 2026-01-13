# State Management in R3F

## Table of Contents
- [State Categories](#state-categories)
- [Zustand Patterns](#zustand-patterns)
- [Event Handling](#event-handling)
- [External State Sync](#external-state-sync)

## State Categories

### Where State Should Live

| State Type | Location | Example |
|------------|----------|---------|
| Per-frame animation | Ref/useFrame | Rotation, position lerping |
| Transient interaction | Ref or store.getState() | Hover state, drag position |
| Shared 3D state | Zustand store | Selected object, camera target |
| UI-triggering state | React useState or Zustand | Score, menu open, modal |

**Rule of thumb**: If it changes >10fps, keep it out of React state.

## Zustand Patterns

### Basic Store

```tsx
import { create } from 'zustand'

interface Store {
  selectedId: string | null
  setSelected: (id: string | null) => void
  hoveredId: string | null
  setHovered: (id: string | null) => void
}

const useStore = create<Store>((set) => ({
  selectedId: null,
  setSelected: (id) => set({ selectedId: id }),
  hoveredId: null,
  setHovered: (id) => set({ hoveredId: id }),
}))
```

### Selective Subscriptions

```tsx
// BAD: Re-renders on any store change
const store = useStore()

// GOOD: Only re-renders when selectedId changes
const selectedId = useStore((s) => s.selectedId)

// GOOD: Multiple values with shallow comparison
import { shallow } from 'zustand/shallow'
const { selectedId, hoveredId } = useStore(
  (s) => ({ selectedId: s.selectedId, hoveredId: s.hoveredId }),
  shallow
)
```

### useFrame Access (No Subscription)

```tsx
useFrame(() => {
  // Get state without subscribing
  const { selectedId } = useStore.getState()

  // Direct mutation is fine here
  if (selectedId === myId) {
    meshRef.current.scale.setScalar(1.2)
  }
})
```

### Store with Actions

```tsx
const useStore = create((set, get) => ({
  objects: [],

  addObject: (obj) => set((state) => ({
    objects: [...state.objects, obj]
  })),

  removeObject: (id) => set((state) => ({
    objects: state.objects.filter(o => o.id !== id)
  })),

  // Computed/derived values
  getObjectById: (id) => get().objects.find(o => o.id === id),
}))
```

### Store with Middleware

```tsx
import { persist, devtools } from 'zustand/middleware'

const useStore = create(
  devtools(
    persist(
      (set) => ({
        quality: 'high',
        setQuality: (q) => set({ quality: q }),
      }),
      { name: 'app-storage' }
    )
  )
)
```

### Store Outside React

```tsx
// For external systems (physics, networking)
const unsubscribe = useStore.subscribe(
  (state) => state.selectedId,
  (selectedId) => {
    console.log('Selection changed:', selectedId)
  }
)

// Mutate from anywhere
useStore.setState({ selectedId: 'new-id' })

// Read from anywhere
const current = useStore.getState().selectedId
```

## Event Handling

### Pointer Events

```tsx
<mesh
  onPointerDown={(e) => {
    e.stopPropagation()  // Prevent parent handlers
    store.setSelected(id)
  }}
  onPointerOver={(e) => {
    document.body.style.cursor = 'pointer'
    // Direct mutation for instant feedback
    e.object.scale.setScalar(1.1)
  }}
  onPointerOut={(e) => {
    document.body.style.cursor = 'default'
    e.object.scale.setScalar(1)
  }}
/>
```

### Event Object Properties

```tsx
onPointerDown={(e) => {
  e.object      // The Three.js object that was hit
  e.point       // World position of intersection
  e.distance    // Distance from camera
  e.face        // Face that was hit
  e.faceIndex   // Index of face
  e.uv          // UV coordinates at intersection
  e.eventObject // Object that has the event handler
  e.delta       // Distance moved (for drag)
  e.ray         // The ray used for intersection
  e.camera      // Camera used
  e.stopPropagation()  // Stop event bubbling
  e.nativeEvent // Original DOM event
}}
```

### Event Bubbling

Events bubble up the JSX hierarchy:

```tsx
<group onClick={() => console.log('group clicked')}>
  <mesh onClick={(e) => {
    console.log('mesh clicked')
    e.stopPropagation()  // Without this, group also fires
  }}>
    ...
  </mesh>
</group>
```

### Raycast Performance

Only objects with event handlers are tested:

```tsx
// GOOD: Only interactive objects have handlers
<mesh onClick={handleClick}>...</mesh>
<mesh>...</mesh>  {/* Not raycasted */}

// BAD: Attaching to many objects
{items.map(item => (
  <mesh onPointerMove={...}>...</mesh>  // All raycasted every frame
))}
```

For complex meshes, use BVH:

```tsx
import { useBVH } from '@react-three/drei'

function ComplexMesh() {
  const { nodes } = useGLTF('/complex.glb')
  useBVH(nodes.HighPolyMesh)
  return <primitive object={nodes.HighPolyMesh} onClick={...} />
}
```

## External State Sync

### WebSocket/Network Updates

```tsx
// In a component or effect
useEffect(() => {
  const socket = new WebSocket('ws://...')

  socket.onmessage = (event) => {
    const data = JSON.parse(event.data)
    // Update store (not React state)
    useStore.setState({ players: data.players })
  }

  return () => socket.close()
}, [])

// In useFrame, smoothly interpolate to network state
useFrame(() => {
  const { players } = useStore.getState()
  players.forEach(player => {
    const mesh = playerMeshes.current[player.id]
    if (mesh) {
      mesh.position.lerp(player.position, 0.1)
    }
  })
})
```

### Multiplayer Pattern

```tsx
const useStore = create((set, get) => ({
  localPlayer: { position: [0, 0, 0], rotation: [0, 0, 0] },
  remotePlayers: {},

  updateLocalPlayer: (position, rotation) => {
    set({ localPlayer: { position, rotation } })
    // Send to server
    socket.send(JSON.stringify({ position, rotation }))
  },

  updateRemotePlayer: (id, data) => {
    set((state) => ({
      remotePlayers: { ...state.remotePlayers, [id]: data }
    }))
  },
}))
```

### Physics Integration

```tsx
// Physics updates store, React reads via subscription
const useStore = create((set) => ({
  physicsObjects: {},
  updatePhysicsObject: (id, position, rotation) => {
    set((state) => ({
      physicsObjects: {
        ...state.physicsObjects,
        [id]: { position, rotation }
      }
    }))
  }
}))

// In physics callback (runs every physics tick)
world.on('step', () => {
  bodies.forEach(body => {
    useStore.getState().updatePhysicsObject(
      body.id,
      body.position.toArray(),
      body.quaternion.toArray()
    )
  })
})
```

### URL/Router State

```tsx
// Sync camera position to URL
import { useSearchParams } from 'next/navigation'

function CameraController() {
  const [params, setParams] = useSearchParams()
  const { camera } = useThree()

  // On mount, restore from URL
  useEffect(() => {
    const x = parseFloat(params.get('cx') || '0')
    const y = parseFloat(params.get('cy') || '5')
    const z = parseFloat(params.get('cz') || '10')
    camera.position.set(x, y, z)
  }, [])

  // Debounced URL update
  const updateUrl = useMemo(() =>
    debounce((pos) => {
      setParams({
        cx: pos.x.toFixed(2),
        cy: pos.y.toFixed(2),
        cz: pos.z.toFixed(2),
      })
    }, 500),
    []
  )

  useFrame(() => {
    updateUrl(camera.position)
  })

  return <OrbitControls />
}
```
