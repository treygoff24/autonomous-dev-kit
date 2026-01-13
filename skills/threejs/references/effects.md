# Particles, Effects, and Large-Scale Simulation

## Table of Contents
- [GPU Particle Systems](#gpu-particle-systems)
- [GPGPU Techniques](#gpgpu-techniques)
- [Instanced Animation (GPU Skinning)](#instanced-animation-gpu-skinning)
- [Noise and Flow Fields](#noise-and-flow-fields)
- [Flocking and Crowds](#flocking-and-crowds)
- [Water Effects](#water-effects)
- [Fire and Smoke](#fire-and-smoke)
- [Terrain and Vegetation](#terrain-and-vegetation)

## GPU Particle Systems

### Basic Points-Based Particles

```typescript
const particleCount = 10000;
const positions = new Float32Array(particleCount * 3);
const velocities = new Float32Array(particleCount * 3);

for (let i = 0; i < particleCount; i++) {
  positions[i * 3] = Math.random() * 100 - 50;
  positions[i * 3 + 1] = Math.random() * 100;
  positions[i * 3 + 2] = Math.random() * 100 - 50;

  velocities[i * 3] = 0;
  velocities[i * 3 + 1] = Math.random() * 2;
  velocities[i * 3 + 2] = 0;
}

const geometry = new THREE.BufferGeometry();
geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
geometry.setAttribute('velocity', new THREE.BufferAttribute(velocities, 3));

const material = new THREE.PointsMaterial({
  size: 0.5,
  map: particleTexture,
  transparent: true,
  depthWrite: false,
  blending: THREE.AdditiveBlending
});

const particles = new THREE.Points(geometry, material);
```

### Shader-Based Animation

```typescript
const particleMaterial = new THREE.ShaderMaterial({
  uniforms: {
    time: { value: 0 },
    pointTexture: { value: particleTexture }
  },
  vertexShader: `
    attribute vec3 velocity;
    uniform float time;

    void main() {
      vec3 pos = position + velocity * time;
      // Respawn when too high
      pos.y = mod(pos.y, 100.0);

      vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
      gl_PointSize = 10.0 / -mvPosition.z;
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  fragmentShader: `
    uniform sampler2D pointTexture;

    void main() {
      gl_FragColor = texture2D(pointTexture, gl_PointCoord);
    }
  `,
  transparent: true,
  depthWrite: false
});
```

## GPGPU Techniques

### Texture-Based State Storage

Store particle positions/velocities in textures, update via shader passes:

```typescript
// Create position and velocity textures
const size = Math.ceil(Math.sqrt(particleCount));

const positionData = new Float32Array(size * size * 4);
const velocityData = new Float32Array(size * size * 4);
for (let i = 0; i < size * size; i++) {
  const i4 = i * 4;
  positionData[i4] = (Math.random() - 0.5) * 100;
  positionData[i4 + 1] = Math.random() * 100;
  positionData[i4 + 2] = (Math.random() - 0.5) * 100;
  positionData[i4 + 3] = 1;

  velocityData[i4] = 0;
  velocityData[i4 + 1] = Math.random() * 0.5;
  velocityData[i4 + 2] = 0;
  velocityData[i4 + 3] = 1;
}

const positionTexture = new THREE.DataTexture(
  positionData, size, size, THREE.RGBAFormat, THREE.FloatType
);
const velocityTexture = new THREE.DataTexture(
  velocityData, size, size, THREE.RGBAFormat, THREE.FloatType
);
positionTexture.needsUpdate = true;
velocityTexture.needsUpdate = true;

// Fullscreen quad vertex shader for simulation pass
const fullscreenQuadVert = `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position, 1.0);
  }
`;

// Simulation shader updates textures each frame
const simulationMaterial = new THREE.ShaderMaterial({
  uniforms: {
    positionTexture: { value: positionTexture },
    velocityTexture: { value: velocityTexture },
    deltaTime: { value: 0 }
  },
  vertexShader: fullscreenQuadVert,
  fragmentShader: `
    uniform sampler2D positionTexture;
    uniform sampler2D velocityTexture;
    uniform float deltaTime;
    varying vec2 vUv;

    void main() {
      vec3 pos = texture2D(positionTexture, vUv).xyz;
      vec3 vel = texture2D(velocityTexture, vUv).xyz;

      pos += vel * deltaTime;

      // Apply forces, boundaries, etc.
      if (pos.y < 0.0) {
        pos.y = 100.0;
        vel.y = 0.0;
      }

      gl_FragColor = vec4(pos, 1.0);
    }
  `
});
```

### Render Particles from Texture

```typescript
const renderMaterial = new THREE.ShaderMaterial({
  uniforms: {
    positionTexture: { value: positionTexture }
  },
  vertexShader: `
    uniform sampler2D positionTexture;
    attribute vec2 reference; // UV to look up position

    void main() {
      vec3 pos = texture2D(positionTexture, reference).xyz;
      vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
      gl_PointSize = 5.0 / -mvPosition.z;
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  fragmentShader: `
    void main() {
      gl_FragColor = vec4(1.0, 0.5, 0.0, 1.0);
    }
  `
});
```

## Instanced Animation (GPU Skinning)

For large crowds with skeletal animation, standard `SkinnedMesh` doesn't scale. Use GPU-based approaches:

### Texture-Based Bone Matrices

Store bone matrices per frame in a texture, sample in vertex shader:

```typescript
// Bake animation to texture (offline or at load)
function bakeAnimationToTexture(clip: THREE.AnimationClip, skeleton: THREE.Skeleton) {
  const boneCount = skeleton.bones.length;
  const frameCount = Math.ceil(clip.duration * 30); // 30 fps
  const width = boneCount * 4; // 4 pixels per bone (mat4 = 16 floats)
  const height = frameCount;

  const data = new Float32Array(width * height * 4);
  const root = skeleton.bones[0];
  const mixer = new THREE.AnimationMixer(root);
  const action = mixer.clipAction(clip);
  action.play();

  const boneMatrix = new THREE.Matrix4();
  for (let frame = 0; frame < frameCount; frame++) {
    mixer.setTime(frame / 30);
    root.updateMatrixWorld(true);
    skeleton.update();
    const frameOffset = frame * boneCount * 16;
    for (let b = 0; b < boneCount; b++) {
      boneMatrix.multiplyMatrices(
        skeleton.bones[b].matrixWorld,
        skeleton.boneInverses[b]
      );
      boneMatrix.toArray(data, frameOffset + b * 16);
    }
  }

  const texture = new THREE.DataTexture(data, width, height, THREE.RGBAFormat, THREE.FloatType);
  texture.needsUpdate = true;
  return texture;
}
```

### Instanced Skinned Mesh Shader

```glsl
// Vertex shader for instanced animated characters
attribute float animationTime; // Per-instance animation offset
uniform sampler2D boneTexture;
uniform float boneTextureSize;

mat4 getBoneMatrix(float boneIndex, float frame) {
  float x = boneIndex * 4.0;
  float y = frame;
  // Sample 4 pixels to reconstruct mat4
  vec4 c0 = texture2D(boneTexture, vec2((x + 0.5) / boneTextureSize, (y + 0.5) / boneTextureSize));
  vec4 c1 = texture2D(boneTexture, vec2((x + 1.5) / boneTextureSize, (y + 0.5) / boneTextureSize));
  vec4 c2 = texture2D(boneTexture, vec2((x + 2.5) / boneTextureSize, (y + 0.5) / boneTextureSize));
  vec4 c3 = texture2D(boneTexture, vec2((x + 3.5) / boneTextureSize, (y + 0.5) / boneTextureSize));
  return mat4(c0, c1, c2, c3);
}
```

### Impostor Swap Chains

For very distant crowds, swap animated meshes with billboards:

```typescript
const LOD_DISTANCE_MESH = 50;
const LOD_DISTANCE_IMPOSTOR = 150;

function updateCrowdLOD(characters: Character[], camera: THREE.Camera) {
  for (const char of characters) {
    const dist = camera.position.distanceTo(char.position);

    if (dist < LOD_DISTANCE_MESH) {
      char.mesh.visible = true;
      char.impostor.visible = false;
    } else if (dist < LOD_DISTANCE_IMPOSTOR) {
      char.mesh.visible = false;
      char.impostor.visible = true;
      // Update impostor to face camera
      char.impostor.quaternion.copy(camera.quaternion);
    } else {
      char.mesh.visible = false;
      char.impostor.visible = false;
    }
  }
}
```

### Libraries

- **three-instanced-skinned-mesh** - Community solution for instanced SkinnedMesh
- **three-nebula** - GPU particle system with built-in behaviors

## Noise and Flow Fields

### Curl Noise for Fluid Motion

```glsl
// In fragment/vertex shader
vec3 curlNoise(vec3 p) {
  float e = 0.1;
  vec3 dx = vec3(e, 0.0, 0.0);
  vec3 dy = vec3(0.0, e, 0.0);
  vec3 dz = vec3(0.0, 0.0, e);

  float n1 = noise(p + dy) - noise(p - dy);
  float n2 = noise(p + dz) - noise(p - dz);
  float n3 = noise(p + dx) - noise(p - dx);
  float n4 = noise(p + dz) - noise(p - dz);
  float n5 = noise(p + dx) - noise(p - dx);
  float n6 = noise(p + dy) - noise(p - dy);

  return vec3(n1 - n2, n3 - n4, n5 - n6) / (2.0 * e);
}

// Apply to velocity
velocity += curlNoise(position * 0.1 + time * 0.1) * 0.1;
```

### Precomputed 3D Noise Texture

```typescript
// Generate or load 3D noise texture
const noiseData = new Float32Array(64 * 64 * 64);
for (let i = 0; i < noiseData.length; i++) {
  noiseData[i] = Math.random() * 2 - 1;
}

const noiseTexture = new THREE.Data3DTexture(noiseData, 64, 64, 64);
noiseTexture.format = THREE.RedFormat;
noiseTexture.type = THREE.FloatType;
noiseTexture.needsUpdate = true;

// Sample in shader
// vec3 noiseVal = texture(noiseTexture, position * 0.1).rgb;
```

## Flocking and Crowds

### Boids Algorithm

```typescript
interface Boid {
  position: THREE.Vector3;
  velocity: THREE.Vector3;
}

function updateBoids(boids: Boid[], dt: number) {
  const separationDist = 2;
  const alignmentDist = 5;
  const cohesionDist = 5;

  for (const boid of boids) {
    const separation = new THREE.Vector3();
    const alignment = new THREE.Vector3();
    const cohesion = new THREE.Vector3();
    let sepCount = 0, alignCount = 0, cohCount = 0;

    for (const other of boids) {
      if (other === boid) continue;
      const dist = boid.position.distanceTo(other.position);

      if (dist < separationDist) {
        separation.add(
          boid.position.clone().sub(other.position).normalize().divideScalar(dist)
        );
        sepCount++;
      }
      if (dist < alignmentDist) {
        alignment.add(other.velocity);
        alignCount++;
      }
      if (dist < cohesionDist) {
        cohesion.add(other.position);
        cohCount++;
      }
    }

    if (sepCount > 0) separation.divideScalar(sepCount);
    if (alignCount > 0) alignment.divideScalar(alignCount);
    if (cohCount > 0) {
      cohesion.divideScalar(cohCount).sub(boid.position);
    }

    boid.velocity.add(separation.multiplyScalar(1.5));
    boid.velocity.add(alignment.multiplyScalar(1.0));
    boid.velocity.add(cohesion.multiplyScalar(1.0));
    boid.velocity.clampLength(0, 5);

    boid.position.add(boid.velocity.clone().multiplyScalar(dt));
  }
}
```

### Instanced Crowd Rendering

```typescript
const crowdMesh = new THREE.InstancedMesh(characterGeo, characterMat, 100);
const dummy = new THREE.Object3D();

function updateCrowd(boids: Boid[]) {
  boids.forEach((boid, i) => {
    dummy.position.copy(boid.position);
    dummy.lookAt(boid.position.clone().add(boid.velocity));
    dummy.updateMatrix();
    crowdMesh.setMatrixAt(i, dummy.matrix);
  });
  crowdMesh.instanceMatrix.needsUpdate = true;
}
```

## Water Effects

### Reflective Water

```typescript
import { Water } from 'three/examples/jsm/objects/Water.js';

const waterGeometry = new THREE.PlaneGeometry(1000, 1000);
const water = new Water(waterGeometry, {
  textureWidth: 512,
  textureHeight: 512,
  waterNormals: textureLoader.load('waternormals.jpg', tex => {
    tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  }),
  sunDirection: new THREE.Vector3(),
  sunColor: 0xffffff,
  waterColor: 0x001e0f,
  distortionScale: 3.7
});
water.rotation.x = -Math.PI / 2;
scene.add(water);

// Animate
function updateWater() {
  water.material.uniforms['time'].value += 1.0 / 60.0;
}
```

### Simple Wave Displacement

```glsl
// Vertex shader
uniform float time;

void main() {
  vec3 pos = position;
  float wave1 = sin(pos.x * 0.5 + time) * 0.5;
  float wave2 = sin(pos.z * 0.3 + time * 1.5) * 0.3;
  pos.y += wave1 + wave2;

  gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
}
```

## Fire and Smoke

### Particle-Based Fire

```typescript
// Helper to create particle geometry with life attribute
function createParticleGeometry(count: number): THREE.BufferGeometry {
  const positions = new Float32Array(count * 3);
  const life = new Float32Array(count);
  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() - 0.5) * 2;
    positions[i * 3 + 1] = Math.random() * 3;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 2;
    life[i] = Math.random();
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geo.setAttribute('life', new THREE.BufferAttribute(life, 1));
  return geo;
}

const fireParticles = new THREE.Points(
  createParticleGeometry(500),
  new THREE.ShaderMaterial({
    uniforms: {
      time: { value: 0 },
      fireTexture: { value: fireTexture }
    },
    vertexShader: `
      attribute float life;
      varying float vLife;

      void main() {
        vLife = life;
        vec4 mvPos = modelViewMatrix * vec4(position, 1.0);
        gl_PointSize = (1.0 - life) * 50.0 / -mvPos.z;
        gl_Position = projectionMatrix * mvPos;
      }
    `,
    fragmentShader: `
      varying float vLife;
      uniform sampler2D fireTexture;

      void main() {
        vec4 tex = texture2D(fireTexture, gl_PointCoord);
        vec3 color = mix(vec3(1.0, 0.3, 0.0), vec3(1.0, 1.0, 0.0), vLife);
        gl_FragColor = vec4(color * tex.rgb, tex.a * (1.0 - vLife));
      }
    `,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending
  })
);
```

### Volumetric Smoke (Layered Planes)

```typescript
// Stack of transparent planes with noise-scrolled texture
const smokeLayers = [];
for (let i = 0; i < 10; i++) {
  const plane = new THREE.Mesh(
    new THREE.PlaneGeometry(5, 5),
    new THREE.MeshBasicMaterial({
      map: smokeTexture,
      transparent: true,
      opacity: 0.3,
      depthWrite: false
    })
  );
  plane.position.y = i * 0.5;
  plane.rotation.x = -Math.PI / 2;
  smokeLayers.push(plane);
}

// Animate UV offset for movement
function updateSmoke(dt: number) {
  smokeLayers.forEach((layer, i) => {
    layer.material.map.offset.y += dt * 0.1 * (1 + i * 0.1);
  });
}
```

## Terrain and Vegetation

### Heightmap Terrain

```typescript
const heightTexture = textureLoader.load('heightmap.png');

const terrainGeo = new THREE.PlaneGeometry(100, 100, 256, 256);
const terrainMat = new THREE.ShaderMaterial({
  uniforms: {
    heightMap: { value: heightTexture },
    heightScale: { value: 20 }
  },
  vertexShader: `
    uniform sampler2D heightMap;
    uniform float heightScale;

    void main() {
      vec2 uv = uv;
      float height = texture2D(heightMap, uv).r * heightScale;
      vec3 pos = position;
      pos.z = height;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
    }
  `
});

const terrain = new THREE.Mesh(terrainGeo, terrainMat);
terrain.rotation.x = -Math.PI / 2;
```

### Instanced Grass

```typescript
const grassCount = 50000;
const grassGeo = new THREE.PlaneGeometry(0.1, 0.5);
const grassMesh = new THREE.InstancedMesh(grassGeo, grassMat, grassCount);

const dummy = new THREE.Object3D();
for (let i = 0; i < grassCount; i++) {
  dummy.position.set(
    Math.random() * 100 - 50,
    0,
    Math.random() * 100 - 50
  );
  dummy.rotation.y = Math.random() * Math.PI;
  dummy.scale.setScalar(0.8 + Math.random() * 0.4);
  dummy.updateMatrix();
  grassMesh.setMatrixAt(i, dummy.matrix);
}

// Animate wind in vertex shader
// Use sin(position.x + time) to offset vertices
```

### Billboard Trees

```typescript
// For distant trees, use sprites that always face camera
const treeSprite = new THREE.Sprite(
  new THREE.SpriteMaterial({ map: treeTexture })
);
treeSprite.scale.set(5, 10, 1);

// Or manual billboard rotation
function updateBillboard(sprite: THREE.Mesh) {
  sprite.quaternion.copy(camera.quaternion);
}
```
