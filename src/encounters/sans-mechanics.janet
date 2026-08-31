# Deterministic 30 Hz mechanics for the canonical Sans encounter.

(def ticks-per-second 30)
(def dt (/ 1.0 ticks-per-second))
(def heart-size 16)
(def heart-half 8)
(def inner-border 5)
(def heart-speed 150)
(def jump-strength 180)
(def jump-release-speed 30)
(def default-max-fall-speed 750)
(def directions [[1 0] [0 1] [-1 0] [0 -1]])

(defn emit! [battle event]
  (array/push (get battle :events) event))

(defn numeric [value &opt fallback]
  (if (number? value)
    value
    (or (and (string? value) (scan-number value)) fallback 0)))

(defn integer [value &opt fallback]
  (math/floor (numeric value fallback)))

(defn enabled? [value]
  (not= 0 (integer value 0)))

(defn seconds->ticks [seconds]
  (def n (numeric seconds 0))
  (if (<= n 0) 0 (max 1 (math/round (* n ticks-per-second)))))

(defn direction-vector [direction]
  (get directions (% (integer direction 0) 4)))

(defn radians [degrees]
  (* degrees (/ math/pi 180.0)))

(defn color-name [color]
  (case (integer color 0) 1 :blue 2 :orange :white))

(def sound-ids
  {"Ding" :sans/sfx-ding "PlayerFight" :sans/sfx-player-fight
   "PlayerDamaged" :sans/sfx-player-damaged "SansSpeak" :sans/sfx-sans-speak
   "GasterBlaster" :sans/sfx-gaster-blaster "BoneStab" :sans/sfx-bone-stab
   "Warning" :sans/sfx-warning "HeartShatter" :sans/sfx-heart-shatter
   "GasterBlast" :sans/sfx-gaster-blast "Flash" :sans/sfx-flash
   "Slam" :sans/sfx-slam "MenuSelect" :sans/sfx-menu-select
   "HeartSplit" :sans/sfx-heart-split "MenuCursor" :sans/sfx-menu-cursor
   "BattleText" :sans/sfx-battle-text "PlayerHeal" :sans/sfx-player-heal
   "GasterBlast2" :sans/sfx-gaster-blast-2})

(defn new-player []
  @{:x 320 :y 320 :w heart-size :h heart-size :vx 0 :vy 0
    :hp 92 :max-hp 92 :kr 0 :kr-t 0 :mode :red :gravity-dir 1
    :max-fall-speed default-max-fall-speed :visible? false :moving? false
    :hurt-ticks 0 :slammed? false :slam-damage? false :sprite :normal})

(defn new-arena []
  @{:left 32 :top 240 :right 608 :bottom 384
    :target-left 33 :target-top 251 :target-right 608 :target-bottom 391
    :rect @[32 240 576 144] :target @[33 251 575 140]
    :speed 480 :resizing? false :visible? false
    :resume-generation nil :completion nil})

(defn sans [battle] (first (get battle :enemies)))

(defn ensure-collections! [battle]
  (unless (get battle :hazards nil) (put battle :hazards @[]))
  (unless (get battle :platforms nil) (put battle :platforms @[]))
  battle)

(defn sync-arena-rect! [arena]
  (put arena :rect @[(get arena :left) (get arena :top)
                     (- (get arena :right) (get arena :left))
                     (- (get arena :bottom) (get arena :top))])
  (put arena :target @[(get arena :target-left) (get arena :target-top)
                       (- (get arena :target-right) (get arena :target-left))
                       (- (get arena :target-bottom) (get arena :target-top))]))

(defn reset-attack! [battle]
  (ensure-collections! battle)
  (array/clear (get battle :hazards))
  (array/clear (get battle :platforms))
  (put battle :sans-bottom-bones? false)
  (put battle :sans-bottom-bone-ticks 0)
  (def player (get battle :player))
  (def arena (get battle :arena))
  (put player :vx 0) (put player :vy 0) (put player :moving? false)
  (put player :max-fall-speed default-max-fall-speed)
  (put player :slammed? false) (put player :slam-damage? false)
  (put arena :speed 480) (put arena :completion nil)
  (put arena :resume-generation nil)
  (when-let [enemy (sans battle)]
    (put enemy :x 320) (put enemy :x-speed 0))
  battle)

(defn approach [value target amount]
  (cond (< value target) (min target (+ value amount))
        (> value target) (max target (- value amount))
        :else value))

(defn set-arena-target! [battle left top right bottom completion]
  (def arena (get battle :arena))
  (put arena :target-left (numeric left)) (put arena :target-top (numeric top))
  (put arena :target-right (numeric right)) (put arena :target-bottom (numeric bottom))
  (put arena :visible? true) (put arena :resizing? true)
  (put arena :completion completion)
  (put arena :resume-generation
       (and (get battle :attack nil) (get (get battle :attack) :generation nil)))
  (sync-arena-rect! arena)
  arena)

(defn set-arena-instant! [battle left top right bottom]
  (def arena (set-arena-target! battle left top right bottom nil))
  (put arena :left (get arena :target-left)) (put arena :top (get arena :target-top))
  (put arena :right (get arena :target-right)) (put arena :bottom (get arena :target-bottom))
  (put arena :resizing? false)
  (sync-arena-rect! arena)
  arena)

(defn resume-resize-owner! [battle arena]
  (def generation (get arena :resume-generation nil))
  (def attack (get battle :attack nil))
  (when (and attack generation (= generation (get attack :generation nil))
             (not (get attack :ended? false)))
    (put attack :status :running)
    (put attack :pause-reason nil))
  (put arena :completion nil)
  (put arena :resume-generation nil))

(defn step-arena! [battle]
  (def arena (get battle :arena))
  (when (get arena :resizing? false)
    (def amount (* (get arena :speed 480) dt))
    (put arena :left (approach (get arena :left) (get arena :target-left) amount))
    (put arena :top (approach (get arena :top) (get arena :target-top) amount))
    (put arena :right (approach (get arena :right) (get arena :target-right) amount))
    (put arena :bottom (approach (get arena :bottom) (get arena :target-bottom) amount))
    (sync-arena-rect! arena)
    (when (and (= (get arena :left) (get arena :target-left))
               (= (get arena :top) (get arena :target-top))
               (= (get arena :right) (get arena :target-right))
               (= (get arena :bottom) (get arena :target-bottom)))
      (put arena :resizing? false)
      (if (= (get arena :completion nil) "TLResume")
        (resume-resize-owner! battle arena)
        (do (put arena :completion nil) (put arena :resume-generation nil)))))
  arena)

(defn set-heart-mode! [player mode]
  (case (integer mode 0)
    0 (do (put player :mode :red) (put player :gravity-dir 1))
    1 (do (put player :mode :blue) (put player :gravity-dir 1)))
  player)

(defn gravity-vector [player] (direction-vector (get player :gravity-dir 1)))

(defn gravity-speed [player]
  (def g (gravity-vector player))
  (+ (* (get player :vx) (get g 0)) (* (get player :vy) (get g 1))))

(defn gravity-acceleration [speed]
  (cond (> speed 15) 540
        (> speed -30) 180
        (> speed -120) 450
        :else 180))

(defn input-held? [input direction]
  (or (get input (keyword (string direction "-down")) false)
      (get input (keyword (string direction "?")) false)))
(defn input-pressed? [input direction]
  (or (get input direction false)
      (get input (keyword (string direction "-pressed?")) false)))
(defn input-released? [input direction]
  (or (get input (keyword (string direction "-released")) false)
      (get input (keyword (string direction "-released?")) false)))
(defn cancel-held? [input]
  (or (get input :cancel-down false) (get input :cancel? false)))

(defn rect-overlap? [ax ay aw ah bx by bw bh]
  (and (< ax (+ bx bw)) (< bx (+ ax aw)) (< ay (+ by bh)) (< by (+ ay ah))))

(defn heart-bounds [player &opt dx dy]
  (def ox (default dx 0)) (def oy (default dy 0))
  [(- (+ (get player :x) ox) heart-half)
   (- (+ (get player :y) oy) heart-half) heart-size heart-size])

(defn platform-solid? [battle platform dx dy]
  (def player (get battle :player))
  (def gravity (get player :gravity-dir 1))
  (def bounds (heart-bounds player dx dy))
  (def px (get bounds 0)) (def py (get bounds 1))
  (def x (get platform :x)) (def y (get platform :y))
  (def w (get platform :w)) (def h (get platform :h 7))
  (def horizontal-overlap (and (< px (+ x w)) (> (+ px heart-size) x)))
  (case gravity
    1 (and (> dy 0) horizontal-overlap (> y (get player :y))
           (<= (+ (get player :y) heart-half) (+ y 2))
           (> (+ py heart-size) y))
    3 (and (< dy 0) horizontal-overlap (< y (get player :y))
           (>= (- (get player :y) heart-half) (- (+ y h) 2))
           (< py (+ y h)))
    false))

(defn heart-solid? [battle dx dy]
  (def player (get battle :player)) (def arena (get battle :arena))
  (def bounds (heart-bounds player dx dy))
  (def left (get bounds 0)) (def top (get bounds 1))
  (def right (+ left heart-size)) (def bottom (+ top heart-size))
  (or (< left (+ (get arena :left) inner-border))
      (< top (+ (get arena :top) inner-border))
      (> right (- (get arena :right) inner-border))
      (> bottom (- (get arena :bottom) inner-border))
      (and (= (get player :mode) :blue)
           (find |(platform-solid? battle $ dx dy) (get battle :platforms @[])))))

(defn slam-impact! [battle speed]
  (def player (get battle :player))
  (when (get player :slammed? false)
    (put player :slammed? false)
    (when (>= (math/abs speed) 330)
      (emit! battle [:sound :sans/sfx-player-damaged])
      (emit! battle [:sound :sans/sfx-slam])
      (put battle :sans-shake (math/floor (/ (math/abs speed) 90)))
      (when (and (get player :slam-damage? false) (> (get player :hp) 1))
        (put player :hp (dec (get player :hp)))))))

(defn move-axis! [battle axis delta]
  (def player (get battle :player))
  (var remaining (math/abs delta)) (def sign (if (< delta 0) -1 1))
  (var hit? false)
  (while (and (> remaining 0) (not hit?))
    (def amount (* sign (min 1 remaining)))
    (def dx (if (= axis :x) amount 0)) (def dy (if (= axis :y) amount 0))
    (if (heart-solid? battle dx dy)
      (do
        (set hit? true)
        (def impact (if (= axis :x) (get player :vx) (get player :vy)))
        (slam-impact! battle impact)
        (put player (if (= axis :x) :vx :vy) 0))
      (put player axis (+ (get player axis) amount)))
    (-= remaining (math/abs amount)))
  hit?)

(defn jump-input [gravity-dir]
  (case gravity-dir 0 :left 1 :up 2 :right 3 :down))

(defn jump! [battle]
  (def player (get battle :player))
  (when (and (= (get player :mode) :blue)
             (let [g (gravity-vector player)] (heart-solid? battle (get g 0) (get g 1))))
    (def g (gravity-vector player))
    (put player :vx (- (get player :vx) (* (get g 0) jump-strength)))
    (put player :vy (- (get player :vy) (* (get g 1) jump-strength)))
    true))

(defn release-jump! [player]
  (def g (gravity-vector player)) (def speed (gravity-speed player))
  (when (< speed (- jump-release-speed))
    (if (not= 0 (get g 0))
      (put player :vx (* (get g 0) (- jump-release-speed)))
      (put player :vy (* (get g 1) (- jump-release-speed))))))

(defn platform-under-heart [battle]
  (def player (get battle :player)) (def gravity (get player :gravity-dir 1))
  (find
    (fn [platform]
      (def x (get platform :x)) (def w (get platform :w))
      (def horizontal? (and (> (+ (get player :x) heart-half) x)
                            (< (- (get player :x) heart-half) (+ x w))))
      (and horizontal?
           (case gravity
             1 (<= (math/abs (- (+ (get player :y) heart-half) (get platform :y))) 2.1)
             3 (<= (math/abs (- (- (get player :y) heart-half)
                                  (+ (get platform :y) (get platform :h 7)))) 2.1)
             false)))
    (get battle :platforms @[])))

(defn apply-blue-motion! [battle input speed]
  (def player (get battle :player))
  (def gravity-dir (get player :gravity-dir 1)) (def g (gravity-vector player))
  (def jump-key (jump-input gravity-dir))
  (when (input-pressed? input jump-key) (jump! battle))
  (when (input-released? input jump-key) (release-jump! player))
  (def down-speed (gravity-speed player))
  (unless (heart-solid? battle (* (get g 0) 0.2) (* (get g 1) 0.2))
    (def acceleration (gravity-acceleration down-speed))
    (put player :vx (+ (get player :vx) (* (get g 0) acceleration dt)))
    (put player :vy (+ (get player :vy) (* (get g 1) acceleration dt))))
  (def fall-cap (get player :max-fall-speed default-max-fall-speed))
  (def capped (max (- fall-cap) (min fall-cap (gravity-speed player))))
  (if (not= 0 (get g 0)) (put player :vx (* (get g 0) capped))
    (put player :vy (* (get g 1) capped)))
  (if (or (= gravity-dir 0) (= gravity-dir 2))
    (do
      # Side-platform collision/carry is disabled in the source for horizontal gravity.
      (put player :vy 0)
      (when (not= (input-held? input :up) (input-held? input :down))
        (put player :vy (if (input-held? input :up) (- speed) speed))))
    (do
      (put player :vx 0)
      (when-let [platform (platform-under-heart battle)]
        (put player :vx (get platform :vx 0))
        (put player :vy (get platform :vy 0))
        (case gravity-dir
          1 (put player :y (- (get platform :y) 8.05))
          3 (put player :y (+ (get platform :y) (get platform :h 7) 8.05))))
      (when (not= (input-held? input :left) (input-held? input :right))
        (put player :vx (+ (get player :vx)
                           (if (input-held? input :left) (- speed) speed)))))))

(defn move-heart! [battle input]
  (def player (get battle :player)) (def speed (if (cancel-held? input) 75 heart-speed))
  (when (>= (get player :hp) 0)
    (if (= (get player :mode) :red)
      (do
        (put player :vx (cond (= (input-held? input :left) (input-held? input :right)) 0
                              (input-held? input :left) (- speed) :else speed))
        (put player :vy (cond (= (input-held? input :up) (input-held? input :down)) 0
                              (input-held? input :up) (- speed) :else speed)))
      (when (= (get player :mode) :blue) (apply-blue-motion! battle input speed)))
    (def vx (get player :vx)) (def vy (get player :vy))
    (move-axis! battle :x (* vx dt)) (move-axis! battle :y (* vy dt))
    (put player :moving? (or (not= 0 (get player :vx)) (not= 0 (get player :vy)))))
  player)

(defn slam! [battle direction]
  (def player (get battle :player)) (def dir (max 0 (min 3 (integer direction 0))))
  (set-heart-mode! player 1) (put player :gravity-dir dir) (put player :slammed? true)
  (def g (gravity-vector player))
  (def speed (get player :max-fall-speed default-max-fall-speed))
  (put player :vx (* (get g 0) speed)) (put player :vy (* (get g 1) speed))
  player)

(defn spawn-platform! [battle x y width direction speed reverse?]
  (ensure-collections! battle)
  (def vector (direction-vector direction))
  (def platform
    @{:kind :platform :shape :rect :family :nine-patch
      :x (integer x) :y (integer y)
      :w (integer width) :width (integer width) :h 7
      :direction (% (integer direction) 4) :speed (integer speed)
      :vx (* (get vector 0) (integer speed)) :vy (* (get vector 1) (integer speed))
      :reverse? (enabled? reverse?) :visible? true :age 0
      :render @{:base :sans/platform-1 :cap :sans/platform-2 :cap-offset-y -4}})
  (array/push (get battle :platforms) platform)
  platform)

(defn spawn-platform-repeat! [battle start-x start-y width direction speed count spacing]
  (def vector (direction-vector direction))
  (for i 0 (integer count)
    (spawn-platform! battle
      (- (numeric start-x) (* (get vector 0) (integer spacing) i))
      (- (numeric start-y) (* (get vector 1) (integer spacing) i))
      width direction speed 0)))

(defn step-platforms! [battle]
  (def arena (get battle :arena))
  (each platform (get battle :platforms @[])
    (put platform :x (+ (get platform :x) (* (get platform :vx) dt)))
    (put platform :y (+ (get platform :y) (* (get platform :vy) dt)))
    (put platform :age (inc (get platform :age 0)))
    (when (get platform :reverse? false)
      (def dir (get platform :direction))
      (def crossed (case dir
                     0 (>= (+ (get platform :x) (get platform :w)) (get arena :right))
                     1 (>= (+ (get platform :y) (get platform :h)) (get arena :bottom))
                     2 (<= (get platform :x) (get arena :left))
                     3 (<= (get platform :y) (get arena :top))))
      (when crossed
        (def next-dir (% (+ dir 2) 4)) (def vector (direction-vector next-dir))
        (put platform :direction next-dir)
        (put platform :vx (* (get vector 0) (get platform :speed)))
        (put platform :vy (* (get vector 1) (get platform :speed)))))))

(defn base-hazard [kind]
  @{:kind kind :shape :rect :family :nine-patch :damage 1 :karma 6 :color :white
    :visible? true :age 0 :dead? false})

(defn spawn-bone! [battle vertical? x y length direction speed color]
  (ensure-collections! battle)
  (def vector (direction-vector direction))
  (def bone (base-hazard (if vertical? :bone-v :bone-h)))
  (put bone :x (integer x)) (put bone :y (integer y))
  (put bone :w (if vertical? 10 (integer length)))
  (put bone :h (if vertical? (integer length) 10))
  (put bone :direction (% (integer direction) 4)) (put bone :speed (integer speed))
  (put bone :vx (* (get vector 0) (integer speed)))
  (put bone :vy (* (get vector 1) (integer speed)))
  (put bone :color (color-name color))
  (put bone :texture (if vertical? :sans/bone-v :sans/bone-h))
  (array/push (get battle :hazards) bone)
  bone)

(defn spawn-bone-repeat! [battle vertical? start-x start-y length direction speed count spacing]
  (def vector (direction-vector direction))
  (for i 0 (integer count)
    (spawn-bone! battle vertical?
      (- (numeric start-x) (* (get vector 0) (integer spacing) i))
      (- (numeric start-y) (* (get vector 1) (integer spacing) i))
      length direction speed 0)))

(defn spawn-sine-bones! [battle count spacing speed height]
  (def arena (get battle :arena)) (def spacing-n (integer spacing))
  (def direction (if (> spacing-n 0) 2 0))
  (for i 0 (integer count)
    (def x (if (> spacing-n 0) (+ (get arena :right) (* spacing-n i))
             (+ (get arena :left) (* spacing-n i))))
    (def sine (math/floor (* (math/sin (/ i 3.0)) 28)))
    (def y (+ (get arena :top) 6))
    (spawn-bone! battle true x y (+ (integer height) sine) direction speed 0)
    (def lower-y (+ y (integer height) sine 39))
    (spawn-bone! battle true x lower-y (- (get arena :bottom) 5 lower-y) direction speed 0)))

(defn warning-geometry! [warning arena]
  (def dir (get warning :direction)) (def distance (get warning :distance))
  (case dir
    0 (do (put warning :x (- (get arena :right) distance 5))
          (put warning :y (+ (get arena :top) 8)) (put warning :w (- distance 3))
          (put warning :h (- (get arena :bottom) (get arena :top) 16)))
    1 (do (put warning :x (+ (get arena :left) 8))
          (put warning :y (- (get arena :bottom) distance 5))
          (put warning :w (- (get arena :right) (get arena :left) 16))
          (put warning :h (- distance 3)))
    2 (do (put warning :x (+ (get arena :left) 8))
          (put warning :y (+ (get arena :top) 8)) (put warning :w (- distance 3))
          (put warning :h (- (get arena :bottom) (get arena :top) 16)))
    3 (do (put warning :x (+ (get arena :left) 8))
          (put warning :y (+ (get arena :top) 8))
          (put warning :w (- (get arena :right) (get arena :left) 16))
          (put warning :h (- distance 3))))
  warning)

(defn spawn-stab-warning! [battle direction distance warn-time stay-time]
  (ensure-collections! battle)
  (def warning (base-hazard :stab-warning))
  (put warning :damage 0) (put warning :direction (max 0 (min 3 (integer direction))))
  (put warning :distance (integer distance))
  (put warning :warn-ticks (seconds->ticks warn-time))
  (put warning :stay-ticks (seconds->ticks stay-time))
  (put warning :texture :sans/bone-stab-warn)
  (warning-geometry! warning (get battle :arena))
  (array/push (get battle :hazards) warning)
  (emit! battle [:sound :sans/sfx-warning])
  warning)

(defn activate-stab! [battle stab]
  (def arena (get battle :arena)) (def dir (get stab :direction))
  (def distance (get stab :distance))
  (put stab :kind (if (or (= dir 0) (= dir 2)) :bone-stab-h :bone-stab-v))
  (put stab :damage 1) (put stab :karma 6) (put stab :speed (* distance 10))
  (put stab :state :enter)
  (case dir
    0 (do (put stab :x (- (get arena :right) 5)) (put stab :y (get arena :top))
          (put stab :w (+ distance 8)) (put stab :h (- (get arena :bottom) (get arena :top)))
          (put stab :dest-x (- (get arena :right) 5 distance)) (put stab :dest-y (get arena :top)))
    1 (do (put stab :x (get arena :left)) (put stab :y (- (get arena :bottom) 5))
          (put stab :w (- (get arena :right) (get arena :left))) (put stab :h (+ distance 8))
          (put stab :dest-x (get arena :left)) (put stab :dest-y (- (get arena :bottom) 5 distance)))
    2 (do (put stab :x (- (+ (get arena :left) 5) (+ distance 8)))
          (put stab :y (get arena :top)) (put stab :w (+ distance 8))
          (put stab :h (- (get arena :bottom) (get arena :top)))
          (put stab :dest-x (+ (- (+ (get arena :left) 5) (+ distance 8)) distance))
          (put stab :dest-y (get arena :top)))
    3 (do (put stab :x (get arena :left))
          (put stab :y (- (+ (get arena :top) 5) (+ distance 8)))
          (put stab :w (- (get arena :right) (get arena :left))) (put stab :h (+ distance 8))
          (put stab :dest-x (get arena :left))
          (put stab :dest-y (+ (- (+ (get arena :top) 5) (+ distance 8)) distance))))
  (put stab :texture (if (or (= dir 0) (= dir 2)) :sans/bone-stab-h :sans/bone-stab-v))
  (emit! battle [:sound :sans/sfx-bone-stab]))

(defn step-stab! [battle stab]
  (if (= (get stab :kind) :stab-warning)
    (if (> (get stab :warn-ticks) 0)
      (put stab :warn-ticks (dec (get stab :warn-ticks)))
      (activate-stab! battle stab))
    (let [dir (get stab :direction) vector (direction-vector dir)
          entering? (= (get stab :state) :enter) sign (if entering? -1 1)
          amount (* (get stab :speed) dt sign)]
      (unless (= (get stab :state) :stay)
        (put stab :x (+ (get stab :x) (* (get vector 0) amount)))
        (put stab :y (+ (get stab :y) (* (get vector 1) amount))))
      (when entering?
        (def reached? (case dir
                        0 (<= (get stab :x) (get stab :dest-x))
                        1 (<= (get stab :y) (get stab :dest-y))
                        2 (>= (get stab :x) (get stab :dest-x))
                        3 (>= (get stab :y) (get stab :dest-y))))
        (when reached?
          (put stab :x (get stab :dest-x)) (put stab :y (get stab :dest-y))
          (put stab :state (if (> (get stab :stay-ticks) 0) :stay :leave))))
      (when (= (get stab :state) :stay)
        (put stab :stay-ticks (dec (get stab :stay-ticks)))
        (when (<= (get stab :stay-ticks) 0) (put stab :state :leave)))
      (when (and (= (get stab :state) :leave)
                 (or (< (+ (get stab :x) (get stab :w)) 0) (> (get stab :x) 640)
                     (< (+ (get stab :y) (get stab :h)) 0) (> (get stab :y) 480)))
        (put stab :dead? true)))))

(defn spawn-blaster! [battle size start-x start-y end-x end-y end-angle spin-time blast-time]
  (ensure-collections! battle)
  (def size-n (integer size)) (def scale (case size-n 0 0.5 1 1.0 2 1.5 0.5))
  (def width (case size-n 0 114 1 114 2 171 114))
  (def height (case size-n 0 44 1 88 2 132 44))
  (def blaster
    @{:kind :gaster-blaster :shape :beam :family :sprite
      :x (integer start-x) :y (integer start-y) :w width :h height :angle 90
      :end-x (integer end-x) :end-y (integer end-y) :end-angle (integer end-angle)
      :scale scale :state :enter :timer-ticks (seconds->ticks spin-time)
      :blast-ticks (seconds->ticks blast-time) :beam-age 0 :base-size 0 :beam-size 0
      :beam-opacity 100 :leave-speed 0 :beam-visible? false :damage 0 :karma 10
      :color :white :visible? true :age 0 :dead? false
      :texture :sans/gaster-blaster/default})
  (array/push (get battle :hazards) blaster)
  (emit! battle [:sound :sans/sfx-gaster-blaster 1.2])
  blaster)

(defn step-blaster! [battle blaster]
  (case (get blaster :state)
    :enter
    (do
      (each pair [[:x :end-x] [:y :end-y] [:angle :end-angle]]
        (def field (get pair 0)) (def target (get blaster (get pair 1)))
        (def value (get blaster field))
        (put blaster field (if (<= (math/abs (- value target)) 3) target
                             (+ value (* (- target value) dt 10)))))
      (when (and (= (get blaster :x) (get blaster :end-x))
                 (= (get blaster :y) (get blaster :end-y))
                 (= (get blaster :angle) (get blaster :end-angle)))
        (put blaster :state :wait)))
    :wait
    (if (> (get blaster :timer-ticks) 0)
      (put blaster :timer-ticks (dec (get blaster :timer-ticks)))
      (do (put blaster :state :fire) (put blaster :timer-ticks 3)
          (put blaster :texture :sans/gaster-blaster/fire)))
    :fire
    (if (> (get blaster :timer-ticks) 0)
      (put blaster :timer-ticks (dec (get blaster :timer-ticks)))
      (do
        (put blaster :state :leave) (put blaster :beam-visible? true)
        (put blaster :damage 1)
        (emit! battle [:sound :sans/sfx-gaster-blast 1.2])
        (emit! battle [:sound :sans/sfx-gaster-blast-2 1.2])
        (when (> (get blaster :scale) 0.5) (put battle :sans-shake 5))))
    :leave
    (do
      (put blaster :leave-speed (+ (get blaster :leave-speed) 30))
      (def angle (radians (get blaster :angle)))
      (put blaster :x (- (get blaster :x) (* (math/cos angle) dt (get blaster :leave-speed))))
      (put blaster :y (- (get blaster :y) (* (math/sin angle) dt (get blaster :leave-speed))))
      (put blaster :beam-age (inc (get blaster :beam-age)))
      (def beam-age (get blaster :beam-age))
      (def target-size (* 35 (/ (get blaster :h) 44.0)))
      (if (<= beam-age 4)
        (put blaster :base-size (+ (get blaster :base-size) (math/floor (/ target-size 4))))
        (when (= beam-age 5) (put blaster :base-size target-size)))
      (when (> beam-age (+ 5 (get blaster :blast-ticks)))
        (put blaster :base-size (* (get blaster :base-size) 0.8))
        (put blaster :beam-opacity (- 100 (* (- beam-age (get blaster :blast-ticks) 5) 10))))
      (def sine-size (* (math/sin (/ beam-age 1.5)) (/ (get blaster :base-size) 4)))
      (put blaster :beam-size (+ (get blaster :base-size) sine-size))
      (when (< (get blaster :beam-opacity) 80) (put blaster :damage 0))
      (when (< (get blaster :base-size) 2) (put blaster :dead? true)))))

(defn spawn-menu-bone-left! [battle]
  (ensure-collections! battle)
  (def bone (base-hazard :menu-bone-left))
  (merge-into bone {:family :sprite :x -10 :y 270 :w 14 :h 44 :damage 1 :karma 0
                    :timer-ticks 0 :state :active :nonlethal? true
                    :texture :sans/menu-bone-left/default})
  (array/push (get battle :hazards) bone)
  bone)

(defn enable-bottom-menu-bones! [battle]
  (put battle :sans-bottom-bones? true)
  (put battle :sans-bottom-bone-ticks 0)
  (put battle :sans-bottom-bone-alternate 0))

(defn spawn-bottom-menu-bone! [battle button]
  (def bone (base-hazard :menu-bone-bottom))
  (merge-into bone {:family :sprite :x (get [142 294 454 606] button 142) :y 480
                    :w 14 :h 44 :damage 1 :karma 0 :button button :state :rise
                    :nonlethal? true :texture :sans/menu-bone-bottom/default})
  (array/push (get battle :hazards) bone))

(defn step-menu-bones! [battle]
  (when (get battle :sans-bottom-bones? false)
    (put battle :sans-bottom-bone-ticks (inc (get battle :sans-bottom-bone-ticks 0)))
    (when (>= (get battle :sans-bottom-bone-ticks) 18)
      (put battle :sans-bottom-bone-ticks 0)
      (def alternate (get battle :sans-bottom-bone-alternate 0))
      (spawn-bottom-menu-bone! battle alternate)
      (spawn-bottom-menu-bone! battle (+ 2 alternate))
      (put battle :sans-bottom-bone-alternate (- 1 alternate))))
  (each hazard (get battle :hazards @[])
    (case (get hazard :kind)
      :menu-bone-left
      (do
        (put hazard :timer-ticks (inc (get hazard :timer-ticks)))
        (put hazard :x
             (+ -30
                (* (math/abs
                     (math/sin
                      (radians
                       (/ (* 600 (/ (get hazard :timer-ticks) 30.0)) math/pi))))
                   105)))
        (when (and (get hazard :destroy? false) (< (get hazard :x) -8))
          (put hazard :dead? true)))
      :menu-bone-bottom
      (case (get hazard :state)
        :rise (do (put hazard :y (- (get hazard :y) (* 300 dt)))
                  (when (<= (get hazard :y) 440)
                    (put hazard :y 440) (put hazard :state :cross)))
        :cross (do (put hazard :x (- (get hazard :x) (* 150 dt)))
                   (def stop-x (- (get [32 184 344 496] (get hazard :button) 32) 14))
                   (when (<= (get hazard :x) stop-x)
                     (put hazard :x stop-x) (put hazard :state :fall)))
        :fall (do (put hazard :y (+ (get hazard :y) (* 300 dt)))
                  (when (> (get hazard :y) 480) (put hazard :dead? true)))))))

(defn step-linear-hazard! [hazard]
  (put hazard :x (+ (get hazard :x) (* (get hazard :vx 0) dt)))
  (put hazard :y (+ (get hazard :y) (* (get hazard :vy 0) dt)))
  (def dir (get hazard :direction 0))
  (when (case dir
          0 (> (get hazard :x) 640) 1 (> (get hazard :y) 480)
          2 (< (get hazard :x) (- (get hazard :w)))
          3 (< (get hazard :y) (- (get hazard :h))))
    (put hazard :dead? true)))

(defn step-hazards! [battle]
  (step-menu-bones! battle)
  (def hazards (get battle :hazards @[]))
  (each hazard hazards
    (put hazard :age (inc (get hazard :age 0)))
    (case (get hazard :kind)
      :bone-h (step-linear-hazard! hazard) :bone-v (step-linear-hazard! hazard)
      :stab-warning (step-stab! battle hazard) :bone-stab-h (step-stab! battle hazard)
      :bone-stab-v (step-stab! battle hazard) :gaster-blaster (step-blaster! battle hazard)))
  (def live @[])
  (each hazard hazards (unless (get hazard :dead? false) (array/push live hazard)))
  (put battle :hazards live))

(defn hazard-active? [hazard moving?]
  (and (> (get hazard :damage 0) 0)
       (case (get hazard :color :white) :blue moving? :orange (not moving?) true)))

(defn beam-overlap? [player blaster]
  (if (not (get blaster :beam-visible? false))
    false
    (let [angle (radians (get blaster :angle)) ux (math/cos angle) uy (math/sin angle)
          origin-x (+ (get blaster :x) (* ux 70 (get blaster :scale)))
          origin-y (+ (get blaster :y) (* uy 70 (get blaster :scale)))
          dx (- (get player :x) origin-x) dy (- (get player :y) origin-y)
          along (+ (* dx ux) (* dy uy))
          perpendicular (math/abs (- (* dy ux) (* dx uy)))]
      (and (>= along (- heart-half)) (<= along (+ 1000 heart-half))
           (<= perpendicular (+ (/ (* (get blaster :base-size) 0.75) 2) 2))))))

(defn hazard-overlap? [player hazard]
  (if (= (get hazard :shape) :beam)
    (beam-overlap? player hazard)
    (let [bounds (heart-bounds player)]
      (rect-overlap? (get bounds 0) (get bounds 1) heart-size heart-size
                     (get hazard :x) (get hazard :y) (get hazard :w 0) (get hazard :h 0)))))

(defn damage-player! [battle damage karma]
  (def player (get battle :player))
  (put player :hp (- (get player :hp) (numeric damage)))
  (put player :kr (+ (get player :kr) (numeric karma)))
  (put player :hurt-ticks 1)
  (emit! battle [:sound :sans/sfx-player-damaged]))

(defn resolve-hazard-hits! [battle]
  (def player (get battle :player))
  (when (and (> (get player :hp) 0)
             (>= (- (get battle :tick 0) (get battle :sans-last-damage-tick -1)) 1))
    (def hit
      (find (fn [hazard]
              (and (get hazard :visible? true)
                   (or (not= (get hazard :family) :sprite) (get player :visible? true))
                   (hazard-active? hazard (get player :moving? false))
                   (hazard-overlap? player hazard)))
            (get battle :hazards @[])))
    (when hit
      (put battle :sans-last-damage-tick (get battle :tick 0))
      (damage-player! battle (get hit :damage) (get hit :karma))
      (when (and (get hit :nonlethal? false) (<= (get player :hp) 0)) (put player :hp 1))
      (when (>= (get hit :karma) 3) (put hit :karma 2)))))

(defn step-kr! [player]
  (put player :hp (min (get player :max-hp) (get player :hp)))
  (put player :kr (min 40 (max 0 (get player :kr))))
  (when (>= (get player :kr) (get player :hp))
    (put player :kr (max 0 (dec (get player :hp)))))
  (if (and (> (get player :kr) 0) (> (get player :hp) 1))
    (do
      (put player :kr-t (inc (get player :kr-t 0)))
      (def threshold (cond (>= (get player :kr) 40) 1 (>= (get player :kr) 30) 2
                           (>= (get player :kr) 20) 5 (>= (get player :kr) 10) 15
                           :else 30))
      (when (>= (get player :kr-t) threshold)
        (put player :kr (dec (get player :kr)))
        (put player :hp (dec (get player :hp)))
        (put player :kr-t 0)))
    (put player :kr-t 0))
  player)

(defn hp-view [player]
  (def max-hp (get player :max-hp)) (def hp (get player :hp)) (def kr (get player :kr))
  (def width (math/floor (* max-hp 1.2)))
  {:background {:x 256 :y 400 :w width :h 21}
   :hp-bar {:x 256 :y 400 :w (* width (/ hp max-hp)) :h 21}
   :kr-bar {:x (+ 256 (* width (/ (- hp kr) max-hp))) :y 400
            :w (math/ceil (* width (/ kr max-hp))) :h 21}
   :text (string (if (< hp 10) "0" "") hp " / " max-hp)
   :text-color (if (> kr 0) [255 0 0 255] [255 255 255 255])})

(defn pose-name [name]
  (case name
    "Idle" :idle "HeadBob" :head-bob "Tired" :tired
    "HandUp" :hand-up "HandDown" :hand-down "HandLeft" :hand-left "HandRight" :hand-right
    "Default" :default "Shrug" :shrug "LookLeft" :look-left "Wink" :wink
    "ClosedEyes" :closed-eyes "NoEyes" :no-eyes "BlueEye" :blue-eye
    "Tired1" :tired-1 "Tired2" :tired-2 nil))

(def repeat-heads [:default :look-left :wink :closed-eyes :no-eyes])
(def repeat-torsos [:default :default :default :shrug])

(defn step-sans-animation! [battle]
  (when-let [enemy (sans battle)]
    (def animation (get enemy :animation nil))
    (if animation
      (do
        (put enemy :animation-ticks (inc (get enemy :animation-ticks 0)))
        (def t (/ (get enemy :animation-ticks) 30.0))
        (case animation
          :idle (do
                  (def local (% t 1.2))
                  (put enemy :torso-offset-x (math/sin (radians (/ (* 360 local) 1.2))))
                  (put enemy :torso-offset-y (math/sin (radians (/ (* 720 local) 1.2))))
                  (put enemy :head-offset-x 0)
                  (put enemy :head-offset-y (* -0.4 (math/sin (radians (/ (* 720 local) 1.2))))))
          :head-bob (do
                      (def local (% t 1.1))
                      (put enemy :torso-offset-x 0) (put enemy :torso-offset-y 0)
                      (put enemy :head-offset-x (math/sin (radians (/ (* 360 local) 1.1))))
                      (put enemy :head-offset-y (math/sin (radians (/ (* 720 local) 1.1)))))
          :tired (do
                   (def local (% t 3.8))
                   (def offset (math/sin (radians (/ (* 360 local) 3.8))))
                   (put enemy :torso-offset-x 0) (put enemy :torso-offset-y offset)
                   (put enemy :head-offset-x 0) (put enemy :head-offset-y offset))))
      (do
        (put enemy :animation-ticks 0) (put enemy :torso-offset-x 0)
        (put enemy :torso-offset-y 0) (put enemy :head-offset-x 0) (put enemy :head-offset-y 0)))
    (when (= (get enemy :head) :blue-eye)
      (put enemy :head-frame (math/rng-int (get battle :fx-rng) 2)))
    (when (not= (get enemy :x-speed 0) 0)
      (put enemy :y (- (get (get battle :arena) :top) 16))
      (put enemy :x (+ (get enemy :x) (* (get enemy :x-speed) dt)))
      (put enemy :x-speed (- (get enemy :x-speed) (* 45 dt)))
      (when (< (get enemy :x) -100)
        (put enemy :x 740)
        (put enemy :head (get repeat-heads (math/rng-int (get battle :fx-rng) (length repeat-heads))))
        (put enemy :torso (get repeat-torsos (math/rng-int (get battle :fx-rng) (length repeat-torsos))))))
    (when (= (get enemy :x-speed 0) 0)
      (put enemy :y (- (get (get battle :arena) :target-top) 16)))))

(defn black-screen! [battle enabled]
  (def on? (enabled? enabled))
  (put battle :black-screen? on?)
  (put (get battle :arena) :visible? (not on?))
  (if on?
    (do (array/clear (get battle :hazards @[])) (array/clear (get battle :platforms @[]))
        (emit! battle [:audio-resume-tag :music]) (emit! battle [:black-screen true]))
    (do (emit! battle [:audio-pause-tag :music]) (emit! battle [:black-screen false]))))

(defn pause-for-text! [battle attack text]
  (put attack :status :paused) (put attack :pause-reason :sans-text)
  (emit! battle [:sans/text text (get attack :generation)]))

(defn dispatch! [battle attack command args]
  (ensure-collections! battle)
  (def arg |(get args $ nil))
  (case command
    "BlackScreen" (black-screen! battle (arg 0))
    "Sound" (let [id (get sound-ids (arg 0) nil) rate (numeric (arg 1) 1)]
                (when id (emit! battle [:sound id rate])))
    "CombatZoneResize" (set-arena-target! battle (arg 0) (arg 1) (arg 2) (arg 3) (arg 4))
    "CombatZoneResizeInstant" (set-arena-instant! battle (arg 0) (arg 1) (arg 2) (arg 3))
    "CombatZoneSpeed" (put (get battle :arena) :speed (integer (arg 0)))
    "EndAttack" (put attack :ended? true)
    "BoneH" (spawn-bone! battle false (arg 0) (arg 1) (arg 2) (arg 3) (arg 4) (arg 5))
    "BoneV" (spawn-bone! battle true (arg 0) (arg 1) (arg 2) (arg 3) (arg 4) (arg 5))
    "BoneHRepeat" (spawn-bone-repeat! battle false (arg 0) (arg 1) (arg 2) (arg 3) (arg 4) (arg 5) (arg 6))
    "BoneVRepeat" (spawn-bone-repeat! battle true (arg 0) (arg 1) (arg 2) (arg 3) (arg 4) (arg 5) (arg 6))
    "SineBones" (spawn-sine-bones! battle (arg 0) (arg 1) (arg 2) (arg 3))
    "BoneStab" (spawn-stab-warning! battle (arg 0) (arg 1) (arg 2) (arg 3))
    "GasterBlaster" (spawn-blaster! battle (arg 0) (arg 1) (arg 2) (arg 3) (arg 4) (arg 5) (arg 6) (arg 7))
    "Platform" (spawn-platform! battle (arg 0) (arg 1) (arg 2) (arg 3) (arg 4) (arg 5))
    "PlatformRepeat" (spawn-platform-repeat! battle (arg 0) (arg 1) (arg 2) (arg 3) (arg 4) (arg 5) (arg 6))
    "HeartMode" (set-heart-mode! (get battle :player) (arg 0))
    "HeartTeleport" (let [player (get battle :player)]
                        (put player :x (integer (arg 0))) (put player :y (integer (arg 1)))
                        (put player :visible? true))
    "HeartMaxFallSpeed" (put (get battle :player) :max-fall-speed (integer (arg 0)))
    "SansSlam" (slam! battle (arg 0))
    "SansSlamDamage" (put (get battle :player) :slam-damage? (enabled? (arg 0)))
    "SansAnimation" (when-let [enemy (sans battle)]
                       (put enemy :body nil) (put enemy :animation (pose-name (arg 0))))
    "SansBody" (when-let [enemy (sans battle)]
                  (put enemy :animation nil) (put enemy :body (pose-name (arg 0))))
    "SansTorso" (when-let [enemy (sans battle)]
                   (put enemy :body nil) (put enemy :torso (pose-name (arg 0))))
    "SansHead" (when-let [enemy (sans battle)] (put enemy :head (pose-name (arg 0))))
    "SansSweat" (when-let [enemy (sans battle)]
                   (put enemy :sweat (max 0 (min 3 (integer (arg 0))))))
    "SansX" (when-let [enemy (sans battle)] (put enemy :x (integer (arg 0))))
    "SansRepeat" (when-let [enemy (sans battle)] (put enemy :x-speed -900))
    "SansEndRepeat" (when-let [enemy (sans battle)] (put enemy :x-speed 0))
    "SansText" (pause-for-text! battle attack (arg 0))
    "MenuBoneLeft" (spawn-menu-bone-left! battle)
    "MenuBoneBottom" (enable-bottom-menu-bones! battle)
    (do (put attack :status :error)
        (put attack :error (string "unknown Sans mechanics command: " command))))
  nil)

(defn step! [battle input]
  (ensure-collections! battle)
  # Source order: platforms, SOUL, attacks, arena, Sans, damage, KR.
  (step-platforms! battle)
  (if (= (get battle :phase nil) :enemy-attack)
    (move-heart! battle input)
    (do
      (put (get battle :player) :moving? false)
      (put (get battle :player) :vx 0)
      (put (get battle :player) :vy 0)))
  (step-hazards! battle)
  (step-arena! battle)
  (step-sans-animation! battle)
  (resolve-hazard-hits! battle)
  (step-kr! (get battle :player))
  (when (> (get (get battle :player) :hurt-ticks 0) 0)
    (put (get battle :player) :hurt-ticks (dec (get (get battle :player) :hurt-ticks))))
  (when (> (get battle :sans-shake 0) 0)
    (put battle :sans-shake (dec (get battle :sans-shake))))
  battle)
