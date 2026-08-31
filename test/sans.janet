(import ../src/battle)
(import ../src/encounters/sans)
(import ../src/encounters/sans-timeline)
(import ../src/encounters/sans-mechanics)

(def no-input @{})

(defn step-n!
  [state n &opt input]
  (for _ 0 n
    (battle/step! state (default input no-input)))
  state)

(defn new-sans-battle
  [&opt seed]
  (battle/new-battle (default seed 1) sans/encounter))

# All source programs load as immutable encounter data; no attack is omitted.
(let [programs (sans/programs)]
  (assert (= (length programs) 24))
  (assert (= (sum (map |(length (get $ :rows)) (values programs))) 970))
  (each id sans-timeline/attack-ids
    (assert (get programs id))))

# Normal mode starts directly in the paused intro script with source stats/items.
(let [state (new-sans-battle 10)
      player (get state :player)
      attack (get state :attack)]
  (assert (= (get state :phase) :enemy-attack))
  (assert (= (get attack :id) :sans-intro))
  (assert (= (get attack :status) :paused))
  (assert (= (get player :hp) 92))
  (assert (= (get player :max-hp) 92))
  (assert (= (length (get state :inventory)) 8))
  (battle/step! state no-input)
  (assert (= (get state :phase) :sans-script-dialogue))
  (assert (= (get (get state :dialogue) :text) "ready?"))
  (assert (not (get player :visible?)))
  (battle/step! state @{:confirm true})
  (assert (sans/dialogue-complete? state))
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :enemy-attack))
  (assert (= (get attack :status) :running)))

# Timed Sans glyphs emit their source voice; explicit text skipping is silent.
(let [state (new-sans-battle 11)]
  (battle/step! state no-input)
  (battle/drain-events! state)
  (battle/step! state no-input)
  (def events (battle/drain-events! state))
  (assert (= (length events) 1))
  (assert (= (first events) [:sound :sans/sfx-sans-speak])))

# The standard prologue pauses only the scheduler while arena edges keep moving.
(let [state (new-sans-battle 20)]
  (battle/drain-events! state)
  (sans/install-attack! state :sans-bonegap1)
  (def attack (get state :attack))
  (def arena (get state :arena))
  (assert (= (get attack :status) :paused))
  (assert (get arena :resizing?))
  (def before (get arena :left))
  (battle/step! state no-input)
  (assert (not= before (get arena :left)))
  (step-n! state 30)
  (assert (= (get attack :status) :running)))

# Blue gravity, grounded jump, release cutoff, and cancel-held half speed.
(let [state (new-sans-battle 30)
      player (get state :player)
      arena (get state :arena)]
  (put state :phase :enemy-attack)
  (put state :attack nil)
  (sans-mechanics/set-arena-instant! state 200 200 440 392)
  (put player :visible? true)
  (put player :x 320)
  (put player :y (- (get arena :bottom) 5 8))
  (sans-mechanics/set-heart-mode! player 1)
  (sans-mechanics/move-heart! state @{:up true :up-down true})
  (assert (< (get player :vy) 0))
  (sans-mechanics/move-heart! state @{:up-released true})
  (assert (>= (get player :vy) -30))
  (sans-mechanics/set-heart-mode! player 0)
  (sans-mechanics/move-heart! state @{:right-down true :cancel-down true})
  (assert (= (get player :vx) 75)))

# Blue hazards hit only while moving; orange hazards hit only while still.
(let [state (new-sans-battle 40)
      player (get state :player)]
  (array/clear (get state :hazards))
  (put player :hp 92)
  (put player :x 320)
  (put player :y 320)
  (put player :visible? true)
  (array/push (get state :hazards)
              @{:kind :bone-v :shape :rect :family :nine-patch
                :x 312 :y 312 :w 16 :h 16 :damage 1 :karma 6
                :color :blue :visible? true})
  (put player :moving? false)
  (put state :tick 10)
  (sans-mechanics/resolve-hazard-hits! state)
  (assert (= (get player :hp) 92))
  (put player :moving? true)
  (sans-mechanics/resolve-hazard-hits! state)
  (assert (= (get player :hp) 91))
  (assert (= (get player :kr) 6))
  (put (get (get state :hazards) 0) :color :orange)
  (put state :tick 11)
  (sans-mechanics/resolve-hazard-hits! state)
  (assert (= (get player :hp) 91))
  (put player :moving? false)
  (sans-mechanics/resolve-hazard-hits! state)
  (assert (= (get player :hp) 90)))

# FIGHT is a deterministic MISS dodge; its completed return advances attempts.
(let [state (new-sans-battle 50)
      enemy (sans/sans-state state)]
  (sans/open-player-menu! state)
  (put (get state :menu) :screen :fight)
  (sans/resolve-fight! state)
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :fight-meter))
  (battle/step! state @{:confirm true})
  (assert (= (get state :phase) :fight-dodge))
  (step-n! state (+ sans/fight-out-ticks sans/fight-hold-ticks sans/fight-return-ticks))
  (assert (= (get enemy :hit-attempts) 1))
  (assert (= (get (get state :attack) :id) :sans-bonegap1)))

# Counter-driven selector preserves the source phase break and finale threshold.
(let [state (new-sans-battle 60)
      enemy (sans/sans-state state)]
  (put enemy :hit-attempts 13)
  (put enemy :next-attack 9)
  (assert (= (sans/select-attack! state) :sans-spare))
  (assert (= (get enemy :next-attack) 0))
  (put enemy :hit-attempts 14)
  (assert (= (sans/select-attack! state) :sans-multi1))
  (put enemy :hit-attempts 23)
  (assert (= (sans/select-attack! state) :sans-final)))

# Fatal damage enters the source 20/40/60-tick split, shard, game-over sequence.
(let [state (new-sans-battle 70)
      player (get state :player)]
  (put player :hp 0)
  (battle/step! state no-input)
  (assert (= (get state :phase) :death))
  (assert (= (get (get state :death) :stage) :pre-split))
  (step-n! state 19)
  (assert (= (get (get state :death) :stage) :split))
  (step-n! state 40)
  (assert (= (get (get state :death) :stage) :shards))
  (assert (= (length (get (get state :death) :shards)) 6))
  (step-n! state 60)
  (assert (get state :complete?))
  (assert (= (get state :outcome) :game-over)))

# A completed final script enters the two-line scripted victory, never HP damage.
(let [state (new-sans-battle 80)
      enemy (sans/sans-state state)
      attack (get state :attack)]
  (put enemy :hit-attempts 23)
  (put attack :ended? true)
  (sans/finish-attack! state)
  (assert (= (get state :phase) :sans-victory))
  (assert (= (get (get state :dialogue) :text) "huff... puff..."))
  (battle/step! state @{:cancel true})
  (battle/step! state @{:confirm true})
  (assert (= (get (get state :dialogue) :text) "alright, i guess\nyou win."))
  (battle/step! state @{:cancel true})
  (battle/step! state @{:confirm true})
  (assert (get state :complete?))
  (assert (= (get state :outcome) :victory)))

# Shared menu input uses each encounter's own cursor/select audio IDs.
(let [state (new-sans-battle 85)]
  (sans/open-player-menu! state)
  (put (get state :arena) :resizing? false)
  (battle/drain-events! state)
  (battle/step! state @{:right true})
  (assert (= (first (battle/drain-events! state))
             [:sound :sans/sfx-menu-cursor]))
  (battle/step! state @{:confirm true})
  (assert (= (first (battle/drain-events! state))
             [:sound :sans/sfx-menu-select])))

# Render output is data and contains the complete stable layer surface.
(let [state (new-sans-battle 90)]
  (def model (sans/render-model state))
  (def layers (get model :layers))
  (each id [:background :enemies :buttons :player :clipped-attacks :overlay :touch]
    (assert (get layers id)))
  (put state :black-screen? true)
  (def black-model (sans/render-model state))
  (assert (= (get (last (get (get black-model :layers) :overlay)) :role)
             :black-screen)))

# Every shipped program reaches its explicit EndAttack through the real
# scheduler and mechanics dispatcher. Script dialogue is completed exactly
# through its interactive input path.
(eachp [index id] sans-timeline/attack-ids
  (def state (new-sans-battle (+ 100 index)))
  (def player (get state :player))
  (put player :max-hp 1000000)
  (put player :hp 1000000)
  (battle/drain-events! state)
  (sans/install-attack! state id)
  (def attack (get state :attack))
  (var ticks 0)
  (while (and (< ticks 12000)
              (not (get attack :encounter-ended? false))
              (not= (get attack :status) :error))
    (def input
      (if (= (get state :phase) :sans-script-dialogue)
        (if (sans/dialogue-complete? state)
          @{:confirm true}
          @{:cancel true})
        no-input))
    (battle/step! state input)
    (++ ticks))
  (assert (not= (get attack :status) :error)
          (string id ": " (get attack :error "")))
  (assert (get attack :encounter-ended? false)
          (string id " did not reach EndAttack")))

(print "sans tests passed")
