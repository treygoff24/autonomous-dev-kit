# Asset Loading & Management

## Table of Contents
- [GLTF Loading](#gltf-loading)
- [Texture Loading](#texture-loading)
- [Preloading Strategies](#preloading-strategies)
- [Compression](#compression)
- [Memory Management](#memory-management)

## GLTF Loading

### Basic useGLTF

```tsx
import { useGLTF } from '@react-three/drei'

function Model() {
  const { scene, nodes, materials, animations } = useGLTF('/model.glb')

  // scene: Full scene graph
  // nodes: Object with each mesh by name
  // materials: Object with each material by name
  // animations: Array of AnimationClips

  return <primitive object={scene} />
}

// Preload (call at module level)
useGLTF.preload('/model.glb')
```

### Accessing Parts

```tsx
function Model() {
  const { nodes, materials } = useGLTF('/robot.glb')

  return (
    <group>
      {/* Use specific parts */}
      <mesh geometry={nodes.Head.geometry} material={materials.Metal} />
      <mesh geometry={nodes.Body.geometry} material={materials.Plastic} />

      {/* Override material */}
      <mesh geometry={nodes.Arm.geometry}>
        <meshStandardMaterial color="red" />
      </mesh>
    </group>
  )
}
```

### gltfjsx Code Generation

```bash
npx gltfjsx model.glb --types --transform
```

Generates typed React component:

```tsx
// Auto-generated Model.tsx
import { useGLTF } from '@react-three/drei'
import { GLTF } from 'three-stdlib'

type GLTFResult = GLTF & {
  nodes: {
    Cube: THREE.Mesh
    Sphere: THREE.Mesh
  }
  materials: {
    Material: THREE.MeshStandardMaterial
  }
}

export function Model(props: JSX.IntrinsicElements['group']) {
  const { nodes, materials } = useGLTF('/model.glb') as GLTFResult
  return (
    <group {...props} dispose={null}>
      <mesh geometry={nodes.Cube.geometry} material={materials.Material} />
      <mesh geometry={nodes.Sphere.geometry} material={materials.Material} />
    </group>
  )
}

useGLTF.preload('/model.glb')
```

### Cloning Models

```tsx
import { Clone, useGLTF } from '@react-three/drei'

function Forest() {
  const { scene } = useGLTF('/tree.glb')

  return (
    <>
      {/* Each Clone is a deep copy */}
      <Clone object={scene} position={[0, 0, 0]} />
      <Clone object={scene} position={[5, 0, 0]} />
      <Clone object={scene} position={[10, 0, 0]} />
    </>
  )
}

// Manual cloning
const clonedScene = useMemo(() => scene.clone(true), [scene])
```

### Instancing GLTF Parts

```bash
npx gltfjsx model.glb --instance
```

Or manually:

```tsx
import { Instances, Instance, useGLTF } from '@react-three/drei'

function InstancedTrees() {
  const { nodes, materials } = useGLTF('/tree.glb')

  return (
    <Instances geometry={nodes.Tree.geometry} material={materials.Bark}>
      {positions.map((pos, i) => (
        <Instance key={i} position={pos} rotation={[0, Math.random() * Math.PI, 0]} />
      ))}
    </Instances>
  )
}
```

## Texture Loading

### useTexture

```tsx
import { useTexture } from '@react-three/drei'

function TexturedMesh() {
  // Single texture
  const colorMap = useTexture('/color.jpg')

  // Multiple textures
  const [colorMap, normalMap, roughnessMap] = useTexture([
    '/color.jpg',
    '/normal.jpg',
    '/roughness.jpg'
  ])

  // Object syntax
  const { map, normalMap, roughnessMap } = useTexture({
    map: '/color.jpg',
    normalMap: '/normal.jpg',
    roughnessMap: '/roughness.jpg'
  })

  return (
    <mesh>
      <boxGeometry />
      <meshStandardMaterial
        map={colorMap}
        normalMap={normalMap}
        roughnessMap={roughnessMap}
      />
    </mesh>
  )
}

useTexture.preload('/color.jpg')
```

### Texture Settings

```tsx
const texture = useTexture('/texture.jpg')

// In useEffect or useMemo
texture.wrapS = texture.wrapT = THREE.RepeatWrapping
texture.repeat.set(4, 4)
texture.anisotropy = 16  // Improves quality at angles

// For color maps (diffuse, emissive) - use colorSpace (not deprecated encoding)
texture.colorSpace = THREE.SRGBColorSpace

// For data maps (normal, roughness, metalness) - use linear
// normalMap.colorSpace = THREE.LinearSRGBColorSpace  // default, usually not needed
```

**Note**: `texture.encoding` is deprecated in Three.js r152+. Use `texture.colorSpace` instead.

### Environment Maps

```tsx
import { Environment, useEnvironment } from '@react-three/drei'

// Preset
<Environment preset="sunset" background />

// Custom HDR
<Environment files="/hdr/studio.hdr" background />

// Ground projection (reflections on floor)
<Environment ground={{ height: 32, radius: 130 }} />

// Access env map in component
function ReflectiveSphere() {
  const envMap = useEnvironment({ preset: 'city' })
  return (
    <mesh>
      <sphereGeometry />
      <meshStandardMaterial envMap={envMap} metalness={1} roughness={0} />
    </mesh>
  )
}
```

## Preloading Strategies

### Precompile Materials with `<Preload>`

Avoid first-frame shader jank by precompiling all materials:

```tsx
import { Preload } from '@react-three/drei'

<Canvas>
  <Suspense fallback={null}>
    <Scene />
    {/* Precompile all materials in the scene */}
    <Preload all />
  </Suspense>
</Canvas>
```

This renders all materials once (invisibly) to trigger shader compilation before the scene is displayed.

### Module-Level Preload

```tsx
// At top of file - starts loading immediately
useGLTF.preload('/hero-model.glb')
useTexture.preload('/hero-texture.jpg')

function HeroSection() {
  // Will be cached by the time component mounts
  const { scene } = useGLTF('/hero-model.glb')
  return <primitive object={scene} />
}
```

### Preload on Hover

```tsx
function NavLink({ href, modelPath, children }) {
  return (
    <Link
      href={href}
      onMouseEnter={() => {
        useGLTF.preload(modelPath)
      }}
    >
      {children}
    </Link>
  )
}
```

### Progressive Loading

```tsx
function ProgressiveModel() {
  return (
    <Suspense fallback={<LowPolyPlaceholder />}>
      <Suspense fallback={<MediumPolyModel />}>
        <HighPolyModel />
      </Suspense>
    </Suspense>
  )
}
```

### Loading Progress

```tsx
import { useProgress, Html } from '@react-three/drei'

function Loader() {
  const { progress, loaded, total } = useProgress()

  return (
    <Html center>
      <div className="loader">
        {progress.toFixed(0)}% loaded
        <br />
        ({loaded} / {total} items)
      </div>
    </Html>
  )
}

// Usage
<Canvas>
  <Suspense fallback={<Loader />}>
    <Scene />
  </Suspense>
</Canvas>
```

## Compression

### Draco Compression

```tsx
// Configure Draco decoder path
useGLTF.preload('/model.glb', '/draco/')

// Or in component
const { scene } = useGLTF('/model.glb', '/draco/')
```

Draco compresses geometry 80-95% but adds decode time.

### Meshopt Compression

Generally faster to decode than Draco:

```tsx
import { MeshoptDecoder } from 'three/examples/jsm/libs/meshopt_decoder.module.js'

// Set decoder globally
THREE.GLTFLoader.prototype.setMeshoptDecoder(MeshoptDecoder)
```

### KTX2/Basis Textures

GPU-compressed textures for faster loading and less memory:

```tsx
import { useKTX2 } from '@react-three/drei'

function Model() {
  const texture = useKTX2('/texture.ktx2')
  return (
    <mesh>
      <boxGeometry />
      <meshStandardMaterial map={texture} />
    </mesh>
  )
}
```

## Memory Management

### Disposing Assets

```tsx
// Manual dispose when done
useEffect(() => {
  return () => {
    texture.dispose()
    geometry.dispose()
    material.dispose()
  }
}, [])

// Clear useGLTF cache
useGLTF.clear('/model.glb')

// Prevent auto-dispose (for reuse)
<group dispose={null}>
  <primitive object={scene} />
</group>
```

### Monitoring Memory

```tsx
useFrame(({ gl }) => {
  console.log('Memory:', gl.info.memory)
  // { geometries: 45, textures: 12 }

  console.log('Render:', gl.info.render)
  // { calls: 78, triangles: 250000, points: 0, lines: 0 }
})
```

### LOD for Memory

```tsx
import { Detailed, useGLTF } from '@react-three/drei'

function LODModel() {
  const high = useGLTF('/model-high.glb')
  const medium = useGLTF('/model-medium.glb')
  const low = useGLTF('/model-low.glb')

  return (
    <Detailed distances={[0, 20, 50]}>
      <primitive object={high.scene} />
      <primitive object={medium.scene} />
      <primitive object={low.scene} />
    </Detailed>
  )
}
```

### Streaming Large Scenes

```tsx
// Load chunks based on player position
function StreamingWorld() {
  const [loadedChunks, setLoadedChunks] = useState(new Set(['0,0']))
  const playerPos = useStore(s => s.playerPosition)

  useEffect(() => {
    const chunkX = Math.floor(playerPos.x / CHUNK_SIZE)
    const chunkZ = Math.floor(playerPos.z / CHUNK_SIZE)

    // Load nearby chunks
    for (let dx = -1; dx <= 1; dx++) {
      for (let dz = -1; dz <= 1; dz++) {
        const key = `${chunkX + dx},${chunkZ + dz}`
        if (!loadedChunks.has(key)) {
          useGLTF.preload(`/chunks/${key}.glb`)
          setLoadedChunks(prev => new Set([...prev, key]))
        }
      }
    }

    // Unload distant chunks
    loadedChunks.forEach(key => {
      const [cx, cz] = key.split(',').map(Number)
      if (Math.abs(cx - chunkX) > 2 || Math.abs(cz - chunkZ) > 2) {
        useGLTF.clear(`/chunks/${key}.glb`)
        setLoadedChunks(prev => {
          const next = new Set(prev)
          next.delete(key)
          return next
        })
      }
    })
  }, [playerPos])

  return (
    <>
      {[...loadedChunks].map(key => (
        <Suspense key={key} fallback={null}>
          <Chunk id={key} />
        </Suspense>
      ))}
    </>
  )
}
```
