(import ../src/battle)
(import ../src/dialogue)
(import ../src/encounters/froggit)

(def no-input @{})

(defn step-n!
  [state n &opt input]
  (for _ 0 n
    (battle/step! state (default input no-input)))
  state)

(defn prepare-player-turn
  [&opt seed]
  (def state (battle/new-battle (default seed 1)))
  (step-n! state 14)
  state)

(defn approx=
  [a b tolerance]
  (< (math/abs (- a b)) tolerance))

(def mock-enemy-def
  {:name "Dummy" :max-hp 10 :attack 2 :defense 0 :acts []})

(defn new-mock-enemy
  []
  @{:id 42 :def mock-enemy-def :hp 10 :spare-progress 0})


(defn new-mock-enemies
  []
  @[(new-mock-enemy)])
(def mock-encounter
  {:id :mock
   :enemy-def mock-enemy-def
   :new-enemies new-mock-enemies
   :flavor-text (fn [enemy category rng] "* Dummy waits.")
   :apply-act! (fn [enemy act-id] nil)
   :can-spare? (fn [enemy] false)
   :start-attack! (fn [state player] nil)
   :step-enemy! (fn [enemy] enemy)
   :render-layers []
   :kill-victory "won"
   :spare-victory "spared"})

# Arena expansion is the source's 410-pixel change at 30 pixels per tick.
(let [state (battle/new-battle 10)
      arena (get state :arena)]
  (assert (= (get (get arena :rect) 2) 155))
  (step-n! state 13)
  (assert (get arena :resizing?))
  (battle/step! state no-input)
  (assert (not (get arena :resizing?)))
  (assert (= (get (get arena :rect) 0) 37))
  (assert (= (get (get arena :rect) 2) 565))
  (assert (= (+ (get (get arena :rect) 1) (get (get arena :rect) 3)) 385)))

# FIGHT deals 3..7 damage and requires confirmation before the enemy turn.
(let [state (prepare-player-turn 20)
      enemy (get (get state :enemies) 0)]
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :player-result))
  (assert (<= 23 (get enemy :hp) 27))
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :enemy-attack))
  (assert (> (length (get state :bullets)) 0)))

# ACT/Compliment modifies only the selected enemy instance and enables Spare.
(let [state (prepare-player-turn 30)
      enemy (get (get state :enemies) 0)]
  (battle/step! state @{:right true})
  (battle/step! state @{:confirm true})
  (assert (= (get (get state :menu) :screen) :act))
  (battle/step! state @{:right true})
  (battle/step! state @{:confirm true})
  (assert (= (get enemy :spare-progress) 1))
  (assert (froggit/can-spare? enemy))
  (assert (= (get state :phase) :player-result)))

# ITEM consumes one entry and clamps healing to maximum HP.
(let [state (prepare-player-turn 40)
      player (get state :player)]
  (put player :hp 5)
  (battle/step! state @{:right true})
  (battle/step! state @{:right true})
  (battle/step! state @{:confirm true})
  (assert (= (get (get state :menu) :screen) :item))
  (battle/step! state @{:confirm true})
  (assert (= (get player :hp) 15))
  (assert (= (length (get state :inventory)) 3))
  (assert (= (get state :phase) :player-result)))

# MERCY succeeds through ACT progress and completes after 121 victory ticks.
(let [state (prepare-player-turn 50)
      enemy (get (get state :enemies) 0)]
  (put enemy :spare-progress 1)
  (for _ 0 3 (battle/step! state @{:right true}))
  (battle/step! state @{:confirm true})
  (assert (= (get (get state :menu) :screen) :mercy))
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :victory))
  (step-n! state 120)
  (assert (not (get state :complete?)))
  (battle/step! state no-input)
  (assert (get state :complete?))
  (assert (= (get state :outcome) :victory)))

# Collision damages once, removes the successful bullet, and preserves overlap during immunity.
(let [state (battle/new-battle 60)
      player (get state :player)
      bullets (get state :bullets)]
  (array/clear bullets)
  (array/push bullets @{:x (get player :x) :y (get player :y) :w 12 :h 12})
  (battle/resolve-bullet-hits! state)
  (assert (= (get player :hp) 16))
  (assert (= (get player :hurt-ticks) 28))
  (assert (empty? bullets))
  (array/push bullets @{:x (get player :x) :y (get player :y) :w 12 :h 12})
  (battle/resolve-bullet-hits! state)
  (assert (= (get player :hp) 16))
  (assert (= (length bullets) 1)))

# Pattern construction and first update preserve source coordinates.
(let [state (battle/new-battle 70)
      player (get state :player)
      bullets (get state :bullets)]
  (put player :x 312)
  (put player :y 312)
  (array/clear bullets)
  (froggit/spawn-fly-line! state)
  (assert (= (length bullets) 6))
  (assert (= (get (get bullets 0) :x) 100))
  (assert (= (get (get bullets 0) :y) 225))
  (battle/step-bullet! (get bullets 0))
  (assert (= (get (get bullets 0) :x) 105))

  (array/clear bullets)
  (froggit/spawn-sine! state player)
  (battle/step-bullet! (get bullets 0))
  (assert (= (get (get bullets 0) :x) -34.5))
  (assert (approx= (get (get bullets 0) :y)
                   (+ 312 (* 40 (math/sin 0.1)))
                   0.0001))

  (array/clear bullets)
  (froggit/spawn-triangle! state player)
  (assert (= (length bullets) 6))
  (array/clear bullets)
  (froggit/spawn-window! state player)
  (assert (= (length bullets) 8)))

# A fixed seed gives the same attack choice without cosmetic RNG interference.
(let [a (battle/new-battle 80)
      b (battle/new-battle 80)]
  (array/clear (get a :bullets))
  (array/clear (get b :bullets))
  (assert (= (froggit/start-random-attack! a (get a :player))
             (froggit/start-random-attack! b (get b :player)))))

# A fatal final bullet reproduces the source's player-turn reposition, then
# completes after the final black FadeOut tick.
(let [state (battle/new-battle 90)
      player (get state :player)]
  (put player :hp 4)
  (array/clear (get state :bullets))
  (array/push (get state :bullets)
              @{:x (get player :x) :y (get player :y) :w 12 :h 12})
  (battle/resolve-bullet-hits! state)
  (assert (= (get state :phase) :death))
  (assert (= [(get (get state :death) :x) (get (get state :death) :y)]
             [40 446]))
  (step-n! state 150)
  (assert (= (get (get state :death) :stage) :fade-out))
  (assert (not (get state :complete?)))
  (battle/step! state no-input)
  (assert (get state :complete?))
  (assert (= (get state :outcome) :game-over)))

# HP below 10 independently enables Spare.
(let [enemy (froggit/new-instance)]
  (put enemy :hp 9)
  (assert (froggit/can-spare? enemy)))

# Cancel restores the selected command and failed MERCY consumes a turn.
(let [state (prepare-player-turn 100)]
  (battle/step! state @{:right true})
  (battle/step! state @{:confirm true})
  (battle/step! state @{:cancel true})
  (assert (= (get (get state :menu) :screen) :commands))
  (assert (= (get (get state :menu) :cursor) 1))
  (battle/step! state @{:right true})
  (battle/step! state @{:right true})
  (battle/step! state @{:confirm true})
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :player-result))
  (assert (get (get state :player) :visible?))
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :enemy-attack)))

# Empty ITEM is safe and still resolves as an action.
(let [state (prepare-player-turn 110)]
  (array/clear (get state :inventory))
  (battle/step! state @{:right true})
  (battle/step! state @{:right true})
  (battle/step! state @{:confirm true})
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :player-result)))

# The hard six-second limit returns control even for persistent bullets.
(let [state (prepare-player-turn 120)]
  (battle/start-enemy-turn! state)
  (put state :enemy-turn-ticks 179)
  (battle/step! state no-input)
  (assert (= (get state :phase) :player-menu))
  (assert (empty? (get state :bullets))))

# Encounter callbacks and target IDs let another enemy use the engine unchanged.
(let [state (battle/new-battle 130 mock-encounter)
      first-enemy (get (get state :enemies) 0)
      second-enemy (new-mock-enemy)]
  (put second-enemy :id 43)
  (array/push (get state :enemies) second-enemy)
  (battle/select-target! state 43)
  (assert (= (get (battle/active-enemy state) :id) 43))
  (battle/resolve-fight! state)
  (assert (= (get first-enemy :hp) 10))
  (assert (<= 3 (- 10 (get second-enemy :hp)) 7)))

# Dialogue retains the one-start-update and two-tick character cadence.
(let [text (dialogue/new)]
  (dialogue/set-text! text "AB" 0)
  (dialogue/step! text)
  (assert (= (dialogue/visible-text text) ""))
  (dialogue/step! text)
  (assert (= (dialogue/visible-text text) ""))
  (dialogue/step! text)
  (assert (= (dialogue/visible-text text) "A")))

(print "battle tests passed")
