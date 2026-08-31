(use jaylib)
(import ./assets)
(import ./battle)
(import ./dialogue)

(def submenu-text-positions [[90 268] [350 268] [90 310] [350 310]])
(def button-positions [[32 432] [185 432] [345 432] [500 432]])
(def button-textures [[:fight :fight-selected]
                      [:act :act-selected]
                      [:item :item-selected]
                      [:mercy :mercy-selected]])
(def layer-order [:background :enemies :buttons :player :clipped-attacks :overlay :touch])

(var current-animation-tick 0)

(defn normalize-color
  [color]
  (cond
    (keyword? color) color
    (number? color) color
    :else
    (let [byte-components?
          (or (> (get color 0) 1)
              (> (get color 1) 1)
              (> (get color 2) 1)
              (and (= (length color) 4) (> (get color 3) 1)))]
      (if byte-components?
        (if (= (length color) 4)
          [(/ (get color 0) 255.0) (/ (get color 1) 255.0)
           (/ (get color 2) 255.0) (/ (get color 3) 255.0)]
          [(/ (get color 0) 255.0) (/ (get color 1) 255.0)
           (/ (get color 2) 255.0)])
        color))))


(defn load-bitmap-font
  [texture-id metadata-path scale]
  (def glyphs @{})
  (var line-height 32)
  (each line (string/split "\n" (slurp metadata-path))
    (unless (empty? line)
      (def fields (string/split ";" line))
      (when (= (length fields) 7)
        (def code (scan-number (get fields 0)))
        (def height (scan-number (get fields 4)))
        (put glyphs code
             [(scan-number (get fields 1))
              (scan-number (get fields 2))
              (scan-number (get fields 3))
              height
              (scan-number (get fields 5))
              (scan-number (get fields 6))])
        (set line-height (max line-height height)))))
  {:texture-id texture-id
   :glyphs glyphs
   :line-height line-height
   :scale scale})

(defn prepare-fixed-cell-font
  [descriptor]
  (def prepared @{})
  (each key (keys descriptor)
    (put prepared key (get descriptor key)))
  (def glyphs @{})
  (def codes (string/bytes (get descriptor :charset)))
  (for i 0 (length codes)
    (put glyphs (get codes i) i))
  (put prepared :glyphs glyphs)
  prepared)

(defn load-fonts
  [&opt asset-store]
  (def fonts
    @{:main (load-bitmap-font :font-main "assets/fonts/glyphs_fnt_main.csv" 1.0)
      :small-2 (load-bitmap-font :font-small "assets/fonts/glyphs_fnt_small.csv" 2.0)
      :small-3 (load-bitmap-font :font-small "assets/fonts/glyphs_fnt_small.csv" 3.0)})
  (when asset-store
    (each id (keys (get asset-store :fixed-cell-fonts {}))
      (put fonts id
           (prepare-fixed-cell-font
             (get (get asset-store :fixed-cell-fonts) id)))))
  fonts)

(defn draw-bitmap-text
  [asset-store font text position &opt color]
  (def tint (normalize-color (default color :white)))
  (def texture (assets/texture asset-store (get font :texture-id)))
  (def scale (get font :scale))
  (def start-x (get position 0))
  (var x start-x)
  (var y (get position 1))
  (each code (string/bytes text)
    (if (= code 10)
      (do
        (set x start-x)
        (+= y (* (get font :line-height) scale)))
      (when-let [glyph (get (get font :glyphs) code)]
        (def gx (get glyph 0))
        (def gy (get glyph 1))
        (def gw (get glyph 2))
        (def gh (get glyph 3))
        (def shift (get glyph 4))
        (def offset (get glyph 5))
        (draw-texture-pro texture
                          [gx gy gw gh]
                          [(+ x (* offset scale)) y (* gw scale) (* gh scale)]
                          [0 0] 0 tint)
        (+= x (* shift scale))))))

(defn whitespace-code?
  [code]
  (or (= code 9) (= code 10) (= code 13) (= code 32)))

(defn draw-fixed-cell-text
  [asset-store font text rect &opt item-scale color]
  (def texture (assets/texture asset-store (get font :texture-id)))
  (def scale (default item-scale (get font :scale 1)))
  (def cell-width (get font :cell-width))
  (def cell-height (get font :cell-height))
  (def advance (+ (* cell-width scale) (get font :character-spacing 0)))
  (def line-advance (+ (* cell-height scale) (get font :line-height 0)))
  (def atlas-width (get (get font :atlas-size) 0))
  (def columns (math/floor (/ atlas-width cell-width)))
  (def tint (normalize-color (default color :white)))
  (def start-x (get rect 0))
  (def right (+ start-x (get rect 2)))
  (def bottom (+ (get rect 1) (get rect 3)))
  (def codes (string/bytes text))
  (var x start-x)
  (var y (get rect 1))
  (var i 0)
  (while (< i (length codes))
    (def code (get codes i))
    (if (= code 10)
      (do
        (set x start-x)
        (+= y line-advance))
      (do
        (when (and (get font :word-wrap? false)
                   (not (whitespace-code? code))
                   (or (= i 0) (whitespace-code? (get codes (dec i))))
                   (> x start-x))
          (var j i)
          (while (and (< j (length codes))
                      (not (whitespace-code? (get codes j))))
            (++ j))
          (when (> (+ x (* (- j i) advance)) right)
            (set x start-x)
            (+= y line-advance)))
        (when (<= (+ y (* cell-height scale)) bottom)
          (when-let [glyph-index (get (get font :glyphs) code)]
            (def source-x (* (% glyph-index columns) cell-width))
            (def source-y (* (math/floor (/ glyph-index columns)) cell-height))
            (draw-texture-pro texture
                              [source-x source-y cell-width cell-height]
                              [x y (* cell-width scale) (* cell-height scale)]
                              [0 0] 0 tint)))
        (+= x advance)
        (when (> (+ x advance) right)
          (set x start-x)
          (+= y line-advance))))
    (++ i)))

(defn animation-frame-ticks
  [animation frame]
  (or (get frame :ticks nil)
      (max 1
           (math/floor
             (+ 0.5 (* 30 (/ (get frame :duration 1)
                              (get animation :speed 30))))))))

(defn animation-frame
  [animation ticks &opt requested-index]
  (def frames (get animation :frames))
  (if requested-index
    (get frames (max 0 (min requested-index (dec (length frames)))))
    (if (or (get animation :static? false) (= (length frames) 1))
      (get frames 0)
      (do
        (var total 0)
        (each frame frames
          (+= total (animation-frame-ticks animation frame)))
        (var cursor (max 0 ticks))
        (if (get animation :loop? false)
          (do
            (def back-index (or (get animation :loop-back nil) 0))
            (var intro 0)
            (for i 0 back-index
              (+= intro (animation-frame-ticks animation (get frames i))))
            (var loop-duration (- total intro))
            (when (and (> loop-duration 0) (>= cursor total))
              (set cursor (+ intro (% (- cursor intro) loop-duration)))))
          (set cursor (min cursor (dec total))))
        (var index 0)
        (while (and (< index (dec (length frames)))
                    (>= cursor (animation-frame-ticks animation (get frames index))))
          (-= cursor (animation-frame-ticks animation (get frames index)))
          (++ index))
        (get frames index)))))

(defn scale-pair
  [value]
  (if (number? value)
    [value value]
    value))

(defn sprite-animation
  [asset-store item]
  (def id (or (get item :animation nil) (get item :texture nil)))
  (and id (assets/animation asset-store id)))

(defn sprite-frame
  [asset-store item]
  (when-let [animation (sprite-animation asset-store item)]
    (animation-frame animation
                     (get item :ticks (get item :age current-animation-tick))
                     (get item :frame nil))))

(defn sprite-transform
  [asset-store item]
  (def frame (sprite-frame asset-store item))
  (def animation (sprite-animation asset-store item))
  (def texture-id (or (and frame (get frame :texture-id nil))
                      (get item :texture nil)
                      (get item :texture-id nil)))
  (def texture (assets/texture asset-store texture-id))
  (def source (get item :source
                   [0 0
                    (if frame (get (get frame :size) 0) (get texture :width))
                    (if frame (get (get frame :size) 1) (get texture :height))]))
  (def scale (scale-pair (get item :scale [1 1])))
  (def size (get item :size
                 [(* (get source 2) (get scale 0))
                  (* (get source 3) (get scale 1))]))
  (def origin (get item :origin
                   (if frame (get frame :origin [0 0]) [0 0])))
  {:frame frame
   :texture texture
   :source source
   :position (get item :position [0 0])
   :size size
   :origin origin
   :rotation (get item :rotation 0)
   :tint (normalize-color
           (get item :tint
                (or (and animation (get animation :default-tint nil))
                    :white)))})

(defn draw-sprite
  [asset-store item]
  (when (get item :visible? true)
    (def transform (sprite-transform asset-store item))
    (def size (get transform :size))
    (def origin (get transform :origin))
    (def position (get transform :position))
    (draw-texture-pro (get transform :texture)
                      (get transform :source)
                      [(get position 0) (get position 1)
                       (get size 0) (get size 1)]
                      [(* (get origin 0) (get size 0))
                       (* (get origin 1) (get size 1))]
                      (get transform :rotation)
                      (get transform :tint))))

(defn sprite-image-point
  [asset-store item point-name]
  (def transform (sprite-transform asset-store item))
  (def frame (get transform :frame))
  (def point (and frame (get (get frame :image-points {}) point-name nil)))
  (when point
    (def size (get transform :size))
    (def origin (get transform :origin))
    (def local-x (* (- (get point 0) (get origin 0)) (get size 0)))
    (def local-y (* (- (get point 1) (get origin 1)) (get size 1)))
    (def radians (* (get transform :rotation) (/ math/pi 180.0)))
    (def position (get transform :position))
    [(+ (get position 0)
        (- (* local-x (math/cos radians)) (* local-y (math/sin radians))))
     (+ (get position 1)
        (+ (* local-x (math/sin radians)) (* local-y (math/cos radians))))]))

(defn draw-region
  [texture source dest tint]
  (when (and (> (get source 2) 0) (> (get source 3) 0)
             (> (get dest 2) 0) (> (get dest 3) 0))
    (draw-texture-pro texture source dest [0 0] 0 tint)))

(defn draw-region-tiled
  [texture source dest tint]
  (def tile-width (get source 2))
  (def tile-height (get source 3))
  (when (and (> tile-width 0) (> tile-height 0))
    (var y (get dest 1))
    (def bottom (+ y (get dest 3)))
    (while (< y bottom)
      (def draw-height (min tile-height (- bottom y)))
      (var x (get dest 0))
      (def right (+ x (get dest 2)))
      (while (< x right)
        (def draw-width (min tile-width (- right x)))
        (draw-region texture
                     [(get source 0) (get source 1) draw-width draw-height]
                     [x y draw-width draw-height]
                     tint)
        (+= x tile-width))
      (+= y tile-height))))

(defn draw-mode-region
  [texture source dest mode tint]
  (case mode
    :tile (draw-region-tiled texture source dest tint)
    :transparent nil
    (draw-region texture source dest tint)))

(defn draw-nine-patch
  [asset-store item]
  (def descriptor-id (get item :nine-patch (get item :texture)))
  (def descriptor (assets/nine-patch asset-store descriptor-id))
  (def texture (assets/texture asset-store (get descriptor :texture-id descriptor-id)))
  (def native-size (get descriptor :native-size [(get texture :width) (get texture :height)]))
  (def margins (get descriptor :margins))
  (def left (get margins :left))
  (def top (get margins :top))
  (def right (get margins :right))
  (def bottom (get margins :bottom))
  (def rect (get item :rect))
  (def x (get rect 0))
  (def y (get rect 1))
  (def width (get rect 2))
  (def height (get rect 3))
  (def inner-source-width (- (get native-size 0) left right))
  (def inner-source-height (- (get native-size 1) top bottom))
  (def inner-width (max 0 (- width left right)))
  (def inner-height (max 0 (- height top bottom)))
  (def tint (normalize-color (get item :tint :white)))
  (draw-region texture [0 0 left top] [x y left top] tint)
  (draw-region texture [(- (get native-size 0) right) 0 right top]
               [(+ x width (- right)) y right top] tint)
  (draw-region texture [0 (- (get native-size 1) bottom) left bottom]
               [x (+ y height (- bottom)) left bottom] tint)
  (draw-region texture [(- (get native-size 0) right)
                        (- (get native-size 1) bottom) right bottom]
               [(+ x width (- right)) (+ y height (- bottom)) right bottom] tint)
  (draw-mode-region texture [left 0 inner-source-width top]
                    [(+ x left) y inner-width top]
                    (get descriptor :edge-mode :stretch) tint)
  (draw-mode-region texture [left (- (get native-size 1) bottom)
                             inner-source-width bottom]
                    [(+ x left) (+ y height (- bottom)) inner-width bottom]
                    (get descriptor :edge-mode :stretch) tint)
  (draw-mode-region texture [0 top left inner-source-height]
                    [x (+ y top) left inner-height]
                    (get descriptor :edge-mode :stretch) tint)
  (draw-mode-region texture [(- (get native-size 0) right) top
                             right inner-source-height]
                    [(+ x width (- right)) (+ y top) right inner-height]
                    (get descriptor :edge-mode :stretch) tint)
  (draw-mode-region texture [left top inner-source-width inner-source-height]
                    [(+ x left) (+ y top) inner-width inner-height]
                    (get descriptor :fill-mode :stretch) tint))

(defn draw-tile
  [asset-store item]
  (def descriptor-id (get item :tile (get item :texture)))
  (def descriptor (assets/tile asset-store descriptor-id))
  (def texture (assets/texture asset-store (get descriptor :texture-id descriptor-id)))
  (def native-size (get descriptor :native-size [(get texture :width) (get texture :height)]))
  (def rect (get item :rect
                 [(get (get item :position [0 0]) 0)
                  (get (get item :position [0 0]) 1)
                  (get (get item :size native-size) 0)
                  (get (get item :size native-size) 1)]))
  (def declared-origin (get item :origin (get descriptor :origin :top-left)))
  (def origin (if (= declared-origin :top-left) [0 0] declared-origin))
  (draw-texture-pro texture
                    [0 0 (get rect 2) (get rect 3)]
                    rect
                    [(* (get origin 0) (get rect 2))
                     (* (get origin 1) (get rect 3))]
                    (get item :rotation 0)
                    (normalize-color (get item :tint :white))))

(defn draw-model-text
  [asset-store fonts item]
  (def font-id (get item :font))
  (def font
    (or (get fonts font-id nil)
        (when-let [descriptor (assets/fixed-cell-font asset-store font-id)]
          (prepare-fixed-cell-font descriptor))))
  (def rect (get item :rect
                 [(get (get item :position [0 0]) 0)
                  (get (get item :position [0 0]) 1)
                  640 480]))
  (if (get font :cell-width nil)
    (draw-fixed-cell-text asset-store font (get item :text "") rect
                          (get item :scale nil) (get item :tint :white))
    (draw-bitmap-text asset-store font (get item :text "")
                      [(get rect 0) (get rect 1)] (get item :tint :white))))

(defn draw-model-item
  [asset-store fonts item]
  (when (get item :visible? true)
    (case (get item :kind)
      :sprite (draw-sprite asset-store item)
      :nine-patch (draw-nine-patch asset-store item)
      :tile (draw-tile asset-store item)
      :rect (draw-rectangle-rec
              (get item :rect)
              (normalize-color (get item :color (get item :tint :white))))
      :rect-lines (draw-rectangle-lines-ex
                    (get item :rect)
                    (get item :thickness 1)
                    (normalize-color (get item :color (get item :tint :white))))
      :text (draw-model-text asset-store fonts item)
      :fixed-text (draw-model-text asset-store fonts item))))

(defn draw-clipped-item
  [asset-store fonts item]
  (if-let [clip (get item :clip nil)]
    (do
      (begin-scissor-mode (math/floor (get clip 0))
                          (math/floor (get clip 1))
                          (math/ceil (get clip 2))
                          (math/ceil (get clip 3)))
      (draw-model-item asset-store fonts item)
      (end-scissor-mode))
    (draw-model-item asset-store fonts item)))

(defn draw-model-layer
  [asset-store fonts layer]
  (if (dictionary? layer)
    (let [clip (get layer :clip nil)]
      (when clip
        (begin-scissor-mode (math/floor (get clip 0))
                            (math/floor (get clip 1))
                            (math/ceil (get clip 2))
                            (math/ceil (get clip 3))))
      (each item (get layer :items @[])
        (if clip
          (draw-model-item asset-store fonts item)
          (draw-clipped-item asset-store fonts item)))
      (when clip (end-scissor-mode)))
    (each item layer
      (draw-clipped-item asset-store fonts item))))

(defn draw-render-model
  [asset-store fonts model]
  (clear-background (normalize-color (get model :clear-color :black)))
  (def layers (get model :layers {}))
  (if (dictionary? layers)
    (each layer-id layer-order
      (when-let [layer (get layers layer-id nil)]
        (draw-model-layer asset-store fonts layer)))
    (each layer layers
      (draw-model-layer asset-store fonts layer))))

(defn draw-arena
  [battle-state]
  (def rect (get (get battle-state :arena) :rect))
  # SFML's positive outline thickness expands outside the shape rectangle.
  (draw-rectangle-lines-ex [(- (get rect 0) 5)
                            (- (get rect 1) 5)
                            (+ (get rect 2) 10)
                            (+ (get rect 3) 10)]
                           5 :white))

(defn draw-hp
  [asset-store fonts battle-state]
  (def player (get battle-state :player))
  (def ratio (/ (get player :hp) (get player :max-hp)))
  (draw-bitmap-text asset-store (get fonts :small-2) "HP" [244 405])
  (draw-rectangle 275 400 25 21 :red)
  (draw-rectangle 275 400 (math/floor (* 25 ratio)) 21 :yellow)
  (draw-bitmap-text asset-store (get fonts :small-3)
                    (string (get player :hp) " / " (get player :max-hp))
                    [314 403]))

(defn draw-enemy
  [asset-store encounter enemy]
  (each layer (get encounter :render-layers)
    (def frame (get enemy (get layer :frame-key)))
    (def texture-id (get (get layer :textures) frame))
    (def position ((get layer :position) enemy))
    (draw-texture-v (assets/texture asset-store texture-id) position :white)))

(defn draw-buttons
  [asset-store battle-state]
  (for i 0 4
    (def ids (get button-textures i))
    (def id (if (battle/command-selected? battle-state i)
              (get ids 1) (get ids 0)))
    (draw-texture-v (assets/texture asset-store id) (get button-positions i) :white)))

(defn draw-submenu
  [asset-store fonts battle-state]
  (def options (battle/submenu-options battle-state))
  (for i 0 (min 4 (length options))
    (def mercy-yellow?
      (and (= (get (get battle-state :menu) :screen) :mercy)
           ((get (get battle-state :encounter) :can-spare?)
            (battle/active-enemy battle-state))))
    (draw-bitmap-text asset-store (get fonts :main) (get options i)
                      (get submenu-text-positions i)
                      (if mercy-yellow? :yellow :white))))

(defn draw-player
  [asset-store player]
  (when (get player :visible?)
    (def id (if (= (get player :sprite) :hurt) :heart-hurt :heart))
    (draw-texture-v (assets/texture asset-store id)
                    [(get player :x) (get player :y)] :white)))

(defn draw-bullets
  [asset-store bullets]
  (each bullet bullets
    (def texture-id (get (get bullet :textures) (get bullet :frame)))
    (draw-texture-v
      (assets/texture asset-store texture-id)
      [(get bullet :x) (get bullet :y)] :white)))

(defn draw-death
  [asset-store battle-state]
  (clear-background :black)
  (def death (get battle-state :death))
  (case (get death :stage)
    :show-player
    (draw-texture-v (assets/texture asset-store :heart)
                    [(get death :x) (get death :y)] :white)
    :broken
    (draw-texture-v (assets/texture asset-store :heart-break)
                    [(get death :x) (get death :y)] :white)
    :shards
    (each shard (get death :shards)
      (def id (get [:heart-shard-0 :heart-shard-1 :heart-shard-2 :heart-shard-3]
                   (get shard :frame)))
      (draw-texture-v (assets/texture asset-store id)
                      [(get shard :x) (get shard :y)] :white))))

(defn draw-froggit-battle
  [asset-store fonts battle-state]
  (if (= (get battle-state :phase) :death)
    (draw-death asset-store battle-state)
    (do
      (clear-background :black)
      (draw-texture (assets/texture asset-store :battle-bg) 0 0 :white)
      (draw-arena battle-state)
      (draw-bitmap-text asset-store (get fonts :main)
                        (dialogue/visible-text (get battle-state :dialogue))
                        [52 270])
      (draw-hp asset-store fonts battle-state)
      (each enemy (get battle-state :enemies)
        (draw-enemy asset-store (get battle-state :encounter) enemy))
      (draw-buttons asset-store battle-state)
      (draw-submenu asset-store fonts battle-state)
      (draw-bullets asset-store (get battle-state :bullets))
      (draw-player asset-store (get battle-state :player)))))

(defn draw-battle
  [asset-store fonts battle-state]
  (set current-animation-tick (get battle-state :tick 0))
  (if-let [render-model (get (get battle-state :encounter) :render-model nil)]
    (draw-render-model asset-store fonts (render-model battle-state))
    (draw-froggit-battle asset-store fonts battle-state)))
