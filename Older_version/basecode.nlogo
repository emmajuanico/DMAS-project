; ==========
; Agent-based Evacuation Model with Panic (Starter)
; ==========

globals [ goal-pos vmax ]

breed [people person]
breed [obstacles obstacle]

people-own [
  r
  weight
  velocity
  gamma
  ease-dist
  dc da dl de
  mc ms ml mg mo
]

; ==========
; SETUP
; ==========
to setup
  clear-all
  resize-world -30 30 -30 30
  set-patch-size 10
  set vmax speed-max
  set goal-pos one-of patches with [ pxcor = max-pxcor ]   ;; exit at right edge

  ;; Optional: obstacles in the center strip
  ask n-of 80 patches with [ pxcor > -5 and pxcor < 5 and pycor mod 3 = 0 ] [
    sprout-obstacles 1 [
      set shape "box"
      set color gray
      set size 1.2
    ]
  ]

  ;; create people
  create-people N [
    setxy random-xcor random-ycor
    set color blue
    set size 1.2
    set r 0.5
    set weight 70
    set velocity (list (random-float 1 - 0.5) (random-float 1 - 0.5))
    set gamma random-float 0.1
    set ease-dist 15
    ;; radii
    set dc dc
    set da da
    set dl dl
    set de de
    ;; weights
    set mc mc
    set ms ms
    set ml ml
    set mg mg
    set mo mo
  ]

  reset-ticks
end

; ==========
; MAIN LOOP
; ==========
to go
  ask people [
    let v-goal goal-component
    let v-coh  cohesion-component
    let v-sep  separation-component
    let v-ali  alignment-component
    let v-obs  obstacle-component

    ;; Weighted sum of components
    let v-new v-plus (list 0 0) v-goal mg
    set v-new v-plus v-new v-coh mc
    set v-new v-plus v-new v-sep ms
    set v-new v-plus v-new v-ali ml
    set v-new v-plus v-new v-obs mo

    ;; Limit speed
    set velocity limit-speed v-new vmax

    ;; Update panic
    update-panic

    ;; Move
    let pnext v-scale-add (list xcor ycor) velocity dt
    ifelse can-move-to (item 0 pnext) (item 1 pnext)
    [ setxy (item 0 pnext) (item 1 pnext) ]
    [ set velocity v-scale velocity 0.2 ]  ;; damp if out of bounds

    ;; Optional: draw velocity arrows (add a switch named show-vectors? on Interface)
    if show-vectors? [
      let endx xcor + (item 0 velocity) * 2
      let endy ycor + (item 1 velocity) * 2
      set color blue
      pen-down set pen-size 1
      setxy endx endy
      pen-up
      setxy (item 0 pnext) (item 1 pnext)
    ]
]
  ;; Stop if everyone is near the exit
  if count people with [ distancexy ([pxcor] of goal-pos) ([pycor] of goal-pos) < 2 ]
    = count people
[
  stop
]

  tick
end

; ==========
; BEHAVIOR COMPONENTS
; ==========
to-report goal-component
  let gx [pxcor] of goal-pos
  let gy [pycor] of  goal-pos
  report unit (vector-to gx gy)
end

to-report cohesion-component
  let ns other people in-radius dc
  if any? ns [
    let cx mean [ xcor ] of ns
    let cy mean [ ycor ] of ns
    report unit (vector-to cx cy)
  ]
  report list 0 0
end

to-report separation-component
  let ns other people in-radius da
  if any? ns [
    let away list 0 0
    foreach sort ns [ neighbor ->
      ask neighbor [
        ;; vector from neighbor to me (i.e., away from neighbor)
        set away v-add away (unit (vector-from [xcor] of myself [ycor] of myself xcor ycor))
      ]
    ]
    report unit away
  ]
  report list 0 0
end


to-report alignment-component
  let ns other people in-radius dl
  if any? ns [
    let vx mean [ item 0 velocity ] of ns
    let vy mean [ item 1 velocity ] of ns
    report v-sub (list vx vy) velocity
  ]
  report list 0 0
end

to-report obstacle-component
  let obs obstacles in-radius de
  if any? obs [
    let away list 0 0
    foreach sort obs [ ob ->
      ask ob [
        set away v-add away (unit (vector-from [xcor] of myself [ycor] of myself xcor ycor))
      ]
    ]
    report unit away
  ]
  report list 0 0
end


; ==========
; PANIC UPDATE
; ==========
to update-panic
  ;; δ1: distance to goal vs ease distance
  let gx [pxcor] of goal-pos
  let gy [pycor] of goal-pos
  let D distancexy gx gy
  let L max (list world-width world-height)
  let delta1 max list 0 ((D - ease-dist) / L)

  ;; δ2: mismatch with neighbors
  let ns other people in-radius dl
  let delta2 0
  if any? ns [
    let vmean list (mean [ item 0 velocity ] of ns) (mean [ item 1 velocity ] of ns)
    let mis v-mag (v-sub vmean velocity)
    set delta2 mis / vmax
  ]

  ;; δ3: neighbors in discomfort (proxy: very slow agents)
  let nsC other people in-radius dc
  let delta3 0
  if any? nsC [
    set delta3 (count nsC with [ v-mag velocity < 0.2 * vmax ]) / (count nsC)
  ]

  ;; δ4: lagging compared to local min speed
  let vmin vmax
  if any? ns [ set vmin min (list vmin [ v-mag velocity ] of ns) ]
  let delta4 max list 0 ((vmin - v-mag velocity) / vmax)

  ;; Combine
  let zeta ((delta1 + delta2 + delta3 + delta4) / 4)
  set gamma ((1 - panic-smooth) * gamma + panic-smooth * zeta)
  set gamma max list 0 (min list 1 gamma)
end

; ==========
; VECTOR HELPERS
; ==========
to-report v-add [a b]
  report list (item 0 a + item 0 b) (item 1 a + item 1 b)
end

to-report v-sub [a b]
  report list (item 0 a - item 0 b) (item 1 a - item 1 b)
end

to-report v-scale [a s]
  report list (item 0 a * s) (item 1 a * s)
end

to-report v-scale-add [p vec s]
  report list (item 0 p + item 0 vec * s) (item 1 p + item 1 vec * s)
end

to-report v-mag [a]
  report sqrt ((item 0 a) ^ 2 + (item 1 a) ^ 2)
end

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
  report list (sx - tx) (sy - ty)
end

to-report can-move-to [nx ny]
  report (nx > min-pxcor) and (nx < max-pxcor) and (ny > min-pycor) and (ny < max-pycor)
end

;; helper: add weighted vec to accumulator
to-report v-plus [acc vec w]
  report v-add acc (v-scale vec w)
end

