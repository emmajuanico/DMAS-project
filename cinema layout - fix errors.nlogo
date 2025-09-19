;; Cinema layout generator (NetLogo)
;; - 10 rows, each row: 4 (left) • 12 (center) • 4 (right)
;; - screen (green), front aisle (blue), vertical aisles (blue),
;; - seat rows as thin obstacle lines (black)
;; - outer walls (gray) with 4 exits (red)
;;
;; Usage: paste into the Code tab and RUN -> setup

patches-own [ blocked? exit? wall? ]  ;; blocked? = impassable for agents

globals [
  rows leftSeats centerSeats rightSeats
  verticalAisleWidth frontAisleDepth rowSpacing rowThickness
  ;; computed coords
  seatingWidth worldMinX worldMaxX worldMinY worldMaxY
  leftStartX leftEndX leftAisleStartX leftAisleEndX
  centerStartX centerEndX rightAisleStartX rightAisleEndX rightStartX rightEndX
  topSeatingY bottomSeatingY
]

to setup
  clear-all

  ;; ----------------------------
  ;; PARAMETERS (change these)
  ;; ----------------------------
  set rows 10
  set leftSeats 4
  set centerSeats 12
  set rightSeats 4
  set verticalAisleWidth 2    ;; width of the two vertical aisles separating L-C-R
  set frontAisleDepth 6       ;; big space between screen and first row
  set rowSpacing 1            ;; vertical spacing between seat rows (in patches)
  set rowThickness 1         ;; seat-line thickness (1 = one patch high)
  ;; ----------------------------

  ;; compute world size so layout fits nicely (no extra margins)
  set seatingWidth (leftSeats + centerSeats + rightSeats + 2 * verticalAisleWidth)
  let worldWidth seatingWidth + 4
  let worldHeight (frontAisleDepth + rows * (rowThickness + rowSpacing) + 6)

  set worldMinX (0 - floor (worldWidth / 2))
  set worldMaxX (worldMinX + worldWidth - 1)
  set worldMinY (0 - floor (worldHeight / 2))
  set worldMaxY (worldMinY + worldHeight - 1)

  resize-world worldMinX worldMaxX worldMinY worldMaxY

  ;; initialize patches
  ask patches [
    set pcolor white
    set blocked? false
    set exit? false
    set wall? false
  ]

  ;; compute horizontal block coordinates
  set leftStartX (worldMinX + 1)             ;; seats start right after left wall
  set leftEndX (leftStartX + leftSeats - 1)
  set leftAisleStartX (leftEndX + 1)
  set leftAisleEndX (leftAisleStartX + verticalAisleWidth - 1)
  set centerStartX (leftAisleEndX + 1)
  set centerEndX (centerStartX + centerSeats - 1)
  set rightAisleStartX (centerEndX + 1)
  set rightAisleEndX (rightAisleStartX + verticalAisleWidth - 1)
  set rightStartX (rightAisleEndX + 1)
  set rightEndX worldMaxX - 1   ;; seats touch right wall (no side aisle)

  ;; compute vertical seating range
  set topSeatingY (worldMaxY - frontAisleDepth - 1)   ;; screen flush with top wall
  set bottomSeatingY (worldMinY + 5)                  ;; one aisle then bottom wall

  draw-walls
  draw-screen
  draw-front-aisle
  draw-vertical-aisles
  draw-seat-rows
  draw-back-aisle
  carve-exits

  reset-ticks
end

;; ----------------------------
;; DRAWING SUBPROCEDURES
;; ----------------------------

to draw-walls
  ask patches with [
    pxcor = worldMinX or pxcor = worldMaxX or pycor = worldMinY or pycor = worldMaxY
  ] [
    set pcolor gray
    set wall? true
    set blocked? true
  ]
end

to draw-screen
  let screenHeight 1
  let screenY worldMaxY - 1     ;; directly against wall
  ask patches with [
    pycor = screenY and pxcor >= leftStartX and pxcor <= rightEndX
  ] [
    set pcolor green
    set blocked? true
  ]
end

to draw-front-aisle
  let screenBottomY (worldMaxY - 2)
  ask patches with [
    pycor <= screenBottomY and pycor > topSeatingY and pxcor >= leftStartX and pxcor <= rightEndX
  ] [
    set pcolor blue
    set blocked? false
  ]
end

to draw-vertical-aisles
  ask patches with [
    pxcor >= leftAisleStartX and pxcor <= leftAisleEndX and pycor <= topSeatingY and pycor >= bottomSeatingY
  ] [
    set pcolor blue
    set blocked? false
  ]
  ask patches with [
    pxcor >= rightAisleStartX and pxcor <= rightAisleEndX and pycor <= topSeatingY and pycor >= bottomSeatingY
  ] [
    set pcolor blue
    set blocked? false
  ]
end

to draw-seat-rows
  let i 0
  while [ i < rows ] [
    let y (topSeatingY - i * (rowThickness + rowSpacing))
    ;; left block
    ask patches with [ pycor = y and pxcor >= leftStartX and pxcor <= leftEndX ] [
      set pcolor black
      set blocked? true
    ]
    ;; center block
    ask patches with [ pycor = y and pxcor >= centerStartX and pxcor <= centerEndX ] [
      set pcolor black
      set blocked? true
    ]
    ;; right block
    ask patches with [ pycor = y and pxcor >= rightStartX and pxcor <= rightEndX ] [
      set pcolor black
      set blocked? true
    ]
    set i (i + 1)
  ]
end

to draw-back-aisle
  ask patches with [
    pycor >= worldMinY + 1 and pycor < bottomSeatingY and
    pxcor > worldMinX and pxcor < worldMaxX
  ] [
    set pcolor blue
    set blocked? false
  ]
end



;; ----------------------------
;; EXITS
;; ----------------------------

to-report exit-range [yCenter exitHeight]
  let result []
  let half-floor floor (exitHeight / 2)
  let half-ceil ceiling (exitHeight / 2)
  let startY yCenter - half-floor
  let stopY yCenter + half-ceil
  ;; manually add each integer from startY to stopY inclusive
  let y startY
  while [y <= stopY] [
    set result lput y result
    set y y + 1
  ]
  report result
end

to carve-exits
  let exitHeight 2
  let topExitY (worldMaxY - 4)
  let bottomExitY (worldMinY + 2)
  let leftX worldMinX
  let rightX worldMaxX

  ;; build all exits with a helper procedure
  ask-exit leftX topExitY exitHeight
  ask-exit rightX topExitY exitHeight
  ask-exit leftX bottomExitY exitHeight
  ask-exit rightX bottomExitY exitHeight
end

to ask-exit [x yCenter exitHeight]
  let ys exit-range yCenter exitHeight
  foreach ys [ y ->
    ask patch x y [
      set pcolor red
      set blocked? false
      set exit? true
      set wall? false
    ]
  ]
end

