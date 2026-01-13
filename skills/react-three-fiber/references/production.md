# Production Patterns

## Table of Contents
- [SSR & Code Splitting](#ssr--code-splitting)
- [Mobile Optimization](#mobile-optimization)
- [Accessibility](#accessibility)
- [SEO](#seo)
- [Testing](#testing)
- [Deployment](#deployment)

## SSR & Code Splitting

### Next.js Dynamic Import

```tsx
import dynamic from 'next/dynamic'

// Skip SSR for Canvas components
const Scene = dynamic(() => import('./Scene'), {
  ssr: false,
  loading: () => <div className="loading-placeholder" />
})

export default function Page() {
  return (
    <div>
      <h1>Product Viewer</h1>
      <Scene />
    </div>
  )
}
```

### App Router (Next.js 13+)

```tsx
// app/viewer/page.tsx
'use client'

import { Canvas } from '@react-three/fiber'

export default function ViewerPage() {
  return (
    <Canvas>
      <Scene />
    </Canvas>
  )
}
```

### Route-Based Splitting

```tsx
// Only load 3D code when route is visited
const ProductViewer = lazy(() => import('./ProductViewer'))

<Routes>
  <Route path="/" element={<Home />} />
  <Route
    path="/product/:id"
    element={
      <Suspense fallback={<Loading />}>
        <ProductViewer />
      </Suspense>
    }
  />
</Routes>
```

### Conditional Canvas Loading

```tsx
// Don't load Canvas until needed
function ProductCard({ product }) {
  const [show3D, setShow3D] = useState(false)

  return (
    <div>
      <img src={product.thumbnail} alt={product.name} />
      <button onClick={() => setShow3D(true)}>View in 3D</button>

      {show3D && (
        <Suspense fallback={<Loading />}>
          <ProductCanvas product={product} />
        </Suspense>
      )}
    </div>
  )
}
```

## Mobile Optimization

### Device Detection

**Note**: `useDetectGPU` suspends while detecting - wrap in `<Suspense>` or use the `<DetectGPU>` component.

```tsx
import { Suspense } from 'react'
import { useDetectGPU } from '@react-three/drei'

// Option 1: Component that uses the hook (must be inside Suspense)
function AdaptiveContent() {
  const GPUTier = useDetectGPU()
  // Tier 0-3, higher = better GPU
  const quality = GPUTier.tier >= 2 ? 'high' : 'low'
  return quality === 'high' ? <HighQualityScene /> : <LowQualityScene />
}

function AdaptiveScene() {
  return (
    <Canvas>
      <Suspense fallback={<LowQualityScene />}>
        <AdaptiveContent />
      </Suspense>
    </Canvas>
  )
}

// Option 2: Render prop pattern (no manual Suspense needed)
import { DetectGPU } from '@react-three/drei'

function AdaptiveScene() {
  return (
    <Canvas>
      <DetectGPU>
        {(GPUTier) => (
          GPUTier.tier >= 2 ? <HighQualityScene /> : <LowQualityScene />
        )}
      </DetectGPU>
    </Canvas>
  )
}
```

### Touch Controls

```tsx
import { OrbitControls, PresentationControls } from '@react-three/drei'

// OrbitControls: pinch zoom, two-finger rotate
<OrbitControls
  enablePan={false}  // Disable pan on mobile
  maxPolarAngle={Math.PI / 2}
  minDistance={2}
  maxDistance={10}
/>

// PresentationControls: drag to rotate (better for product viewers)
<PresentationControls
  global
  snap
  rotation={[0, -Math.PI / 4, 0]}
  polar={[-Math.PI / 4, Math.PI / 4]}
  azimuth={[-Infinity, Infinity]}
>
  <Model />
</PresentationControls>
```

### Performance Scaling

```tsx
import { PerformanceMonitor, AdaptiveDpr, AdaptiveEvents } from '@react-three/drei'

<Canvas>
  <PerformanceMonitor
    onIncline={() => {
      setDpr(2)
      setEffects(true)
    }}
    onDecline={() => {
      setDpr(1)
      setEffects(false)
    }}
  >
    <AdaptiveDpr pixelated />
    <AdaptiveEvents />
  </PerformanceMonitor>

  <Scene />
  {effects && <Postprocessing />}
</Canvas>
```

### Battery Saving

```tsx
// Use demand mode for mostly-static content
<Canvas frameloop="demand">
  <OrbitControls makeDefault />  {/* Auto-invalidates */}
  <StaticProduct />
</Canvas>

// Pause rendering when tab is hidden
useEffect(() => {
  const handleVisibilityChange = () => {
    if (document.hidden) {
      // Could switch to frameloop="never" or pause animations
    }
  }
  document.addEventListener('visibilitychange', handleVisibilityChange)
  return () => document.removeEventListener('visibilitychange', handleVisibilityChange)
}, [])
```

## Accessibility

### react-three-a11y

```tsx
import { A11y } from '@react-three/a11y'

function InteractiveModel() {
  return (
    <A11y
      role="button"
      description="Rotate the 3D sneaker model. Press Enter to view details."
      actionCall={() => showDetails()}
      focus={focused}
      focusCall={(focus) => setFocused(focus)}
    >
      <mesh onClick={showDetails}>
        <Model />
      </mesh>
    </A11y>
  )
}
```

Creates hidden DOM button that:
- Is focusable via Tab
- Has screen reader description
- Triggers onClick via Enter/Space

### Keyboard Navigation

```tsx
import { KeyboardControls, useKeyboardControls } from '@react-three/drei'

// Define control map (outside component)
const controlsMap = [
  { name: 'forward', keys: ['KeyW', 'ArrowUp'] },
  { name: 'back', keys: ['KeyS', 'ArrowDown'] },
  { name: 'left', keys: ['KeyA', 'ArrowLeft'] },
  { name: 'right', keys: ['KeyD', 'ArrowRight'] },
  { name: 'jump', keys: ['Space'] },
]

// Wrap your app with the provider
function App() {
  return (
    <KeyboardControls map={controlsMap}>
      <Canvas>
        <Player />
      </Canvas>
    </KeyboardControls>
  )
}

// Use the hook inside the provider
function Player() {
  const [sub, get] = useKeyboardControls()

  // Subscribe to specific key (triggers re-render)
  const jump = useKeyboardControls((state) => state.jump)

  useFrame(() => {
    // Get current state without re-renders
    const { forward, back, left, right } = get()
    // Move based on keys
  })
}
```

### Reduced Motion

```tsx
function AnimatedElement() {
  const prefersReducedMotion = useMediaQuery('(prefers-reduced-motion: reduce)')

  useFrame(({ clock }) => {
    if (prefersReducedMotion) return  // Skip animation

    meshRef.current.rotation.y = Math.sin(clock.elapsedTime)
  })

  return <mesh ref={meshRef}>...</mesh>
}
```

### Focus Indicators

```tsx
function FocusableObject({ id }) {
  const focused = useStore(s => s.focusedId === id)

  return (
    <mesh>
      <boxGeometry />
      <meshStandardMaterial
        color={focused ? 'yellow' : 'gray'}
        emissive={focused ? 'yellow' : 'black'}
        emissiveIntensity={focused ? 0.5 : 0}
      />
    </mesh>
  )
}
```

## SEO

### Metadata

```tsx
// Next.js App Router
export const metadata = {
  title: 'Product Name - 3D Viewer',
  description: 'Interactive 3D view of Product Name. Rotate, zoom, and explore.',
  openGraph: {
    images: ['/og-image.jpg'],  // Static screenshot of 3D
  },
}
```

### Structured Data

```tsx
// Product schema
const structuredData = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: product.name,
  description: product.description,
  image: product.thumbnail,  // Static image, not 3D
  offers: {
    '@type': 'Offer',
    price: product.price,
  },
}

<script
  type="application/ld+json"
  dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
/>
```

### Static Fallback

```tsx
function ProductViewer({ product }) {
  const [loaded, setLoaded] = useState(false)

  return (
    <div>
      {/* Always render static image for SEO */}
      <img
        src={product.thumbnail}
        alt={product.name}
        style={{ display: loaded ? 'none' : 'block' }}
      />

      {/* 3D replaces image when ready */}
      <Canvas style={{ display: loaded ? 'block' : 'none' }}>
        <Suspense fallback={null}>
          <Model onLoad={() => setLoaded(true)} />
        </Suspense>
      </Canvas>
    </div>
  )
}
```

### noscript Fallback

```tsx
<noscript>
  <img src="/product-static.jpg" alt="Product view - Enable JavaScript for 3D" />
</noscript>
```

## Testing

### React Three Test Renderer

```tsx
import ReactThreeTestRenderer from '@react-three/test-renderer'

test('mesh has correct scale on click', async () => {
  const renderer = await ReactThreeTestRenderer.create(<ClickableBox />)

  const mesh = renderer.scene.children[0]
  expect(mesh.scale.x).toBe(1)

  await renderer.fireEvent(mesh, 'click')
  expect(mesh.scale.x).toBe(1.5)
})
```

### Mocking useGLTF

```tsx
// __mocks__/@react-three/drei.js
export const useGLTF = jest.fn(() => ({
  scene: new THREE.Group(),
  nodes: { Mesh: new THREE.Mesh() },
  materials: { Material: new THREE.MeshStandardMaterial() },
}))

// In test
jest.mock('@react-three/drei')
```

### Visual Regression

```tsx
// With Storybook + Chromatic
export default {
  title: 'Components/ProductViewer',
  component: ProductViewer,
}

export const Default = () => <ProductViewer product={mockProduct} />
Default.parameters = {
  chromatic: { delay: 1000 },  // Wait for 3D to render
}
```

## Deployment

### Asset Optimization

```bash
# Compress GLTF with Draco
npx gltf-pipeline -i model.glb -o model-draco.glb --draco.compressionLevel 10

# Generate KTX2 textures
npx toktx --t2 --encode uastc texture.ktx2 texture.png
```

### CDN Configuration

```tsx
// Use CDN for static assets
const MODEL_BASE_URL = process.env.NEXT_PUBLIC_CDN_URL || ''

function Model() {
  const { scene } = useGLTF(`${MODEL_BASE_URL}/models/product.glb`)
  return <primitive object={scene} />
}
```

### Caching Headers

```
# For GLTF/textures - long cache
Cache-Control: public, max-age=31536000, immutable

# Use content hash in filename
product.a1b2c3d4.glb
```

### Bundle Analysis

```bash
# Analyze bundle size
npx next build
npx @next/bundle-analyzer

# Check for duplicate Three.js
# Should be single instance, not bundled multiple times
```

### Error Monitoring

**Note**: `<Canvas>` does NOT have an `onError` prop. Use React Error Boundaries instead.

```tsx
// Wrap Canvas in an Error Boundary
class CanvasErrorBoundary extends React.Component {
  state = { hasError: false, error: null }

  static getDerivedStateFromError(error) {
    return { hasError: true, error }
  }

  componentDidCatch(error, info) {
    // Report to Sentry/etc
    captureException(error, { extra: info })
  }

  render() {
    if (this.state.hasError) {
      return <FallbackView error={this.state.error} />
    }
    return this.props.children
  }
}

// Usage
<CanvasErrorBoundary>
  <Canvas>
    <Scene />
  </Canvas>
</CanvasErrorBoundary>

// For internal scene errors, nest another boundary
<Canvas>
  <ErrorBoundary fallback={<ErrorMesh />}>
    <Scene />
  </ErrorBoundary>
</Canvas>
```

### WebGL Context Loss

```tsx
// Handle WebGL context loss via onCreated
<Canvas
  onCreated={({ gl }) => {
    gl.domElement.addEventListener('webglcontextlost', (e) => {
      e.preventDefault()
      console.error('WebGL context lost')
    })
    gl.domElement.addEventListener('webglcontextrestored', () => {
      console.log('WebGL context restored')
    })
  }}
>
  <Scene />
</Canvas>
```
