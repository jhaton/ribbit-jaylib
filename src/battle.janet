(import ./dialogue)
(import ./encounters/froggit)

(def ticks-per-second 30)
(def enemy-turn-ticks (* 6 ticks-per-second))
(def victory-duration-ticks 121)

(def command-ids [:fight :act :item :mercy])
(def command-player-positions [[40 446] [193 446] [353 446] [508 446]])
(def submenu-player-positions [[54 276] [314 276] [54 318] [314 318]])

(def item-defs
  {:monster-candy {:name "Monster Candy" :short "MnstrCndy" :heal 10}
   :spider-donut {:name "Spider Donut" :short "SpidrDont" :heal 12}
   :butterscotch-pie {:name "Butterscotch Pie" :short "ButtsPie" :heal 20}
   :spider-cider {:name "Spider Cider" :short "SpidrCidr" :heal 18}})

(defn event!
  [battle event]
  (array/push (get battle :events) event))

(defn drain-events!
  [battle]
  (def events (get battle :events))
  (put battle :events @[])
  events)

(defn pressed?
  [input action]
  (get input action false))

(defn enemy-definition
  [battle]
  (get (get battle :encounter) :enemy-def))

(defn enemy-by-id
  [battle enemy-id]
  (find |(= enemy-id (get $ :id)) (get battle :enemies)))

(defn active-enemy
  [battle]
  (def target-id (get (get battle :menu) :target-id nil))
  (or (and target-id (enemy-by-id battle target-id))
      (first (get battle :enemies))))

(defn select-target!
  [battle enemy-id]
  (when-let [enemy (enemy-by-id battle enemy-id)]
    (put (get battle :menu) :target-id enemy-id)
    enemy))

(defn encounter-function
  [battle key]
  (get (get battle :encounter) key))

(defn set-player-position!
  [player position]
  (put player :x (get position 0))
  (put player :y (get position 1)))

(defn encounter-position
  [battle key fallback index]
  (def positions (get (get battle :encounter) key fallback))
  (get positions (% index (length positions))))


(defn arena-center
  [arena]
  (if-let [rect (get arena :rect)]
    [(+ (get rect 0) (/ (get rect 2) 2.0))
     (+ (get rect 1) (/ (get rect 3) 2.0))]
    [(/ (+ (get arena :left) (get arena :right)) 2.0)
     (/ (+ (get arena :top) (get arena :bottom)) 2.0)]))

(defn center-player!
  [battle]
  (def center (arena-center (get battle :arena)))
  # Preserve Player::centerPlayer: resetting the origin leaves top-left at center.
  (put (get battle :player) :x (get center 0))
  (put (get battle :player) :y (get center 1)))

(defn set-arena-target!
  [arena target]
  (put arena :target target)
  (put arena :resizing? true))

(defn start-player-turn!
  [battle]
  (def prior-target-id (get (get battle :menu) :target-id nil))
  (def target
    (or (and prior-target-id (enemy-by-id battle prior-target-id))
        (first (get battle :enemies))))
  (put battle :phase :player-menu)
  (put battle :enemy-turn-ticks 0)
  (put battle :menu @{:screen :commands
                       :cursor 0
                       :saved-command 0
                       :target-id (get target :id)})
  (put (get battle :player) :visible? true)
  (put (get battle :player) :sprite :normal)
  (set-player-position! (get battle :player)
                        (encounter-position battle :command-player-positions
                                            command-player-positions 0))
  (set-arena-target! (get battle :arena) @[37 255 565 130])
  (dialogue/set-text! (get battle :dialogue)
                      ((encounter-function battle :flavor-text)
                       (active-enemy battle)
                       :neutral
                       (get battle :dialogue-rng))
                      0.5)
  battle)

(defn default-player
  []
  @{:x 312 :y 232 :w 16 :h 16
    :hp 20 :max-hp 20 :mode :red
    :hurt-ticks 0 :sprite :normal :visible? true})

(defn default-arena
  []
  @{:rect @[242 255 155 130]
    :target @[242 255 155 130]
    :speed 30
    :resizing? false})

(defn encounter-factory
  [encounter key fallback]
  (if-let [factory (get encounter key)]
    (factory)
    (fallback)))

(defn new-battle
  [&opt seed encounter-definition]
  (def s (default seed 1))
  (def encounter (default encounter-definition froggit/encounter))
  (def battle
    @{:phase :player-menu
      :tick 0
      :turn 0
      :combat-rng (math/rng s)
      :dialogue-rng (math/rng (+ s 1))
      :fx-rng (math/rng (+ s 2))
      :encounter encounter
      :player (encounter-factory encounter :new-player default-player)
      :arena (encounter-factory encounter :new-arena default-arena)
      :enemies (encounter-factory encounter :new-enemies |@[])
      :bullets @[]
      :hazards @[]
      :platforms @[]
      :attack nil
      :inventory @[:monster-candy :spider-donut :butterscotch-pie :spider-cider]
      :menu @{}
      :dialogue (dialogue/new)
      :enemy-turn-ticks 0
      :victory-ticks 0
      :death nil
      :shake-ticks 0
      :last-pattern nil
      :events @[]
      :complete? false
      :outcome nil})
  (def initial-music
    (get encounter :music (if (get encounter :start! nil) nil :battle)))
  (when initial-music
    (event! battle [:music initial-music]))
  (if-let [start (get encounter :start!)]
    (do (start battle) battle)
    (start-player-turn! battle)))

(defn step-arena!
  [arena]
  (when (and (get arena :rect nil) (get arena :resizing?))
    (def rect (get arena :rect))
    (def target (get arena :target))
    (def speed (get arena :speed))
    (def width-diff (- (get target 2) (get rect 2)))
    (def height-diff (- (get target 3) (get rect 3)))
    (if (and (< (math/abs width-diff) speed)
             (< (math/abs height-diff) speed))
      (do
        (put arena :rect @[(get target 0) (get target 1) (get target 2) (get target 3)])
        (put arena :resizing? false))
      (let [width-step (max (- speed) (min speed width-diff))
            height-step (max (- speed) (min speed height-diff))
            bottom (+ (get rect 1) (get rect 3))]
        (put rect 0 (- (get rect 0) (/ width-step 2.0)))
        (put rect 1 (- bottom (+ (get rect 3) height-step)))
        (put rect 2 (+ (get rect 2) width-step))
        (put rect 3 (+ (get rect 3) height-step)))))
  arena)

(defn clamp-player!
  [battle]
  (def player (get battle :player))
  (def rect (get (get battle :arena) :rect))
  # These limits reproduce BattleBox's effective one-pixel inner margin.
  (put player :x (max (+ (get rect 0) 1)
                      (min (- (+ (get rect 0) (get rect 2)) (get player :w) 1)
                           (get player :x))))
  (put player :y (max (+ (get rect 1) 1)
                      (min (- (+ (get rect 1) (get rect 3)) (get player :h) 1)
                           (get player :y)))))

(defn move-player!
  [battle input]
  (def player (get battle :player))
  (var dx 0)
  (var dy 0)
  (when (pressed? input :up-down) (-= dy 4))
  (when (pressed? input :down-down) (+= dy 4))
  (when (pressed? input :left-down) (-= dx 4))
  (when (pressed? input :right-down) (+= dx 4))
  (put player :x (+ (get player :x) dx))
  (put player :y (+ (get player :y) dy))
  (clamp-player! battle))

(defn overlaps?
  [a b]
  (and (< (get a :x) (+ (get b :x) (get b :w)))
       (> (+ (get a :x) (get a :w)) (get b :x))
       (< (get a :y) (+ (get b :y) (get b :h)))
       (> (+ (get a :y) (get a :h)) (get b :y))))

(defn start-death!
  [battle]
  (def player (get battle :player))
  (put battle :phase :death)
  (put battle :death @{:stage :show-player
                       :ticks 0
                       :x (get player :x)
                       :y (get player :y)
                       :shards @[]})
  (event! battle [:stop-music]))

(defn resolve-bullet-hits!
  [battle]
  (def player (get battle :player))
  (def bullets (get battle :bullets))
  (var i 0)
  (while (< i (length bullets))
    (def bullet (get bullets i))
    (if (and (overlaps? player bullet)
             (<= (get player :hurt-ticks) 0))
      (do
        (put player :hp
             (max 0 (- (get player :hp)
                       (get bullet :damage (get (enemy-definition battle) :attack)))))
        (array/remove bullets i)
        (if (<= (get player :hp) 0)
          (do
            (start-death! battle)
            # The source immediately restarts the player turn when the fatal
            # projectile was also the last bullet, moving the death sprite.
            (when (empty? bullets)
              (set-player-position! player (get command-player-positions 0))
              (put (get battle :death) :x (get player :x))
              (put (get battle :death) :y (get player :y))))
          (do
            (put player :hurt-ticks 28)
            (put battle :shake-ticks 2)
            (event! battle [:sound :hurt]))))
      (++ i))))

(defn offscreen?
  [bullet]
  (or (< (get bullet :x) 0)
      (> (get bullet :x) 640)
      (< (get bullet :y) 0)
      (> (get bullet :y) 480)))

(defn step-bullet!
  [bullet]
  (put bullet :age (inc (get bullet :age)))
  ((get bullet :step!) bullet)
  (put bullet :anim-ticks (inc (get bullet :anim-ticks)))
  (when (> (get bullet :anim-ticks) 3)
    (put bullet :frame (% (inc (get bullet :frame)) 2))
    (put bullet :anim-ticks 0)))

(defn step-bullets!
  [battle]
  (def bullets (get battle :bullets))
  # C++ removes pre-update offscreen bullets, then updates the survivors.
  (var i 0)
  (while (< i (length bullets))
    (if (offscreen? (get bullets i))
      (array/remove bullets i)
      (do
        (step-bullet! (get bullets i))
        (++ i)))))

(defn step-player-hurt!
  [player]
  (when (> (get player :hurt-ticks) 0)
    (def phase-index (% (math/floor (/ (- (get player :hurt-ticks) 1) 2)) 2))
    (put player :sprite (if (= phase-index 1) :hurt :normal))
    (put player :hurt-ticks (dec (get player :hurt-ticks)))
    (when (= (get player :hurt-ticks) 0)
      (put player :sprite :normal))))

(defn change-command!
  [battle delta]
  (def menu (get battle :menu))
  (def next (% (+ (get menu :cursor) delta (length command-ids)) (length command-ids)))
  (put menu :cursor next)
  (set-player-position! (get battle :player)
                        (encounter-position battle :command-player-positions
                                            command-player-positions next))
  (event! battle [:sound (get (get battle :encounter)
                              :menu-cursor-sound :squeak)]))

(defn enter-submenu!
  [battle command]
  (def menu (get battle :menu))
  (put menu :saved-command (get menu :cursor))
  (put menu :screen command)
  (put menu :cursor 0)
  (center-player! battle)
  (dialogue/clear! (get battle :dialogue))
  (case command
    :fight (do)
    :act (set-player-position!
           (get battle :player)
           (encounter-position battle :submenu-player-positions
                               submenu-player-positions 0))
    :item (when (not (empty? (get battle :inventory)))
            (set-player-position!
              (get battle :player)
              (encounter-position battle :submenu-player-positions
                                  submenu-player-positions 0)))
    :mercy (set-player-position!
             (get battle :player)
             (encounter-position battle :submenu-player-positions
                                 submenu-player-positions 0))))

(defn exit-submenu!
  [battle]
  (def menu (get battle :menu))
  (def command-index (get menu :saved-command))
  (put menu :screen :commands)
  (put menu :cursor command-index)
  (set-player-position! (get battle :player)
                        (encounter-position battle :command-player-positions
                                            command-player-positions command-index))
  (if-let [flavor-text (encounter-function battle :flavor-text)]
    (dialogue/set-text! (get battle :dialogue)
                        (flavor-text (active-enemy battle)
                                     :neutral
                                     (get battle :dialogue-rng))
                        0)
    (dialogue/clear! (get battle :dialogue))))

(defn start-victory!
  [battle message]
  (put battle :phase :victory)
  (put battle :victory-ticks 0)
  (put (get battle :player) :visible? false)
  (dialogue/set-text! (get battle :dialogue) message 0)
  (event! battle [:stop-music])
  (event! battle [:sound :vaporized]))

(defn resolve-fight!
  [battle]
  (if-let [resolve (encounter-function battle :resolve-fight!)]
    (resolve battle)
    (do
      (def enemy (active-enemy battle))
      (def damage (+ 3 (math/rng-int (get battle :combat-rng) 5)))
      (put enemy :hp (- (get enemy :hp) damage))
      (dialogue/set-text! (get battle :dialogue)
                          (string "* You dealt " damage " damage to "
                                  (get (get enemy :def) :name) ". \n"
                                  (get enemy :hp) " HP remaining.")
                          0)
      (put (get battle :player) :visible? false)
      (event! battle [:sound :laz])
      (if (<= (get enemy :hp) 0)
        (start-victory! battle (get (get battle :encounter) :kill-victory))
        (put battle :phase :player-result)))))

(defn resolve-act!
  [battle index]
  (def enemy (active-enemy battle))
  (def acts (get (get enemy :def) :acts))
  (when (< index (length acts))
    (def act (get acts index))
    ((encounter-function battle :apply-act!) enemy (get act :id))
    (dialogue/set-text! (get battle :dialogue)
                        ((encounter-function battle :flavor-text)
                         enemy (get act :id) (get battle :dialogue-rng))
                        0)
    (put (get battle :player) :visible? false)
    (put battle :phase :player-result)))

(defn resolve-item!
  [battle index]
  (def inventory (get battle :inventory))
  (if (empty? inventory)
    (dialogue/set-text! (get battle :dialogue) "* You have no items." 0)
    (when (< index (length inventory))
      (def item-id (get inventory index))
      (def item (get item-defs item-id))
      (def player (get battle :player))
      (def old-hp (get player :hp))
      (put player :hp (min (get player :max-hp) (+ old-hp (get item :heal))))
      (array/remove inventory index)
      (dialogue/set-text! (get battle :dialogue)
                          (string "* You used the " (get item :name) ".\n"
                                  "* You recovered " (- (get player :hp) old-hp) " HP!")
                          0)
      (event! battle [:sound :heal])))
  (put (get battle :player) :visible? false)
  (put battle :phase :player-result))

(defn resolve-mercy!
  [battle]
  (if-let [resolve (encounter-function battle :resolve-mercy!)]
    (resolve battle)
    (let [enemy (active-enemy battle)]
      (if ((encounter-function battle :can-spare?) enemy)
        (start-victory! battle (get (get battle :encounter) :spare-victory))
        (do
          (dialogue/clear! (get battle :dialogue))
          (put battle :phase :player-result))))))

(defn confirm-command!
  [battle]
  (def command (get command-ids (get (get battle :menu) :cursor)))
  (event! battle [:sound (get (get battle :encounter)
                              :menu-select-sound :select)])
  (enter-submenu! battle command)
  (case command
    :fight (resolve-fight! battle)
    :act nil
    :item nil
    :mercy nil))

(defn default-command-options
  [battle screen]
  (case screen
    :act (get (get (active-enemy battle) :def) :acts)
    :item (map |{:id $ :text (string "* " (get (get item-defs $) :short))}
               (get battle :inventory))
    :mercy [{:id :spare :text "* Spare"}]
    @[]))

(defn command-options
  [battle screen]
  (if-let [options (encounter-function battle :command-options)]
    (or (options battle screen) @[])
    (default-command-options battle screen)))

(defn option-id
  [option index]
  (cond
    (dictionary? option) (get option :id index)
    (keyword? option) option
    :else index))

(defn option-text
  [option]
  (cond
    (string? option) option
    (keyword? option) (string option)
    (dictionary? option)
    (or (get option :text nil)
        (string "* " (get option :label (get option :id))))
    :else (string option)))

(defn resolve-act-option!
  [battle index]
  (def options (command-options battle :act))
  (when (< index (length options))
    (if-let [resolve (encounter-function battle :resolve-act!)]
      (resolve battle (option-id (get options index) index))
      (resolve-act! battle index))))

(defn resolve-item-option!
  [battle index]
  (def options (command-options battle :item))
  (if (< index (length options))
    (if-let [resolve (encounter-function battle :resolve-item!)]
      (resolve battle (option-id (get options index) index))
      (resolve-item! battle index))
    # Preserve the original empty-inventory action for encounters using the
    # generic ITEM resolver.
    (unless (encounter-function battle :resolve-item!)
      (resolve-item! battle index))))

(defn submenu-option-count
  [battle screen]
  (length (command-options battle screen)))

(defn move-submenu!
  [battle direction]
  (def menu (get battle :menu))
  (def screen (get menu :screen))
  (def count (submenu-option-count battle screen))
  (when (> count 0)
    (def index (get menu :cursor))
    (def row (math/floor (/ index 2)))
    (def col (% index 2))
    (var next index)
    (case direction
      :left (let [candidate (+ (* row 2) (% (+ col 1) 2))]
              (when (< candidate count) (set next candidate)))
      :right (let [candidate (+ (* row 2) (% (+ col 1) 2))]
               (when (< candidate count) (set next candidate)))
      :up (let [rows (math/ceil (/ count 2.0))
                candidate (+ (* (% (+ row rows -1) rows) 2) col)]
            (when (< candidate count) (set next candidate)))
      :down (let [rows (math/ceil (/ count 2.0))
                  candidate (+ (* (% (inc row) rows) 2) col)]
              (when (< candidate count) (set next candidate))))
    (when (not= next index)
      (put menu :cursor next)
      (set-player-position! (get battle :player)
                            (encounter-position battle :submenu-player-positions
                                                submenu-player-positions next))
      (event! battle [:sound (get (get battle :encounter)
                                  :menu-cursor-sound :squeak)]))))

(defn update-player-menu!
  [battle input]
  (def menu (get battle :menu))
  (if (= (get menu :screen) :commands)
    (cond
      (and (pressed? input :confirm)
           (not (get (get battle :arena) :resizing?)))
      (confirm-command! battle)
      (pressed? input :right) (change-command! battle 1)
      (pressed? input :left) (change-command! battle -1))
    (cond
      (and (pressed? input :confirm)
           (or (> (submenu-option-count battle (get menu :screen)) 0)
               (and (= (get menu :screen) :item)
                    (not (encounter-function battle :resolve-item!)))))
      (do
        (event! battle [:sound (get (get battle :encounter)
                                    :menu-select-sound :select)])
        (case (get menu :screen)
          :act (resolve-act-option! battle (get menu :cursor))
          :item (resolve-item-option! battle (get menu :cursor))
          :mercy (resolve-mercy! battle)))
      (pressed? input :cancel)
      (do
        (exit-submenu! battle)
        (event! battle [:sound (get (get battle :encounter)
                                    :menu-select-sound :select)]))
      (pressed? input :right) (move-submenu! battle :right)
      (pressed? input :down) (move-submenu! battle :down)
      (pressed? input :left) (move-submenu! battle :left)
      (pressed? input :up) (move-submenu! battle :up))))

(defn start-enemy-turn!
  [battle]
  (put battle :phase :enemy-attack)
  (put battle :enemy-turn-ticks 0)
  (put battle :turn (inc (get battle :turn)))
  (dialogue/clear! (get battle :dialogue))
  (put (get battle :player) :visible? true)
  (put (get battle :player) :sprite :normal)
  (center-player! battle)
  (set-arena-target! (get battle :arena) @[242 255 155 130])
  (when-let [start-attack (encounter-function battle :start-attack!)]
    (start-attack battle (get battle :player))))

(defn spawn-shards!
  [battle death]
  (for i 0 6
    (def angle (* (/ i 6.0) 2 math/pi))
    (def speed (+ 3 (* 3 (math/rng-uniform (get battle :fx-rng)))))
    (array/push (get death :shards)
                @{:x (get death :x) :y (get death :y)
                  :vx (* (math/cos angle) speed)
                  :vy (- (math/abs (* (math/sin angle) speed)))
                  :frame (% i 4) :anim-ticks 0})))

(defn step-death!
  [battle]
  (def death (get battle :death))
  (put death :ticks (inc (get death :ticks)))
  (case (get death :stage)
    :show-player
    (when (>= (get death :ticks) 30)
      (put death :stage :broken)
      (event! battle [:sound :break1]))

    :broken
    (when (>= (get death :ticks) 90)
      (put death :stage :shards)
      (spawn-shards! battle death)
      (event! battle [:sound :break2]))

    :shards
    (do
      (each shard (get death :shards)
        (put shard :x (+ (get shard :x) (get shard :vx)))
        (put shard :y (+ (get shard :y) (get shard :vy)))
        (put shard :vy (+ (get shard :vy) 0.2))
        (put shard :anim-ticks (inc (get shard :anim-ticks)))
        (when (> (get shard :anim-ticks) 2)
          (put shard :frame (% (inc (get shard :frame)) 4))
          (put shard :anim-ticks 0)))
      (when (>= (get death :ticks) 150)
        (put death :stage :fade-out)))

    :fade-out
    (do
      (put battle :complete? true)
      (put battle :outcome :game-over))))

(defn step-dialogue!
  [battle]
  (dialogue/step! (get battle :dialogue))
  (when-let [after-step (encounter-function battle :after-dialogue-step!)]
    (after-step battle)))

(defn step!
  [battle input]
  (unless (get battle :complete?)
    (put battle :tick (inc (get battle :tick)))
    (when-let [step-encounter (encounter-function battle :step!)]
      (step-encounter battle input))
    (case (get battle :phase)
      :player-menu (update-player-menu! battle input)
      :player-result (when (pressed? input :confirm) (start-enemy-turn! battle))
      :enemy-attack
      (if-let [step-attack (encounter-function battle :step-attack!)]
        (step-attack battle input)
        (do
          (move-player! battle input)
          (resolve-bullet-hits! battle)
          (when (= (get battle :phase) :enemy-attack)
            (put battle :enemy-turn-ticks (inc (get battle :enemy-turn-ticks)))
            (when (or (empty? (get battle :bullets))
                      (>= (get battle :enemy-turn-ticks) enemy-turn-ticks))
              (array/clear (get battle :bullets))
              (start-player-turn! battle)))))
      :victory
      (do
        (put battle :victory-ticks (inc (get battle :victory-ticks)))
        (when (> (get battle :victory-ticks) 120)
          (put battle :complete? true)
          (put battle :outcome :victory)))
      :death
      (if-let [step-death (encounter-function battle :step-death!)]
        (step-death battle)
        (step-death! battle)))

    (when (not= (get battle :phase) :death)
      (if (encounter-function battle :step!)
        # A custom encounter step owns arena, hazard, animation, and hurt
        # ordering. Dialogue remains a shared deterministic service.
        (step-dialogue! battle)
        (do
          (step-arena! (get battle :arena))
          (step-dialogue! battle)
          (when-let [step-enemy (encounter-function battle :step-enemy!)]
            (each enemy (get battle :enemies)
              (step-enemy enemy)))
          (step-bullets! battle)
          (step-player-hurt! (get battle :player))))))
  battle)

(defn command-selected?
  [battle index]
  (and (= (get battle :phase) :player-menu)
       (= (get (get battle :menu) :screen) :commands)
       (= (get (get battle :menu) :cursor) index)))

(defn submenu-options
  [battle]
  (def show?
    (or (= (get battle :phase) :player-menu)
        (and (= (get battle :phase) :player-result)
             (get (get battle :player) :visible?))))
  (if-not show?
    @[]
    (map option-text
         (command-options battle (get (get battle :menu) :screen)))))
