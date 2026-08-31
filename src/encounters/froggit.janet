(def definition
  {:id :froggit
   :name "Froggit"
   :max-hp 30
   :attack 4
   :defense 5
   :spare-threshold 1
   :position [215 135]
   :acts [{:id :check :label "Check" :spare-progress 0}
          {:id :compliment :label "Compliment" :spare-progress 1}
          {:id :threaten :label "Threaten" :spare-progress 1}]
   :flavor
   {:check ["* Life is difficult for this enemy."]
    :encounter ["* Froggit hopped close!"]
    :neutral ["* Froggit doesn't seem to\n  know why it's here."
              "* Froggit hops to and fro."
              "* The battlefield is filled\n  with the smell of mustard seed."
              "* You are intimidated by\n  Froggit's raw strength. Only kidding."]
    :compliment ["* Froggit didn't understand what\n  you said, but was flattered anyway."]
    :threaten ["* Froggit didn't understand what\n  you said, but was scared anyway."]
    :low-hp ["* Froggit is trying to run away."]
    :spare ["* Froggit seems reluctant to fight you."]}
   :quotes
   {:neutral ["Ribbit, ribbit." "Croak, croak." "Hop, hop." "Meow."]
    :compliment ["(Blushes deeply.) Ribbit.."]
    :threaten ["Shiver, shiver."]}})

(defn new-instance
  []
  @{:id 1
    :def definition
    :hp (get definition :max-hp)
    :spare-progress 0
    :x 215
    :y 135
    :leg-frame 0
    :leg-ticks 0
    :head-frame 0
    :head-ticks 0
    :motion-ticks 0})

(defn new-enemies
  []
  @[(new-instance)])

(defn can-spare?
  [enemy]
  (or (>= (get enemy :spare-progress) (get definition :spare-threshold))
      (< (get enemy :hp) 10)))

(defn random-line
  [lines rng]
  (if (empty? lines)
    "[NO TEXT]"
    (get lines (math/rng-int rng (length lines)))))

(defn flavor-text
  [enemy category rng]
  (if (= category :check)
    (string "* " (get definition :name)
            " - ATK " (get definition :attack)
            " DEF " (get definition :defense) "\n"
            (random-line (get (get definition :flavor) :check) rng))
    (let [resolved (if (= category :neutral)
                     (cond
                       (< (get enemy :hp) 10) :low-hp
                       (can-spare? enemy) :spare
                       :else :neutral)
                     category)
          lines (get (get definition :flavor) resolved)]
      (if lines (random-line lines rng) "[NO TEXT]"))))

(defn apply-act!
  [enemy act-id]
  (def act (find |(= act-id (get $ :id)) (get definition :acts)))
  (when act
    (put enemy :spare-progress
         (min (get definition :spare-threshold)
              (+ (get enemy :spare-progress) (get act :spare-progress)))))
  act)

(defn step-linear!
  [bullet]
  (put bullet :x (+ (get bullet :x) (get bullet :vx)))
  (put bullet :y (+ (get bullet :y) (get bullet :vy))))

(defn step-sine!
  [bullet]
  (put bullet :x (+ (get bullet :x) (get bullet :speed)))
  (put bullet :y
       (+ (get bullet :start-y)
          (* (get bullet :amplitude)
             (math/sin (+ (* (get bullet :frequency) (get bullet :age))
                          (get bullet :phase)))))))

(defn step-oscillate!
  [bullet]
  (let [direction (if (get bullet :forward?) 1 -1)
        delta (* direction (get bullet :speed))]
    (put bullet :x (+ (get bullet :x) (* (get bullet :dir-x) delta)))
    (put bullet :y (+ (get bullet :y) (* (get bullet :dir-y) delta)))
    (when (or (< (get bullet :x) (- (get bullet :center-x) (get bullet :half-x)))
              (> (get bullet :x) (+ (get bullet :center-x) (get bullet :half-x)))
              (< (get bullet :y) (- (get bullet :center-y) (get bullet :half-y)))
              (> (get bullet :y) (+ (get bullet :center-y) (get bullet :half-y))))
      (put bullet :forward? (not (get bullet :forward?))))))

(def motion-steps
  {:linear step-linear!
   :sine step-sine!
   :oscillate step-oscillate!})

(defn bullet
  [motion x y]
  @{:kind :fly
    :textures [:fly-0 :fly-1]
    :motion motion
    :step! (get motion-steps motion)
    :x x :y y :w 12 :h 12
    :damage (get definition :attack)
    :owner-id 1
    :vx 0 :vy 0
    :age 0
    :frame 0
    :anim-ticks 0})

(defn add-linear!
  [battle x y vx vy]
  (def b (bullet :linear x y))
  (put b :vx vx)
  (put b :vy vy)
  (array/push (get battle :bullets) b)
  b)

(defn spawn-triangle!
  [battle player]
  (for i 0 6
    (def offset (- i 3))
    (add-linear! battle
                 (+ (- (get player :x) 250) (* 25 (math/abs offset)))
                 (+ (get player :y) (* 30 offset))
                 5 0)))

(defn spawn-sine!
  [battle player]
  (for i 0 7
    (def b (bullet :sine (+ (- (get player :x) 350) (* 40 i)) (get player :y)))
    (put b :start-y (get player :y))
    (put b :speed 3.5)
    (put b :amplitude 40)
    (put b :frequency 0.1)
    (put b :phase (* i 0.5))
    (array/push (get battle :bullets) b)))

(def window-offsets
  [[-50 -30] [50 -30] [-50 30] [50 30]
   [0 -30] [0 30] [-50 0] [50 0]])

(defn spawn-window!
  [battle player]
  (each offset window-offsets
    (def x (+ (get player :x) (get offset 0)))
    (def y (+ (get player :y) (get offset 1)))
    (def b (bullet :oscillate x y))
    (put b :center-x x)
    (put b :center-y y)
    (put b :half-x 50)
    (put b :half-y 30)
    (put b :dir-x 1)
    (put b :dir-y 0)
    (put b :speed 1)
    (put b :forward? true)
    (array/push (get battle :bullets) b)))

(defn spawn-fly-line!
  [battle]
  (for i 0 6
    (add-linear! battle 100 (+ 225 (* i 30)) 5 0)))

(defn start-random-attack!
  [battle player]
  (def pattern (math/rng-int (get battle :combat-rng) 4))
  (case pattern
    0 (spawn-triangle! battle player)
    1 (spawn-sine! battle player)
    2 (spawn-window! battle player)
    3 (spawn-fly-line! battle))
  (put battle :last-pattern pattern)
  pattern)

(defn step-animation!
  [enemy]
  (put enemy :motion-ticks (inc (get enemy :motion-ticks)))
  (put enemy :leg-ticks (inc (get enemy :leg-ticks)))
  (put enemy :head-ticks (inc (get enemy :head-ticks)))
  (when (> (get enemy :leg-ticks) 30)
    (put enemy :leg-frame (% (inc (get enemy :leg-frame)) 2))
    (put enemy :leg-ticks 0))
  (when (> (get enemy :head-ticks) 60)
    (put enemy :head-frame (% (inc (get enemy :head-frame)) 2))
    (put enemy :head-ticks 0))
  enemy)

(defn head-position
  [enemy]
  (def seconds (/ (get enemy :motion-ticks) 30.0))
  [(+ (get enemy :x) (* 2.5 (math/sin (+ (* 5.0 seconds) 1.0))))
   (+ (get enemy :y) (* 2.5 (math/cos (* 5.5 seconds))) 3)])

(defn body-position
  [enemy]
  [(get enemy :x) (get enemy :y)])

(def encounter
  {:id :froggit
   :assets
   {:textures
    {:fly-0 "assets/img/spr_flybullet_0.png"
     :fly-1 "assets/img/spr_flybullet_1.png"
     :frog-head-0 "assets/img/spr_froghead_0.png"
     :frog-head-1 "assets/img/spr_froghead_1.png"
     :frog-legs-0 "assets/img/spr_froglegs_0.png"
     :frog-legs-1 "assets/img/spr_froglegs_1.png"}}
   :enemy-def definition
   :new-enemies new-enemies
   :flavor-text flavor-text
   :apply-act! apply-act!
   :can-spare? can-spare?
   :start-attack! start-random-attack!
   :step-enemy! step-animation!
   :render-layers
   [{:frame-key :leg-frame
     :textures [:frog-legs-0 :frog-legs-1]
     :position body-position}
    {:frame-key :head-frame
     :textures [:frog-head-0 :frog-head-1]
     :position head-position}]
   :kill-victory "* YOU WON!\n* Victory tastes a bit like regret."
   :spare-victory "* YOU WON!\n* Froggit lives to croak another day."})
