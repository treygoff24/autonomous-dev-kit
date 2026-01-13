# Shaders in R3F

## Table of Contents
- [shaderMaterial Basics](#shadermaterial-basics)
- [Drei Materials](#drei-materials)
- [Postprocessing](#postprocessing)
- [Advanced Patterns](#advanced-patterns)

## shaderMaterial Basics

### Creating a Custom Material

```tsx
import { shaderMaterial } from '@react-three/drei'
import { extend } from '@react-three/fiber'
import * as THREE from 'three'

const GradientMaterial = shaderMaterial(
  // Uniforms (become props)
  {
    uTime: 0,
    uColorA: new THREE.Color('#ff0000'),
    uColorB: new THREE.Color('#0000ff'),
  },
  // Vertex shader
  `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  // Fragment shader
  `
    uniform float uTime;
    uniform vec3 uColorA;
    uniform vec3 uColorB;
    varying vec2 vUv;

    void main() {
      vec3 color = mix(uColorA, uColorB, vUv.y + sin(uTime) * 0.2);
      gl_FragColor = vec4(color, 1.0);
    }
  `
)

// Register for JSX use (lowercase)
extend({ GradientMaterial })

// TypeScript declaration (optional)
declare global {
  namespace JSX {
    interface IntrinsicElements {
      gradientMaterial: any
    }
  }
}
```

### Using the Material

```tsx
function GradientMesh() {
  const materialRef = useRef()

  // Update time uniform in useFrame
  useFrame((state) => {
    materialRef.current.uTime = state.clock.elapsedTime
  })

  return (
    <mesh>
      <planeGeometry args={[2, 2]} />
      <gradientMaterial
        ref={materialRef}
        uColorA="#ff6b6b"
        uColorB="#4ecdc4"
        transparent
        side={THREE.DoubleSide}
      />
    </mesh>
  )
}
```

### Uniform Update Patterns

```tsx
// Via ref (best for per-frame updates)
useFrame(({ clock }) => {
  materialRef.current.uTime = clock.elapsedTime
})

// Via props (fine for occasional updates)
<gradientMaterial uTime={time} />

// Direct uniform access
materialRef.current.uniforms.uTime.value = newValue
```

## Drei Materials

### MeshTransmissionMaterial

Realistic glass/transparent materials:

```tsx
import { MeshTransmissionMaterial, Environment } from '@react-three/drei'

<mesh>
  <sphereGeometry args={[1, 64, 64]} />
  <MeshTransmissionMaterial
    thickness={0.5}
    roughness={0}
    transmission={1}
    ior={1.5}
    chromaticAberration={0.03}
    anisotropicBlur={0.1}
    distortion={0.2}
    distortionScale={0.5}
    temporalDistortion={0.1}
    backside
  />
</mesh>
```

Requires `<Environment>` for proper reflections.

### MeshReflectorMaterial

Reflective floor/surfaces:

```tsx
import { MeshReflectorMaterial } from '@react-three/drei'

<mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.5, 0]}>
  <planeGeometry args={[10, 10]} />
  <MeshReflectorMaterial
    blur={[300, 100]}
    resolution={1024}
    mixBlur={1}
    mixStrength={80}
    roughness={1}
    depthScale={1.2}
    minDepthThreshold={0.4}
    maxDepthThreshold={1.4}
    color="#151515"
    metalness={0.5}
  />
</mesh>
```

### MeshDistortMaterial

Animated noise distortion:

```tsx
import { MeshDistortMaterial } from '@react-three/drei'

<mesh>
  <sphereGeometry args={[1, 64, 64]} />
  <MeshDistortMaterial
    color="#4a9eff"
    attach="material"
    distort={0.5}      // Distortion strength
    speed={2}          // Animation speed
    roughness={0}
  />
</mesh>
```

### MeshWobbleMaterial

Vertex wobble effect:

```tsx
import { MeshWobbleMaterial } from '@react-three/drei'

<mesh>
  <boxGeometry />
  <MeshWobbleMaterial
    factor={1}     // Wobble strength
    speed={2}      // Animation speed
    color="hotpink"
  />
</mesh>
```

## Postprocessing

### Basic Setup

```tsx
import { EffectComposer, Bloom, DepthOfField, Noise, Vignette } from '@react-three/postprocessing'

<Canvas>
  <Scene />
  <EffectComposer>
    <Bloom
      intensity={1.5}
      luminanceThreshold={0.9}
      luminanceSmoothing={0.025}
    />
    <DepthOfField
      focusDistance={0}
      focalLength={0.02}
      bokehScale={2}
      height={480}
    />
    <Noise opacity={0.02} />
    <Vignette eskil={false} offset={0.1} darkness={1.1} />
  </EffectComposer>
</Canvas>
```

### Common Effects

| Effect | Purpose | Key Props |
|--------|---------|-----------|
| `Bloom` | Glow on bright areas | intensity, luminanceThreshold |
| `DepthOfField` | Focus blur | focusDistance, focalLength, bokehScale |
| `SSAO` | Ambient occlusion | radius, intensity, samples |
| `SSR` | Screen-space reflections | intensity, exponent |
| `ChromaticAberration` | Color fringing | offset |
| `Noise` | Film grain | opacity |
| `Vignette` | Edge darkening | offset, darkness |
| `ToneMapping` | Color grading | mode |
| `GodRays` | Light shafts | sun, samples, density |

### Selective Bloom

Using layers to bloom only certain objects:

```tsx
import { Selection, Select, EffectComposer, SelectiveBloom } from '@react-three/postprocessing'

<Selection>
  <EffectComposer>
    <SelectiveBloom
      intensity={2}
      luminanceThreshold={0}
      luminanceSmoothing={0.9}
    />
  </EffectComposer>

  {/* This will bloom */}
  <Select enabled>
    <mesh>
      <sphereGeometry />
      <meshStandardMaterial emissive="blue" emissiveIntensity={2} />
    </mesh>
  </Select>

  {/* This won't bloom */}
  <mesh>
    <boxGeometry />
    <meshStandardMaterial color="red" />
  </mesh>
</Selection>
```

### Performance Tips

- Keep resolution low: `height={480}` on DOF
- Limit SSAO samples: `samples={16}`
- Skip effects on mobile: conditional rendering
- Use `<PerformanceMonitor>` to toggle effects

## Advanced Patterns

### Noise Functions

```glsl
// In your shader
float random(vec2 st) {
  return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
  vec2 i = floor(st);
  vec2 f = fract(st);
  float a = random(i);
  float b = random(i + vec2(1.0, 0.0));
  float c = random(i + vec2(0.0, 1.0));
  float d = random(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 st) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 5; i++) {
    value += amplitude * noise(st);
    st *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}
```

### Fresnel Effect

```glsl
uniform vec3 uFresnelColor;
varying vec3 vNormal;
varying vec3 vViewDirection;

void main() {
  float fresnel = pow(1.0 - dot(vNormal, vViewDirection), 3.0);
  vec3 color = mix(vec3(0.0), uFresnelColor, fresnel);
  gl_FragColor = vec4(color, fresnel);
}
```

### Vertex Displacement

```glsl
uniform float uTime;
uniform float uAmplitude;

void main() {
  vec3 pos = position;
  float displacement = sin(pos.x * 10.0 + uTime) * uAmplitude;
  pos += normal * displacement;

  gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
}
```

### Texture Scrolling

```glsl
uniform sampler2D uTexture;
uniform float uTime;
varying vec2 vUv;

void main() {
  vec2 scrolledUv = vUv + vec2(uTime * 0.1, 0.0);
  vec4 texColor = texture2D(uTexture, scrolledUv);
  gl_FragColor = texColor;
}
```

### lamina (Layered Materials)

```tsx
import { LayerMaterial, Base, Depth, Fresnel, Noise } from 'lamina'

<mesh>
  <sphereGeometry />
  <LayerMaterial>
    <Base color="#ff4eb8" alpha={1} mode="normal" />
    <Depth
      colorA="#ff0000"
      colorB="#0000ff"
      alpha={0.5}
      mode="multiply"
      near={0}
      far={2}
      origin={[1, 1, 1]}
    />
    <Fresnel
      mode="softlight"
      color="#fff"
      intensity={0.3}
      power={2}
      bias={0}
    />
    <Noise
      mapping="local"
      type="simplex"
      scale={100}
      colorA="#fff"
      colorB="#000"
      mode="subtract"
      alpha={0.2}
    />
  </LayerMaterial>
</mesh>
```
