
const canvas = document.querySelector('canvas');
// Note: may soon try using webgl for this, but just using canvas2d for now
const ctx = canvas.getContext('2d', { antialias: false });

// Number of boids
// The program currently does not support changing this at run time
const count = 500;

// TODO: this defines one page of memory for wasm to use (64KB)
// 16B used statically and each boid needs 16B so one page only
// will hold 4094 boids, which is way way more than what my machine
// can handle updating the logic for, but it won't be hard to fix
const memory = new WebAssembly.Memory({initial:1, maximum:1});
let wasmUpdate;

// Views to memory buffer
const velocities = new Float32Array(memory.buffer, 32, count*2)
const positions = new Float32Array(memory.buffer, 32 + count*8, count*2)

// Loads a wasm instance from its path and an import object
// TODO: investigate using recommended instantiateStreaming method
async function loadWasm(path, importObj) {
  const resp = await fetch(path);
  const buf = await resp.arrayBuffer();
  const module = await WebAssembly.compile(buf);
  return new WebAssembly.Instance(module, importObj);
}


function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = 'lightgrey';

  for(let i=0; i<count*2; i+=2) {
    const halfWidth = 2;
    const height = 8;

    const angle = Math.atan2(velocities[i+1], velocities[i]);
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);

    ctx.beginPath();
    ctx.moveTo(-sin*halfWidth + positions[i], cos*halfWidth + positions[i+1]);
    ctx.lineTo(sin*halfWidth + positions[i], -cos*halfWidth + positions[i+1]);
    ctx.lineTo(cos*height + positions[i], sin*height + positions[i+1]);
    ctx.lineTo(-sin*halfWidth + positions[i], cos*halfWidth + positions[i+1]);
    ctx.fill();
    ctx.stroke();
  }
}

function resize() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  draw();
}

function update() {
  // TODO shouldn't need to pass in boid count
  // Make a function to set it once so it doesn't need to be done every frame
  // The program does not currently support changing count of boids
  wasmUpdate(count, canvas.width, canvas.height);

  draw();

  window.requestAnimationFrame(update);
}

function init() {

  window.addEventListener('resize', resize);

  const log = a => console.log(a);
  const log2 = (a,b) => console.log(a,b);

  loadWasm("flock.wasm", {env: {mem: memory, log, log2}})
    .then(instance => {
      wasmUpdate = instance.exports['update'];

      for(let i=0; i<count*2; i+=2) {
        positions[i] = Math.random()*window.innerWidth;
        positions[i+1] = Math.random()*window.innerHeight;
      }

      update();
      resize();
    });
}

init();
