; ======== Interface ========
; Add sliders:
;   N (100)  speed-max (1.0)  dt (0.2)
;   mc  ms  ml  mg  mo  (0–2)
;   dc  da  dl  de  (1–12)
;   panic-smooth (0–1, e.g., 0.5)
; Add switch: show-vectors?
; Add button: setup / go (forever)

; ======== Globals & Breeds ========
globals [
  goal-pos               ; global goal (e.g., exit) as a patch coordinate
  vmax                   ; speed cap
]

breed [ agents agent ]
breed [ obstacles obstacle ]  ; each obstacle is a patch-sized blocker (simple)

agents-own [
  r w                    ; radius, weight (not used in forces here but kept)
  v                      ; current velocity vector (list [vx vy])
  gamma                  ; panic level in [0,1]
  ease-dist              ; l_i (max acceptable door distance before panic rises)
  ; behavior radii
  dc da dl de
  ; weights (refinement factors)
  mc ms ml mg mo
]

; ======== Setup ========
to setup
  clear-all
  resize-world -30 30 -30 30
  set-patch-size 10
  set vmax speed-max
  set goal-pos one-of patches with [ pxcor = max-pxcor ]  ; right edge = exit

  ; simple obstacles strip (optional)
  ask n-of 80 patches with [ pxcor > -5 and pxcor < 5 and pycor mod 3 = 0 ] [
    sprout-obstacles 1 [ set shape "box" set color gray set size 1.2 ]
  ]

  crt N [
    set breed agents
    setxy random-xcor random-ycor
    set color blue
    set size 1.2
    ; attributes (you can randomize if you want)
    set r 0.5
    set w 70
    set v list (random-float 1 - 0.5) (random-float 1 - 0.5)
    set gamma random-float 0.1
    set ease-dist 15
    ; radii
    set dc dc
    set da da
    set dl dl
    set de de
    ; weights
    set mc mc
    set ms ms
    set ml ml
    set mg mg
    set mo mo
  ]

  reset-ticks
end

; ======== Main loop ========
to go
  ; compute new velocity for each agent
  ask agents [
    let v-goal goal-component
    let v-coh  cohesion-component
    let v-sep  separation-component
    let v-ali  alignment-component
    let v-obs  obstacle-component

    ; weighted sum (panic can modulate weights if you want: e.g., mg*(1-gamma) or mc*(gamma))
    let v-new  v-plus v-goal     mg
    set v-new  v-plus v-new      v-coh  mc
    set v-new  v-plus v-new      v-sep  ms
    set v-new  v-plus v-new      v-ali  ml
    set v-new  v-plus v-new      v-obs  mo

    ; cap speed
    set v limit-speed v-new vmax

    ; update panic BEFORE moving (you can do after; choose one and be consistent)
    update-panic

    ; move
    let pxy list xcor ycor
    let pnext v-scale-add pxy v dt
    ; keep inside world
    ifelse can-move-to (item 0 pnext) (item 1 pnext)
    [ setxy (item 0 pnext) (item 1 pnext) ]
    [ ; if blocked by world boundary: damp velocity
      set v v-scale v 0.2
    ]

    ; optionally draw heading vector
    if show-vectors? [
      let endx xcor + (item 0 v) * 2
      let endy ycor + (item 1 v) * 2
      set color blue
      pen-down set pen-size 1
      setxy endx endy
      pen-up
      setxy (item 0 pnext) (item 1 pnext)
    ]
  ]

  ; stop when near the goal
  if count agents with [ distancexy (pxcor goal-pos) (pycor goal-pos) < 2 ] = count agents [
    stop
  ]

  tick
end

; ======== Components ========

to-report goal-component
  ; toward the exit (goal-pos)
  let gx pxcor goal-pos
  let gy pycor goal-pos
  let dir vector-to gx gy
  report unit dir
end

to-report cohesion-component
  ; towards centroid of neighbors within dc (excluding self)
  let ns other agents in-radius dc
  if any? ns [
    let cx mean [ xcor ] of ns
    let cy mean [ ycor ] of ns
    report unit (vector-to cx cy)
  ]
  report list 0 0
end

to-report separation-component
  ; away from agents closer than da
  let ns other agents in-radius da
  if any? ns [
    let away list 0 0
    foreach ns [
      ask ? [
        set away v-add away (unit (vector-from [xcor] of myself [ycor] of myself xcor ycor))
      ]
    ]
    report unit away
  ]
  report list 0 0
end

to-report alignment-component
  ; align with mean velocity of neighbors within dl
  let ns other agents in-radius dl
  if any? ns [
    let vx mean [ item 0 v ] of ns
    let vy mean [ item 1 v ] of ns
    ; steer toward neighbors' mean velocity relative to own
    report v-sub (list vx vy) v
  ]
  report list 0 0
end

to-report obstacle-component
  ; steer away from obstacles within de
  let obs obstacles in-radius de
  if any? obs [
    let away list 0 0
    foreach obs [
      ask ? [
        set away v-add away (unit (vector-from [xcor] of myself [ycor] of myself xcor ycor))
      ]
    ]
    report unit away
  ]
  report list 0 0
end

; ======== Panic update γ_i(t) ========
to update-panic
  ; δ1: distance to goal vs ease distance
  let gx pxcor goal-pos
  let gy pycor goal-pos
  let D distancexy gx gy
  let L max (list world-width world-height) ; scene scale
  let delta1 (D - ease-dist) / L
  if delta1 < 0 [ set delta1 0 ]

  ; δ2: mismatch in direction with neighbors moving to exits (approx via velocity alignment error)
  let ns other agents in-radius dl
  let delta2 0
  if any? ns [
    let vmean list 0 0
    set vmean list (mean [ item 0 v ] of ns) (mean [ item 1 v ] of ns)
    let mis v-mag (v-sub vmean v)
    set delta2 mis / vmax
  ]

  ; δ3: fraction of nearby agents in discomfort (use speed < 0.2*vmax as proxy)
  let nsC other agents in-radius dc
  let delta3 0
  if any? nsC [
    set delta3 (count nsC with [ v-mag v < 0.2 * vmax ]) / (count nsC)
  ]

  ; δ4: lag in speed (slower than local min or target)
  let vmin vmax
  if any? ns [ set vmin min (list vmin [ v-mag v ] of ns) ]
  let delta4 max list 0 ((vmin - v-mag v) / vmax)

  let zeta ( (delta1 + delta2 + delta3 + delta4) / 4 )
  set gamma ((1 - panic-smooth) * gamma + panic-smooth * zeta)
  set gamma max list 0 (min list 1 gamma)
end

; ======== Vector helpers ========
to-report v-add [a b]       report list (item 0 a + item 0 b) (item 1 a + item 1 b) end
to-report v-sub [a b]       report list (item 0 a - item 0 b) (item 1 a - item 1 b) end
to-report v-scale [a s]     report list (item 0 a * s) (item 1 a * s) end
to-report v-scale-add [p v s]
  report list (item 0 p + item 0 v * s) (item 1 p + item 1 v * s)
end
to-report v-mag [a]         report sqrt ((item 0 a) ^ 2 + (item 1 a) ^ 2) end
to-report unit [a]
  let m v-mag a
  if m = 0 [ report list 0 0 ]
  report list ((item 0 a) / m) ((item 1 a) / m)
end
to-report limit-speed [a s]
  let m v-mag a
  if m > s [ report v-scale (unit a) s ]
  report a
end
to-report vector-to [tx ty]
  report list (tx - xcor) (ty - ycor)
end
to-report vector-from [sx sy tx ty]
  ; vector pointing from (sx,sy) to (tx,ty) (used for separation/obstacles)
  report list (sx - tx) (sy - ty)
end

; ======== Utility ========
to-report can-move-to [nx ny]
  report (nx > min-pxcor) and (nx < max-pxcor) and (ny > min-pycor) and (ny < max-pycor)
end
