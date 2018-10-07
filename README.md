# wasm-boids
Demonstration of webassembly using classic boids simulation

Check it out [here!](https://nickgirardo.github.io/animation-tests/wasm-boids/)

## Building
The only processing which needs to be done on this is compiling `flock.wat` which is WebAssembly text format to the binary representation of WebAssembly.
Furthermore, since this file was handwritten, I would highly advise running an optimizer on the output.

A build script, `build.sh`, is included in the repository.
It depends on `wat2wasm` to compile the text representation to the binary representation and `wasm-opt` to optimize the output binary.

- `wat2wasm` is part of wabt and can be found at [WebAssembly/wabt](https://github.com/WebAssembly/wabt)
- `wasm-opt` is part of binaryen and can be found at [WebAssembly/binaryen](https://github.com/WebAssembly/binaryen)

However, keep in mind `wat2wasm` can be replaced by any such tool and `wasm-opt` is optional.

Make sure the output file is in the same directory as the other files and named `flock.wasm`.

## Running
Once `flock.wasm` has been created, any simple http-server can deliver this demonstration, as it is static.

## Motivation
I created this because I was interested in learning about running non-js code in the browser.
I figured this would be a good starting point for a number of reasons.

To begin with, I was already somewhat familiar with the boids simulation.
This meant I could concentrate more on the process of writing and executing wasm and less on the details of the simulation.

With a sufficient amount of boids, the simulation is fairly demanding on a processor.
Inital js tests left me with abysmall performance.
With this in mind, I would be able to get a feel for how much of a boon to performance wasm could be.
I am able to hit 60 fps with a faily straightforward algorithm on flock of 500 boids on my laptop from 2012, which I feel happy about.

Furthermore, the simulation itself is interesting, both from a visual standpoint and considering how such simple rules can create such captivating behavior.

## Brief Retrospective
Interfacing between the js and the wasm was much more painless than I had expected at the outset.
After simple setup, being able to call the wasm functions as if they were js functions was great, as was having unfettered access to the wasm memory buffer from the js side.

I feel that this simulation is a somewhat ideal use case for wasm: heavy simulations with very little calling between the wasm and js side.
I read that crossing the barrier between js and wasm will cause performance to take a serious hit.
Fortunately, I only make exactly one call from js to wasm per frame and the wasm never needs to call out to js (except for logging during development).

While I am quite happy with what I have made, I have some notable misgivings which primarly are caused by my decision to write the wasm text representation by hand.

Wasm does not have much defined from the outset, so if you are writing in it directly as I was, be prepared to write many small utility functions (I wrote a mod function for instance) or calling out to the browser's functions.
I could see this becoming more of an issue if you needed to make use of a lot of trigonometric functions.

I found the debugging and testing enviornment left a lot to be desired.
Firefox's fantastic debugging tools were largely useless for finding issues that came up while writing wasm.
I was unable to find any information regarding something like sourcemaps for wasm, nor could I find a step through debugger.
I wasn't able to find specific testing tools either.
For a project as small as mine, this wasn't too much of an issue, but I could see this becoming greatly frustrating on any more serious projects.

Hopefully these issues could be sidestepped if you were writing in a more high-level language compiled to wasm, but writing in the text format was a frustrating experience.
I would absolutely recommend avoiding writing wasm text format directly with the exception of learning projects (such as this).

## Issues

I am aware this simulation is imperfect, but it is good enough for the purposes I had in mind for it.

Constants (e.g. boid friction, the effectiveness of each of the three rules) are primarily hardcoded, although I made sure to thoroughly comment when I did so.

Boids are updated as the simulation advances, meaning that some boids will have the previous frame values and some will have the next frame values at any given point in time.
I decided to leave this unchanged as it wasn't causing any real issues, but it should be kept in mind.
