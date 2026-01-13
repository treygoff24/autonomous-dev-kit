# Testing & TypeScript Patterns

## Table of Contents
- [React Three Test Renderer](#react-three-test-renderer)
- [Testing Patterns](#testing-patterns)
- [Mocking Assets](#mocking-assets)
- [TypeScript Best Practices](#typescript-best-practices)
- [Storybook Integration](#storybook-integration)

## React Three Test Renderer

The `@react-three/test-renderer` creates a headless WebGL context for testing R3F components without a browser.

### Basic Setup

```tsx
import ReactThreeTestRenderer from '@react-three/test-renderer'

test('mesh exists in scene', async () => {
  const renderer = await ReactThreeTestRenderer.create(
    <mesh>
      <boxGeometry />
      <meshStandardMaterial />
    </mesh>
  )

  // Access scene
  const mesh = renderer.scene.children[0]
  expect(mesh.type).toBe('Mesh')

  // allChildren includes geometry and material (auto-attached)
  expect(mesh.allChildren.length).toBe(2)
})
```

### Testing Scene Structure

```tsx
test('model has expected structure', async () => {
  const renderer = await ReactThreeTestRenderer.create(<MyModel />)

  // Traverse scene
  const meshes = renderer.scene.children.filter(c => c.type === 'Mesh')
  expect(meshes.length).toBe(3)

  // Check specific properties
  const hero = renderer.scene.children.find(c => c.name === 'hero')
  expect(hero.position.x).toBeCloseTo(0)
})
```

### Simulating Events

```tsx
test('mesh scales on click', async () => {
  const renderer = await ReactThreeTestRenderer.create(<ClickableMesh />)

  const mesh = renderer.scene.children[0]
  expect(mesh.scale.x).toBe(1)

  // Fire click event
  await renderer.fireEvent(mesh, 'click')

  expect(mesh.scale.x).toBe(1.5)
})

test('hover changes color', async () => {
  const renderer = await ReactThreeTestRenderer.create(<HoverMesh />)

  const mesh = renderer.scene.children[0]

  await renderer.fireEvent(mesh, 'pointerOver')
  expect(mesh.material.color.getHexString()).toBe('ff0000')

  await renderer.fireEvent(mesh, 'pointerOut')
  expect(mesh.material.color.getHexString()).toBe('0000ff')
})
```

### Advancing Frames

```tsx
test('mesh rotates over time', async () => {
  const renderer = await ReactThreeTestRenderer.create(<RotatingMesh speed={1} />)

  const mesh = renderer.scene.children[0]
  const initialRotation = mesh.rotation.y

  // Advance 60 frames (~1 second at 60fps)
  await renderer.advanceFrames(60, 1/60)

  expect(mesh.rotation.y).toBeGreaterThan(initialRotation)
  expect(mesh.rotation.y).toBeCloseTo(1, 1)  // ~1 radian after 1 sec
})
```

## Testing Patterns

### Testing Component Props

```tsx
test('mesh responds to position prop', async () => {
  const { rerender, scene } = await ReactThreeTestRenderer.create(
    <Box position={[0, 0, 0]} />
  )

  expect(scene.children[0].position.x).toBe(0)

  // Re-render with new props
  await rerender(<Box position={[5, 0, 0]} />)

  expect(scene.children[0].position.x).toBe(5)
})
```

### Testing State Changes

```tsx
test('store updates affect scene', async () => {
  // Reset store before test
  useStore.setState({ selectedId: null })

  const renderer = await ReactThreeTestRenderer.create(<SelectableScene />)

  // Trigger selection
  useStore.setState({ selectedId: 'mesh-1' })

  // Wait for effects
  await renderer.advanceFrames(1, 0.016)

  const selectedMesh = renderer.scene.children.find(c => c.name === 'mesh-1')
  expect(selectedMesh.material.emissiveIntensity).toBeGreaterThan(0)
})
```

### Testing Event Propagation

```tsx
test('stopPropagation prevents parent handler', async () => {
  const parentHandler = jest.fn()
  const childHandler = jest.fn()

  const renderer = await ReactThreeTestRenderer.create(
    <group onClick={parentHandler}>
      <mesh onClick={(e) => { e.stopPropagation(); childHandler() }} />
    </group>
  )

  const mesh = renderer.scene.children[0].children[0]
  await renderer.fireEvent(mesh, 'click')

  expect(childHandler).toHaveBeenCalled()
  expect(parentHandler).not.toHaveBeenCalled()
})
```

## Mocking Assets

### Mocking useGLTF

```tsx
// __mocks__/@react-three/drei.js
import * as THREE from 'three'

export const useGLTF = jest.fn(() => ({
  scene: new THREE.Group(),
  nodes: {
    Body: new THREE.Mesh(
      new THREE.BoxGeometry(),
      new THREE.MeshStandardMaterial()
    ),
    Head: new THREE.Mesh(
      new THREE.SphereGeometry(),
      new THREE.MeshStandardMaterial()
    ),
  },
  materials: {
    Skin: new THREE.MeshStandardMaterial({ color: 'beige' }),
  },
  animations: [],
}))

useGLTF.preload = jest.fn()
useGLTF.clear = jest.fn()

// Re-export everything else from the real module
export * from '@react-three/drei'
```

### Mocking useTexture

```tsx
export const useTexture = jest.fn(() => {
  const texture = new THREE.Texture()
  texture.needsUpdate = true
  return texture
})

useTexture.preload = jest.fn()
```

### Mock Setup in Test

```tsx
// In test file
jest.mock('@react-three/drei')

import { useGLTF } from '@react-three/drei'

beforeEach(() => {
  ;(useGLTF as jest.Mock).mockClear()
})

test('model loads correctly', async () => {
  const renderer = await ReactThreeTestRenderer.create(<Character />)
  expect(useGLTF).toHaveBeenCalledWith('/character.glb')
})
```

## TypeScript Best Practices

### Typing useRef

```tsx
import { useRef } from 'react'
import * as THREE from 'three'

function MyMesh() {
  // Option 1: Non-null assertion (use when you know ref will be set)
  const meshRef = useRef<THREE.Mesh>(null!)

  // Option 2: Nullable (safer, requires null checks)
  const meshRef = useRef<THREE.Mesh | null>(null)

  useFrame(() => {
    // With null!, no check needed
    meshRef.current.rotation.y += 0.01

    // With nullable, must check
    if (meshRef.current) {
      meshRef.current.rotation.y += 0.01
    }
  })

  return <mesh ref={meshRef}>...</mesh>
}
```

### Typing Event Handlers

```tsx
import { ThreeEvent } from '@react-three/fiber'

function ClickableMesh() {
  const handleClick = (event: ThreeEvent<MouseEvent>) => {
    event.stopPropagation()
    console.log('Clicked at:', event.point)
    console.log('Object:', event.object)
    console.log('Face:', event.face)
  }

  const handlePointerMove = (event: ThreeEvent<PointerEvent>) => {
    console.log('UV:', event.uv)
  }

  return (
    <mesh onClick={handleClick} onPointerMove={handlePointerMove}>
      ...
    </mesh>
  )
}
```

### Extending JSX.IntrinsicElements

When creating custom materials with `shaderMaterial`:

```tsx
import { shaderMaterial } from '@react-three/drei'
import { extend, ReactThreeFiber } from '@react-three/fiber'
import * as THREE from 'three'

// Create the material
const WaveMaterial = shaderMaterial(
  { uTime: 0, uColor: new THREE.Color('#ff0000') },
  vertexShader,
  fragmentShader
)

// Extend Three namespace
extend({ WaveMaterial })

// Declare JSX type
declare global {
  namespace JSX {
    interface IntrinsicElements {
      waveMaterial: ReactThreeFiber.MaterialNode<
        typeof WaveMaterial,
        { uTime: number; uColor: THREE.Color | string }
      >
    }
  }
}

// Now TypeScript knows about <waveMaterial>
function WaveMesh() {
  return (
    <mesh>
      <planeGeometry />
      <waveMaterial uTime={0} uColor="hotpink" />  {/* Typed! */}
    </mesh>
  )
}
```

### Typing useGLTF Results

Use `gltfjsx --types` for auto-generated types:

```tsx
// Auto-generated by gltfjsx
import * as THREE from 'three'
import { GLTF } from 'three-stdlib'

type GLTFResult = GLTF & {
  nodes: {
    Cube: THREE.Mesh
    Sphere: THREE.Mesh
    Light: THREE.PointLight
  }
  materials: {
    Metal: THREE.MeshStandardMaterial
    Glass: THREE.MeshPhysicalMaterial
  }
}

export function Model(props: JSX.IntrinsicElements['group']) {
  const { nodes, materials } = useGLTF('/model.glb') as GLTFResult

  // Now nodes.Cube, materials.Metal are typed
  return (
    <group {...props}>
      <mesh geometry={nodes.Cube.geometry} material={materials.Metal} />
    </group>
  )
}
```

### Generic Component Patterns

```tsx
import { forwardRef } from 'react'
import * as THREE from 'three'

interface BoxProps extends JSX.IntrinsicElements['mesh'] {
  color?: string
  size?: number
}

const Box = forwardRef<THREE.Mesh, BoxProps>(
  ({ color = 'orange', size = 1, ...props }, ref) => {
    return (
      <mesh ref={ref} {...props}>
        <boxGeometry args={[size, size, size]} />
        <meshStandardMaterial color={color} />
      </mesh>
    )
  }
)

// Usage
const boxRef = useRef<THREE.Mesh>(null!)
<Box ref={boxRef} color="red" size={2} position={[0, 1, 0]} />
```

## Storybook Integration

### Setup

```tsx
// .storybook/preview.tsx
import { Canvas } from '@react-three/fiber'

export const decorators = [
  (Story) => (
    <div style={{ width: '100%', height: '400px' }}>
      <Canvas>
        <ambientLight />
        <Story />
      </Canvas>
    </div>
  ),
]
```

### Writing Stories

```tsx
// Box.stories.tsx
import { Box } from './Box'

export default {
  title: 'Components/Box',
  component: Box,
  argTypes: {
    color: { control: 'color' },
    size: { control: { type: 'range', min: 0.5, max: 3 } },
  },
}

export const Default = {
  args: {
    color: '#ff6b6b',
    size: 1,
  },
}

export const Large = {
  args: {
    color: '#4ecdc4',
    size: 2,
  },
}
```

### Chromatic/Visual Testing

```tsx
export const ForVisualTesting = {
  args: { color: 'red' },
  parameters: {
    chromatic: {
      delay: 1000,  // Wait for 3D to render
      pauseAnimationAtEnd: true,
    },
  },
}
```
