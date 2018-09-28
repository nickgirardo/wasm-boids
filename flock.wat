
;; Memory layout
;; 0x0000 Current boid acceleration
;; 0x0008 Current boid working field [seperation, cohesion, alignment]
;; 0x0010 Working field
;; 0x0018 Working field
;; 0x0020 Start of boid specific memory
;;  0x0020+(i*8) Velocity for boid i
;;  0x0020+(count*8)+(i*8) Position for boid i
;;    Note: 0x0020+(count*8) is set as global $pos_head

(module
  (memory (import "env" "mem") 1)
  (import "env" "log"
    (func $logf (param f32))
  )
  (import "env" "log"
    (func $logi (param i32))
  )
  (import "env" "log2"
    (func $log2f (param f32) (param f32))
  )
  (global $count (mut i32) (i32.const 0))
  (global $pos_head (mut i32) (i32.const 0))

  ;; Returns location of velocity for given boid
  (func $vel
    (param $i i32)
    (result i32)

    (i32.add
      (i32.const 32)
      (i32.mul
        (get_local $i)
        (i32.const 8)
      )
    )
  )

  ;; Returns location of position for given boid
  (func $pos
    (param $i i32)
    (result i32)

    (i32.add
      (get_global $pos_head)
      (i32.mul
        (get_local $i)
        (i32.const 8)
      )
    )
  )

  ;; SECTION Math functions!
  ;; Adding as needed

  ;; Float modulus function
  ;; result = x - y*floor(x/y)
  ;; Note: this differs with reference to fmod by the sign of the result
  ;; fmod's output keeps the sign of $x, whereas this should keep the sign of $y
  (func $math_mod
    (param $x f32)
    (param $y f32)

    (result f32)

    (f32.sub
      (get_local $x)
      (f32.mul
        (f32.floor
          (f32.div (get_local $x) (get_local $y))
        )
        (get_local $y)
      )
    )
  )

  ;; SECTION Vector functions!
  ;; Adding as needed

  (func $vec2_print
    (param $loc i32)

    (call $log2f (f32.load (get_local $loc)) (f32.load (i32.add (i32.const 4) (get_local $loc))))
  )

  ;; Zero
  ;; Zeros a given vector
  (func $vec2_zero
    (param $loc i32)

    ;; Trying to be clever and save a bit of time here
    ;; TODO: if anything breaks check here
    ;; TODO: keep an eye on perf here
    (f64.store (get_local $loc) (f64.const 0))
  )

  ;; Add
  ;; Adds two vectors
  ;; Result is written to $out
  (func $vec2_add
    (param $out i32)
    (param $a i32)
    (param $b i32)

    ;; Add the two first components of each vector
    (f32.store
      (get_local $out)
      (f32.add
        (f32.load (get_local $a))
        (f32.load (get_local $b))
      )
    )

    ;; Add the two second components of each vector
    (f32.store
      (i32.add
        (get_local $out)
        (i32.const 4)
      )
      (f32.add
        (f32.load 
          (i32.add
            (get_local $a)
            (i32.const 4)
          )
        )
        (f32.load 
          (i32.add
            (get_local $b)
            (i32.const 4)
          )
        )
      )
    )
  )

  ;; Sub
  ;; Subtracts two vectors
  ;; Result is written to $out
  (func $vec2_sub
    (param $out i32)
    (param $a i32)
    (param $b i32)

    ;; Subtract the two first components of each vector
    (f32.store
      (get_local $out)
      (f32.sub
        (f32.load (get_local $a))
        (f32.load (get_local $b))
      )
    )

    ;; Subtract the two second components of each vector
    (f32.store
      (i32.add
        (get_local $out)
        (i32.const 4)
      )
      (f32.sub
        (f32.load 
          (i32.add
            (get_local $a)
            (i32.const 4)
          )
        )
        (f32.load 
          (i32.add
            (get_local $b)
            (i32.const 4)
          )
        )
      )
    )
  )

  ;; Length
  ;; Returns the length (magnitude) of a given vector
  (func $vec2_length
    (param $in i32)
    (result f32)

    (f32.sqrt
      (f32.add
        (f32.mul
          (f32.load (get_local $in))
          (f32.load (get_local $in))
        )
        (f32.mul
          (f32.load
            (i32.add
              (get_local $in)
              (i32.const 4)
            )
          )
          (f32.load
            (i32.add
              (get_local $in)
              (i32.const 4)
            )
          )
        )
      )
    )
  )

  ;; Normalize
  ;; Returns a normalized vector (i.e. a unit vector in the direction of the given vector)
  ;; Writes the input to the given location
  ;; TODO confirm behaviour is as desired for zero vectors
  (func $vec2_normalize
    (param $out i32)
    (param $in i32)

    (local $len f32)

    ;; First calculate length
    (set_local $len
      (f32.sqrt
        (f32.add
          (f32.mul
            (f32.load (get_local $in))
            (f32.load (get_local $in))
          )
          (f32.mul
            (f32.load
              (i32.add
                (get_local $in)
                (i32.const 4)
              )
            )
            (f32.load
              (i32.add
                (get_local $in)
                (i32.const 4)
              )
            )
          )
        )
      )
    )


    ;; For each component, store len*in if len > 0, otherwise store 0
    ;; len should only be <= 0 for zero vectors

    (block $zero
      (br_if
        $zero
        (f32.le (get_local $len) (f32.const 0))
      )

      ;; Invert $len
      (set_local $len (f32.div (f32.const 1) (get_local $len)))

      ;; First component
      (f32.store
        (get_local $out)
        (f32.mul
          (f32.load (get_local $in))
          (get_local $len)
        )
      )

      ;; Second component
      (f32.store
        (i32.add (get_local $out) (i32.const 4))
        (f32.mul
          (f32.load 
            (i32.add (get_local $in) (i32.const 4))
          )
          (get_local $len)
        )
      )

    )
  )

  ;; Scale
  ;; Scales the vector at location $in by $amount
  ;; Result is written to $out
  (func $vec2_scale
    (param $out i32)
    (param $in i32)
    (param $amount f32)

    ;; Scale first float of vector
    (f32.store
      (get_local $out)
      (f32.mul
        (f32.load (get_local $in))
        (get_local $amount)
      )
    )

    ;; Scale second float of vector
    (f32.store
      (i32.add
        (get_local $out)
        (i32.const 4)
      )
      (f32.mul
        (f32.load 
          (i32.add
            (get_local $in)
            (i32.const 4)
          )
        )
        (get_local $amount)
      )
    )
  )

  ;; Scale and add
  ;; Adds two vectors after scaling the second by some amount
  ;; Result is written to $out
  (func $vec2_scale_and_add
    (param $out i32)
    (param $a i32)
    (param $b i32)
    (param $amount f32)

    ;; Working on first float of vector pair
    (f32.store
      (get_local $out)
      (f32.add
        (f32.load (get_local $a))
        (f32.mul
          (f32.load (get_local $b))
          (get_local $amount)
        )
      )
    )

    (f32.store
      (i32.add (get_local $out) (i32.const 4))
      (f32.add
        (f32.load (i32.add (get_local $a) (i32.const 4)))
        (f32.mul
          (f32.load (i32.add (get_local $b) (i32.const 4)))
          (get_local $amount)
        )
      )
    )
  )

  (func (export "update")
    (param $count i32)
    (param $max_x f32)
    (param $max_y f32)

    (local $current i32)

    ;; TODO: set elsewhere to avoid resetting every frame
    ;; This is unchanging as we assume that the amount of boids must not change
    (set_global $pos_head
      (i32.add
        (i32.const 32)
        (i32.mul
          (get_local $count)
          (i32.const 8)
        )
      )
    )

    (set_global $count (get_local $count))

    (set_local $current (i32.const 0))

    (block $break
      (loop $top
        (br_if
          $break
          (i32.eq (get_local $current) (get_local $count))
        )

        ;; This stores the result of seperation at memory location 8
        (call $seperation (get_local $current))

        (call $vec2_scale
          (i32.const 0) ;; Output to acceleration
          (i32.const 8) ;; Input from result of $seperation
          (f32.const 0.08) ;; Effectiveness of seperation, hardcoded for now
        )

        ;; This stores the result of cohesion at memory location 8
        (call $cohesion (get_local $current))

        (call $vec2_scale_and_add
          (i32.const 0) ;; Output to acceleration
          (i32.const 0) ;; Input, currently calculated acceleration
          (i32.const 8) ;; Input from result of $cohesion
          (f32.const 0.01) ;; Effectiveness of cohesion, hardcoded for now
        )

        ;; This stores the result of alignment at memory location 8
        (call $alignment (get_local $current))

        (call $vec2_scale_and_add
          (i32.const 0) ;; Output to acceleration
          (i32.const 0) ;; Input, currently calculated acceleration
          (i32.const 8) ;; Input from result of $alignment
          (f32.const 0.4) ;; Effectiveness of alignment, hardcoded for now
        )

        ;; add the calculated acceleration to the current vector's velocity
        (call $vec2_add
          (call $vel (get_local $current))
          (call $vel (get_local $current))
          (i32.const 0)
        )

        ;; Apply friction to velocity
        (call $vec2_scale
          (call $vel (get_local $current))
          (call $vel (get_local $current))
          (f32.const 0.9) ;; Friction amount, hardcoded for now
        )

        ;; Add calculated velocity to position
        (call $vec2_add
          (call $pos (get_local $current))
          (call $pos (get_local $current))
          (call $vel (get_local $current))
        )

        ;; Wrap around at edges
        (f32.store
          (call $pos (get_local $current))
          (call $math_mod
            (f32.load (call $pos (get_local $current)))
            (get_local $max_x)
          )
        )
        (f32.store
          (i32.add (call $pos (get_local $current)) (i32.const 4))
          (call $math_mod
            (f32.load (i32.add (call $pos (get_local $current)) (i32.const 4)))
            (get_local $max_y)
          )
        )

        (set_local $current (i32.add (get_local $current) (i32.const 1)))

        (br $top)
      )
    )
  )

  (func $seperation
    (param $current i32)

    (local $other i32)
    (local $neighbors i32)
    (local $dist f32)

    ;; For averaging, increments as we add neighbors
    (set_local $neighbors (i32.const 0))

    ;; Index of the boid we are comparing the current against
    (set_local $other (i32.const -1))

    ;; Zero acc
    ;; Diff doesn't need to be zeroed because it will be written to before read
    (call $vec2_zero (i32.const 24))

    (block $break
      (loop $top

        ;; Increment before rest of loop in case we exited early
        (set_local $other (i32.add (get_local $other) (i32.const 1)))
        
        ;; Break from loop if finished iterating boids
        (br_if
          $break
          (i32.eq (get_local $other) (get_global $count))
        )

        ;; Don't compare the current boid against itself
        (br_if
          $top
          (i32.eq (get_local $other) (get_local $current))
        )

        ;; Get difference between boids
        (call $vec2_sub
          (i32.const 16)
          (call $pos (get_local $current))
          (call $pos (get_local $other))
        )

        (set_local $dist
          (call $vec2_length (i32.const 16))
        )

        ;; Too far, next boid
        ;; Neighborhood size for seperation is 20, hardcoded for now
        (br_if
          $top
          (f32.gt (get_local $dist) (f32.const 20.0)) 
        )

        ;; Increment count of neighbors
        (set_local
          $neighbors
          (i32.add (get_local $neighbors) (i32.const 1))
        )

        (call $vec2_add
          (i32.const 24)
          (i32.const 24)
          (i32.const 16)
        )

        (br $top)
      )
    )


    ;; Non-zero neighbors case
    (block $no_neighbors
      (br_if
        $no_neighbors
        (i32.eqz (get_local $neighbors))
      )
      (call $vec2_scale
        (i32.const 24)
        (i32.const 24)
        (f32.div
          (f32.const 1)
          (f32.convert_s/i32 (get_local $neighbors))
        )
      )

      (call $vec2_sub
        (i32.const 8)
        (i32.const 24)
        (call $vel (get_local $current))
      )
      (return)
    )

    ;; Zero neighbors case
    (call $vec2_zero (i32.const 8))

  )

  (func $cohesion
    (param $current i32)

    (local $other i32)
    (local $neighbors i32)
    (local $dist f32)

    ;; For averaging, increments as we add neighbors
    (set_local $neighbors (i32.const 0))

    ;; Index of the boid we are comparing the current against
    (set_local $other (i32.const -1))

    ;; Zero acc
    ;; Diff doesn't need to be zeroed because it will be written to before read
    (call $vec2_zero (i32.const 24))

    (block $break
      (loop $top

        (set_local $other (i32.add (get_local $other) (i32.const 1)))

        ;; Break from loop if finished iterating boids
        (br_if
          $break
          (i32.eq (get_local $other) (get_global $count))
        )

        ;; Don't compare the current boid against itself
        (br_if
          $top
          (i32.eq (get_local $other) (get_local $current))
        )

        ;; Get difference between boids
        (call $vec2_sub
          (i32.const 16)
          (call $pos (get_local $current))
          (call $pos (get_local $other))
        )

        (set_local $dist
          (call $vec2_length (i32.const 16))
        )

        ;; Too far, next boid
        ;; Neighborhood size for cohesion is 60, hardcoded for now
        (br_if
          $top
          (f32.gt (get_local $dist) (f32.const 60.0)) 
        )

        ;; Increment count of neighbors
        (set_local
          $neighbors
          (i32.add (get_local $neighbors) (i32.const 1))
        )

        (call $vec2_add
          (i32.const 24)
          (i32.const 24)
          (call $pos (get_local $other))
        )

        (br $top)
      )
    )

    ;; Non-zero neighbors case
    (block $no_neighbors
      (br_if
        $no_neighbors
        (i32.eqz (get_local $neighbors))
      )
      (call $vec2_scale
        (i32.const 24)
        (i32.const 24)
        (f32.div
          (f32.const 1)
          (f32.convert_s/i32 (get_local $neighbors))
        )
      )

      (call $vec2_sub
        (i32.const 8)
        (i32.const 24)
        (call $pos (get_local $current))
      )
      (return)
    )

    ;; Zero neighbors case
    (call $vec2_zero (i32.const 8))

  )

  ;; 0x0010 (16) (diff) keeps track of distance between boids
  ;; 0x0018 (24) (acc) is accumulator
  (func $alignment
    (param $current i32)

    (local $other i32)
    (local $neighbors i32)
    (local $dist f32)

    ;; For averaging, increments as we add neighbors
    (set_local $neighbors (i32.const 0))

    ;; Index of the boid we are comparing the current against
    (set_local $other (i32.const -1))

    ;; Zero acc
    ;; Diff doesn't need to be zeroed because it will be written to before read
    (call $vec2_zero (i32.const 24))

    (block $break
      (loop $top

        (set_local $other (i32.add (get_local $other) (i32.const 1)))

        ;; break from loop if finished iterating over boids
        (br_if
          $break
          (i32.eq (get_local $other) (get_global $count))
        )

        ;; Don't compare the current boid against itself
        (br_if
          $top
          (i32.eq (get_local $other) (get_local $current))
        )

        ;; Get difference between boids
        (call $vec2_sub
          (i32.const 16)
          (call $pos (get_local $current))
          (call $pos (get_local $other))
        )

        ;; Get distance between boids
        (set_local $dist
          (call $vec2_length (i32.const 16))
        )

        ;; Too far, next boid
        ;; Neighborhood size for alignment is 60, hardcoded for now
        (br_if
          $top
          (f32.gt (get_local $dist) (f32.const 60.0)) 
        )

        ;; Increment amount of neighbors
        (set_local
          $neighbors
          (i32.add (get_local $neighbors) (i32.const 1))
        )

        ;; Add other boids velocity to acc
        (call $vec2_add
          (i32.const 24)
          (i32.const 24)
          (call $vel (get_local $other))
        )

        (br $top)
      )
    )

    ;; Non-zero neighbors case
    (block $no_neighbors
      (br_if
        $no_neighbors
        (i32.eqz (get_local $neighbors))
      )
      (call $vec2_normalize (i32.const 8) (i32.const 24))
      (return)
    )

    ;; Zero neighbors case
    (call $vec2_zero (i32.const 8))
          
  )
)






