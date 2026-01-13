# Lighting, Materials, and Realistic Rendering

## Table of Contents
- [Color Management](#color-management)
- [Tone Mapping](#tone-mapping)
- [Physical Lighting](#physical-lighting)
- [Environment Maps (IBL)](#environment-maps-ibl)
- [Shadows](#shadows)
- [PBR Materials](#pbr-materials)
- [Special Material Effects](#special-material-effects)
- [Atmospheric Effects](#atmospheric-effects)

## Color Management

### Linear Workflow Setup

```typescript
// Renderer output (Three.js r152+)
renderer.outputColorSpace = THREE.SRGBColorSpace;

// Color textures (albedo, emissive)
colorTexture.colorSpace = THREE.SRGBColorSpace;

// Data textures (normal, roughness, metallic, AO)
normalTexture.colorSpace = THREE.LinearSRGBColorSpace; // Default
```

### Why Linear?

Lighting calculations must happen in linear space. sRGB textures are gamma-corrected for display—Three.js converts them to linear internally, then converts back for output.

## Tone Mapping

### Available Operators

```typescript
renderer.toneMapping = THREE.ACESFilmicToneMapping; // Cinematic
renderer.toneMappingExposure = 1.0;
```

| Operator | Character |
|----------|-----------|
| LinearToneMapping | No curve, harsh clipping |
| ReinhardToneMapping | Gentle rolloff, muted |
| CineonToneMapping | Film-like |
| ACESFilmicToneMapping | Cinematic, slight color shift |

### ACES Color Shift

ACES pushes bright oranges toward yellow and bright blues toward cyan. For accurate color (product viz), consider:
- LinearToneMapping with lower exposure
- Custom tone mapping shader

### Exposure Control

Think of `toneMappingExposure` as a camera exposure dial:

```typescript
// Dark scene
renderer.toneMappingExposure = 2.0;

// Bright outdoor
renderer.toneMappingExposure = 0.5;
```

## Physical Lighting

### Enable Physical Units

```typescript
// Three.js r155+: physical lights are default, disable legacy mode
renderer.useLegacyLights = false;

// For Three.js r150-r154:
// renderer.physicallyCorrectLights = true;
```

Now light intensity is in candelas (point/spot) or lux (directional).

### Realistic Values

| Light Type | Typical Intensity |
|------------|-------------------|
| Candle | 12 cd |
| 60W bulb | 800 cd |
| Bright lamp | 2000 cd |
| Sun (directional) | 100,000 lux |
| Overcast sky | 10,000 lux |

```typescript
const sun = new THREE.DirectionalLight(0xffffff, 3);
// With physical lights, intensity ~3 looks like bright sun
// Adjust toneMappingExposure to balance
```

### Decay

With physical lights, point/spot decay is realistic (inverse-square):

```typescript
const pointLight = new THREE.PointLight(0xffffff, 100, 0, 2);
// intensity: candelas
// distance: 0 = infinite
// decay: 2 = physically correct (inverse square)
```

## Environment Maps (IBL)

### HDR Environment

```typescript
import { RGBELoader } from 'three/examples/jsm/loaders/RGBELoader.js';

const rgbeLoader = new RGBELoader();
rgbeLoader.load('environment.hdr', (texture) => {
  texture.mapping = THREE.EquirectangularReflectionMapping;

  // For PBR reflections
  scene.environment = texture;

  // Optionally as background
  scene.background = texture;
});
```

### PMREM Processing

For accurate roughness-based reflections, use PMREMGenerator:

```typescript
const pmremGenerator = new THREE.PMREMGenerator(renderer);
pmremGenerator.compileEquirectangularShader();

rgbeLoader.load('environment.hdr', (texture) => {
  const envMap = pmremGenerator.fromEquirectangular(texture).texture;
  scene.environment = envMap;
  texture.dispose();
  pmremGenerator.dispose();
});
```

### Light Probes

For ambient diffuse lighting:

```typescript
import { LightProbeGenerator } from 'three/examples/jsm/lights/LightProbeGenerator.js';

const lightProbe = new THREE.LightProbe();
scene.add(lightProbe);

// Generate from cube texture
const cubeTexture = cubeTextureLoader.load([...]);
lightProbe.copy(LightProbeGenerator.fromCubeTexture(cubeTexture));
```

## Shadows

### Basic Setup

```typescript
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const light = new THREE.DirectionalLight(0xffffff, 1);
light.castShadow = true;

// Shadow map resolution
light.shadow.mapSize.width = 2048;
light.shadow.mapSize.height = 2048;

// Tight frustum for better resolution
const d = 50;
light.shadow.camera.left = -d;
light.shadow.camera.right = d;
light.shadow.camera.top = d;
light.shadow.camera.bottom = -d;
light.shadow.camera.near = 0.5;
light.shadow.camera.far = 500;

// Bias to prevent shadow acne
light.shadow.bias = -0.0005;
```

### Cascaded Shadow Maps (CSM)

For large outdoor scenes:

```typescript
import { CSM } from 'three/examples/jsm/csm/CSM.js';

const csm = new CSM({
  maxFar: 1000,
  cascades: 4,
  shadowMapSize: 2048,
  lightDirection: new THREE.Vector3(-1, -1, -1).normalize(),
  camera: camera,
  parent: scene
});

// Update in render loop
csm.update();
```

### Contact Shadows

For soft grounded shadows:

```typescript
import { ContactShadows } from '@react-three/drei'; // R3F
// Or implement custom: render objects from above onto plane with blur
```

## PBR Materials

### MeshStandardMaterial

```typescript
const material = new THREE.MeshStandardMaterial({
  color: 0xffffff,
  map: albedoTexture,
  normalMap: normalTexture,
  roughnessMap: roughnessTexture,
  metalnessMap: metalnessTexture,
  aoMap: aoTexture,
  aoMapIntensity: 1.0,
  envMapIntensity: 1.0
});
```

### MeshPhysicalMaterial Extensions

```typescript
const carPaint = new THREE.MeshPhysicalMaterial({
  color: 0xff0000,
  metalness: 0.9,
  roughness: 0.1,
  clearcoat: 1.0,
  clearcoatRoughness: 0.1
});

const glass = new THREE.MeshPhysicalMaterial({
  transmission: 1.0,
  thickness: 0.5,
  roughness: 0.0,
  ior: 1.5
});

const fabric = new THREE.MeshPhysicalMaterial({
  sheen: 1.0,
  sheenColor: new THREE.Color(0x0000ff),
  sheenRoughness: 0.5
});
```

## Special Material Effects

### Effect Mapping

| Want | Use |
|------|-----|
| Car paint | Clearcoat + metalness |
| Glass | Transmission + IOR |
| Velvet/cloth | Sheen |
| Wet surfaces | Clearcoat (water layer) |
| Chrome | Metalness=1, roughness=0, envMap |
| Brushed metal | Custom anisotropy shader or normal map |
| Subsurface (skin) | Transmission + thickness hack |

### Fresnel Glow (Custom)

```typescript
material.onBeforeCompile = (shader) => {
  shader.fragmentShader = shader.fragmentShader.replace(
    '#include <output_fragment>',
    `
    float fresnel = pow(1.0 - dot(normal, viewDir), 3.0);
    gl_FragColor.rgb += vec3(0.0, 0.5, 1.0) * fresnel * 0.5;
    #include <output_fragment>
    `
  );
};
```

## Atmospheric Effects

### Fog

```typescript
// Linear fog
scene.fog = new THREE.Fog(0xcccccc, 10, 100);

// Exponential fog
scene.fog = new THREE.FogExp2(0xcccccc, 0.02);
```

### God Rays

```typescript
import { GodRaysPass } from 'three/examples/jsm/postprocessing/GodRaysPass.js';

// Position light mesh where sun is
const sunMesh = new THREE.Mesh(
  new THREE.SphereGeometry(1),
  new THREE.MeshBasicMaterial({ color: 0xffff00 })
);

const godRaysPass = new GodRaysPass(scene, camera, sunMesh, {
  density: 1.0,
  decay: 0.95,
  weight: 0.5
});
composer.addPass(godRaysPass);
```

### Sky Shader

```typescript
import { Sky } from 'three/examples/jsm/objects/Sky.js';

const sky = new Sky();
sky.scale.setScalar(10000);
scene.add(sky);

const skyUniforms = sky.material.uniforms;
skyUniforms['turbidity'].value = 10;
skyUniforms['rayleigh'].value = 2;
skyUniforms['mieCoefficient'].value = 0.005;
skyUniforms['mieDirectionalG'].value = 0.8;

// Sun position
const sun = new THREE.Vector3();
const phi = THREE.MathUtils.degToRad(90 - elevation);
const theta = THREE.MathUtils.degToRad(azimuth);
sun.setFromSphericalCoords(1, phi, theta);
skyUniforms['sunPosition'].value.copy(sun);
```

### Dithering

Prevent banding in gradients:

```typescript
material.dithering = true;
```
