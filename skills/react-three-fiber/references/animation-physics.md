# Animation & Physics Integration

## Table of Contents
- [Animation Approaches](#animation-approaches)
- [React Spring](#react-spring)
- [Framer Motion 3D](#framer-motion-3d)
- [useFrame Patterns](#useframe-patterns)
- [Skeletal Animation](#skeletal-animation)
- [Rapier Physics](#rapier-physics)
- [Combining Systems](#combining-systems)

## Animation Approaches

| Approach | Best For | Updates Via |
|----------|----------|-------------|
| useFrame | Custom, per-frame control | Direct mutation |
| React Spring | Physics-based transitions | Animated proxy |
| Framer Motion 3D | Declarative state transitions | Animated wrapper |
| AnimationMixer | Skeletal/morph animations | Three.js system |
| GSAP | Complex timelines | External library |

## External Animation Libraries + Demand Mode

When using `frameloop="demand"`, external animation libraries (GSAP, AnimationMixer) won't render automatically. You need to call `invalidate()` during animation.

### GSAP with R3F

```tsx
import gsap from 'gsap'
import { useThree } from '@react-three/fiber'

function GSAPAnimation() {
  const meshRef = useRef()
  const { invalidate } = useThree()

  useEffect(() => {
    // Create GSAP timeline
    const tl = gsap.timeline({
      onUpdate: invalidate,  // Request frame on each GSAP update
    })

    tl.to(meshRef.current.position, { x: 5, duration: 2, ease: 'power2.out' })
      .to(meshRef.current.rotation, { y: Math.PI * 2, duration: 1 }, '-=1')

    return () => tl.kill()
  }, [invalidate])

  return <mesh ref={meshRef}>...</mesh>
}
```

### AnimationMixer with Demand Mode

```tsx
function AnimatedModel() {
  const { scene, animations } = useGLTF('/model.glb')
  const { actions, mixer } = useAnimations(animations, scene)
  const { invalidate } = useThree()

  useEffect(() => {
    actions.walk?.play()

    // Invalidate while animation is playing
    const handler = () => invalidate()
    mixer.addEventListener('loop', handler)

    return () => mixer.removeEventListener('loop', handler)
  }, [actions, mixer, invalidate])

  // Keep invalidating while mixer is running
  useFrame((_, delta) => {
    mixer.update(delta)
    if (actions.walk?.isRunning()) {
      invalidate()
    }
  })

  return <primitive object={scene} />
}
```

**Key pattern**: Always call `invalidate()` from your animation's update callback or useFrame when using `frameloop="demand"`.

## React Spring

```tsx
import { a, useSpring } from '@react-spring/three'

function AnimatedBox({ active }) {
  const { scale, color } = useSpring({
    scale: active ? 1.5 : 1,
    color: active ? '#ff6d6d' : '#6d6dff',
    config: { mass: 1, tension: 280, friction: 60 }
  })

  return (
    <a.mesh scale={scale}>
      <boxGeometry />
      <a.meshStandardMaterial color={color} />
    </a.mesh>
  )
}
```

### Spring Config Options

```tsx
useSpring({
  to: { x: 100 },
  config: {
    mass: 1,        // Weight of the spring
    tension: 170,   // Stiffness
    friction: 26,   // Damping
    precision: 0.01,
    velocity: 0,
    clamp: false,   // Stop at boundaries
    duration: 1000, // Override physics with duration
    easing: t => t, // Easing function if using duration
  }
})

// Presets
import { config } from '@react-spring/three'
config.default  // { mass: 1, tension: 170, friction: 26 }
config.gentle   // { mass: 1, tension: 120, friction: 14 }
config.wobbly   // { mass: 1, tension: 180, friction: 12 }
config.stiff    // { mass: 1, tension: 210, friction: 20 }
config.slow     // { mass: 1, tension: 280, friction: 60 }
config.molasses // { mass: 1, tension: 280, friction: 120 }
```

### Chained Springs

```tsx
const [springs, api] = useSprings(3, i => ({
  position: [i * 2, 0, 0],
  config: config.wobbly,
}))

// Trigger chain
api.start(i => ({
  position: [i * 2, Math.sin(i) * 2, 0],
  delay: i * 100,
}))
```

## Framer Motion 3D

```tsx
import { motion } from 'framer-motion-3d'

function AnimatedMesh() {
  return (
    <motion.mesh
      initial={{ scale: 0 }}
      animate={{ scale: 1 }}
      whileHover={{ scale: 1.2 }}
      transition={{ type: 'spring', stiffness: 300 }}
    >
      <boxGeometry />
      <meshStandardMaterial />
    </motion.mesh>
  )
}
```

### Variants

```tsx
const variants = {
  hidden: { scale: 0, rotateY: 0 },
  visible: { scale: 1, rotateY: Math.PI * 2 },
}

<motion.mesh
  variants={variants}
  initial="hidden"
  animate="visible"
  transition={{ duration: 1 }}
/>
```

## useFrame Patterns

### Lerp (Linear Interpolation)

```tsx
const targetPosition = useMemo(() => new Vector3(), [])

useFrame(() => {
  targetPosition.set(targetX, targetY, targetZ)
  meshRef.current.position.lerp(targetPosition, 0.1)
})
```

### Damp (Frame-rate Independent)

```tsx
import { damp } from 'three/src/math/MathUtils'

useFrame((_, delta) => {
  meshRef.current.rotation.y = damp(
    meshRef.current.rotation.y,
    targetRotation,
    4,     // lambda (smoothing factor)
    delta
  )
})
```

### Oscillation

```tsx
useFrame(({ clock }) => {
  meshRef.current.position.y = Math.sin(clock.elapsedTime * 2) * 0.5
  meshRef.current.rotation.z = Math.cos(clock.elapsedTime) * 0.1
})
```

### Easing Functions

```tsx
// Manual eased animation
const animationRef = useRef({ t: 0, duration: 1 })

useFrame((_, delta) => {
  const anim = animationRef.current
  if (anim.t < 1) {
    anim.t = Math.min(anim.t + delta / anim.duration, 1)
    const eased = easeOutCubic(anim.t)
    meshRef.current.position.x = lerp(startX, endX, eased)
  }
})

function easeOutCubic(t) {
  return 1 - Math.pow(1 - t, 3)
}
```

## Skeletal Animation

### useAnimations Hook

```tsx
import { useAnimations, useGLTF } from '@react-three/drei'

function Character({ action }) {
  const { scene, animations } = useGLTF('/character.glb')
  const { actions, mixer } = useAnimations(animations, scene)

  useEffect(() => {
    // Crossfade to new action
    const current = actions[action]
    current?.reset().fadeIn(0.5).play()

    return () => current?.fadeOut(0.5)
  }, [action, actions])

  return <primitive object={scene} />
}
```

### Animation Blending

```tsx
function BlendedCharacter({ walkSpeed }) {
  const { scene, animations } = useGLTF('/character.glb')
  const { actions } = useAnimations(animations, scene)

  useEffect(() => {
    actions.idle?.play()
    actions.walk?.play()

    // Blend based on speed
    actions.idle.setEffectiveWeight(1 - walkSpeed)
    actions.walk.setEffectiveWeight(walkSpeed)
  }, [walkSpeed, actions])

  return <primitive object={scene} />
}
```

## Rapier Physics

### Basic Setup

```tsx
import { Physics, RigidBody, CuboidCollider } from '@react-three/rapier'

function PhysicsScene() {
  return (
    <Physics gravity={[0, -9.81, 0]} debug>
      <RigidBody type="fixed">
        <mesh position={[0, -1, 0]}>
          <boxGeometry args={[20, 1, 20]} />
          <meshStandardMaterial />
        </mesh>
      </RigidBody>

      <RigidBody restitution={0.7}>
        <mesh position={[0, 5, 0]}>
          <sphereGeometry />
          <meshStandardMaterial />
        </mesh>
      </RigidBody>
    </Physics>
  )
}
```

### RigidBody Types

| Type | Description |
|------|-------------|
| `dynamic` | Affected by forces, gravity (default) |
| `fixed` | Static, immovable |
| `kinematicPosition` | Moved by setting position |
| `kinematicVelocity` | Moved by setting velocity |

### Applying Forces

```tsx
function JumpingBall() {
  const bodyRef = useRef()

  const jump = () => {
    bodyRef.current.applyImpulse({ x: 0, y: 5, z: 0 }, true)
  }

  const push = () => {
    bodyRef.current.applyForce({ x: 10, y: 0, z: 0 }, true)
  }

  return (
    <RigidBody ref={bodyRef}>
      <mesh onClick={jump}>
        <sphereGeometry />
        <meshStandardMaterial />
      </mesh>
    </RigidBody>
  )
}
```

### Collision Events

```tsx
<RigidBody
  onCollisionEnter={({ other }) => {
    console.log('Hit:', other.rigidBodyObject.name)
  }}
  onCollisionExit={() => {
    console.log('No longer colliding')
  }}
  onContactForce={(payload) => {
    // payload.totalForceMagnitude
  }}
>
  <mesh name="player">...</mesh>
</RigidBody>
```

### Character Controller

```tsx
function CharacterController() {
  const bodyRef = useRef()
  const [keys, setKeys] = useState({ forward: false, back: false, left: false, right: false })

  useFrame(() => {
    const impulse = { x: 0, y: 0, z: 0 }
    if (keys.forward) impulse.z -= 0.1
    if (keys.back) impulse.z += 0.1
    if (keys.left) impulse.x -= 0.1
    if (keys.right) impulse.x += 0.1

    bodyRef.current.applyImpulse(impulse, true)
  })

  return (
    <RigidBody
      ref={bodyRef}
      type="dynamic"
      enabledRotations={[false, false, false]}  // Prevent tipping
      linearDamping={0.5}
    >
      <CapsuleCollider args={[0.5, 0.5]} />
      <mesh>...</mesh>
    </RigidBody>
  )
}
```

### Sensors (Triggers)

```tsx
<RigidBody type="fixed">
  <CuboidCollider
    args={[2, 2, 2]}
    sensor
    onIntersectionEnter={({ other }) => {
      console.log('Entered zone:', other.rigidBodyObject.name)
    }}
    onIntersectionExit={() => {
      console.log('Left zone')
    }}
  />
</RigidBody>
```

## Combining Systems

### Spring + Physics

Don't animate physics objects with springs directly. Instead:

```tsx
// Spring controls visual smoothing of physics output
function SmoothedPhysicsObject() {
  const bodyRef = useRef()
  const meshRef = useRef()
  const [spring, api] = useSpring(() => ({ position: [0, 0, 0] }))

  useFrame(() => {
    // Get physics position
    const pos = bodyRef.current.translation()
    // Spring toward it
    api.start({ position: [pos.x, pos.y, pos.z] })
  })

  return (
    <>
      <RigidBody ref={bodyRef}>
        <CuboidCollider args={[0.5, 0.5, 0.5]} />
      </RigidBody>
      {/* Visual mesh follows with spring smoothing */}
      <a.mesh ref={meshRef} position={spring.position}>
        <boxGeometry />
        <meshStandardMaterial />
      </a.mesh>
    </>
  )
}
```

### Animation + Physics Handoff

```tsx
function Ragdoll() {
  const [isRagdoll, setIsRagdoll] = useState(false)
  const { scene, animations } = useGLTF('/character.glb')
  const { actions } = useAnimations(animations, scene)

  const enableRagdoll = () => {
    actions.current?.stop()
    setIsRagdoll(true)
  }

  if (isRagdoll) {
    return <PhysicsRagdoll model={scene} />
  }

  return (
    <primitive object={scene} onClick={enableRagdoll} />
  )
}
```
