(import ./sans-timeline)
(import ./sans-mechanics)
(import ./sans-assets)

(def ticks-per-second 30)
(def fight-out-ticks 12)
(def fight-hold-ticks 33)
(def fight-return-ticks 12)

(def first-phase-attacks
  [:sans-intro :sans-bonegap1 :sans-bluebone :sans-bonegap2
   :sans-platforms1 :sans-platforms2 :sans-platforms3 :sans-platforms4
   :sans-platformblaster :sans-platforms4hard :sans-bonegap1fast
   :sans-boneslideh :sans-bonegap2 :sans-platformblasterfast])
(def first-phase-random
  [:sans-bonegap1fast :sans-bonegap2 :sans-boneslideh
   :sans-platformblasterfast])
(def second-phase-attacks
  [:sans-multi1 :sans-randomblaster1 :sans-multi2 :sans-bonestab1
   :sans-bonestab2 :sans-randomblaster2 :sans-boneslidev :sans-multi3
   :sans-bonestab3])
(def second-phase-random
  [:sans-bonestab3 :sans-multi3 :sans-randomblaster2])

(def item-defs
  {:butterscotch-pie {:name "Butterscotch Pie" :short "Pie" :heal 99}
   :instant-noodles {:name "Instant Noodles" :short "I.Noodles" :heal 90}
   :face-steak {:name "Face Steak" :short "Steak" :heal 60}
   :legendary-hero {:name "Legendary Hero" :short "L. Hero" :heal 40}})
(def initial-inventory
  [:butterscotch-pie :instant-noodles :face-steak
   :legendary-hero :legendary-hero :legendary-hero :legendary-hero
   :legendary-hero])

(def sans-definition
  {:id :sans :name "Sans" :attack 1 :defense 1
   :acts [{:id :check :label "Check"}]})

(var cached-programs nil)
(defn programs
  []
  (or cached-programs
      (set cached-programs
           (sans-timeline/load-programs "assets/sans/attacks"))))

(defn event!
  [battle event]
  (array/push (get battle :events) event))

(defn sans-state
  [battle]
  (first (get battle :enemies)))

(defn new-player
  []
  @{:x 320 :y 320 :w 16 :h 16
    :name "Chara" :lv 19
    :vx 0 :vy 0
    :hp 92 :max-hp 92 :kr 0 :kr-t 0
    :mode :red :gravity-dir 1 :gravity-angle 90 :max-fall-speed 750
    :visible? false :moving? false :movement-enabled? false
    :hurt-ticks 0 :slammed? false :slam-damage? false
    :sprite :normal})

(defn new-arena
  []
  @{:left 32 :top 240 :right 608 :bottom 384
    :target-left 33 :target-top 251 :target-right 608 :target-bottom 391
    :speed 480 :resizing? false :resume-generation nil :visible? false})

(defn new-sans
  []
  @{:id 1 :def sans-definition :kind :sans
    :x 320 :y 224 :x-speed 0
    :hit-attempts 0 :next-attack 0
    :dodge-state 0 :dodge-ticks 0 :dodge-timer 0
    :just-dodged? false
    :animation :idle :legs :standing :torso :default
    :body nil :head :default :sweat 0
    :torso-offset-x 0 :torso-offset-y 0
    :head-offset-x 0 :head-offset-y 0})

(defn new-enemies
  []
  @[(new-sans)])

(defn choose
  [battle values]
  (get values (math/rng-int (get battle :combat-rng) (length values))))

(defn select-attack!
  [battle]
  (def sans (sans-state battle))
  (def attempts (get sans :hit-attempts))
  (def next (get sans :next-attack))
  (cond
    (< attempts 13)
    (if (< next (length first-phase-attacks))
      (do
        (put sans :next-attack (inc next))
        (get first-phase-attacks next))
      (choose battle first-phase-random))

    (= attempts 13)
    (do
      (put sans :next-attack 0)
      (put sans :sweat 2)
      :sans-spare)

    (<= attempts 22)
    (if (< next (length second-phase-attacks))
      (do
        (put sans :next-attack (inc next))
        (get second-phase-attacks next))
      (choose battle second-phase-random))

    :else :sans-final))

(defn set-dialogue!
  [battle text &opt style]
  (def dialogue (get battle :dialogue))
  (put dialogue :text text)
  (put dialogue :visible 0)
  (put dialogue :delay-ticks 1)
  (put dialogue :letter-ticks 1)
  (put dialogue :letter-timer 0)
  (put dialogue :started? false)
  (put dialogue :active? true)
  (put dialogue :style (default style :battle))
  (put battle :sans-spoken-visible 0)
  dialogue)

(defn dialogue-complete?
  [battle]
  (def dialogue (get battle :dialogue))
  (>= (get dialogue :visible 0) (length (get dialogue :text ""))))

(defn reveal-dialogue!
  [battle]
  (def dialogue (get battle :dialogue))
  (put dialogue :started? true)
  (put dialogue :visible (length (get dialogue :text "")))
  # Skipping reveals silently; source voice playback belongs to timed glyphs.
  (put battle :sans-spoken-visible (get dialogue :visible))
  (put dialogue :active? false))

(defn pressed?
  [input key]
  (or (get input key false)
      (case key
        :confirm (get input :confirm-pressed? false)
        :cancel (get input :cancel-pressed? false)
        false)))

(defn begin-flow!
  [battle phase lines on-done &opt style]
  (put battle :phase phase)
  (put battle :sans-flow @{:lines lines :index 0 :on-done on-done
                           :style (default style :battle)})
  (set-dialogue! battle (first lines) (default style :battle)))

(var start-selected-attack! nil)
(var consume-sans-text! nil)
(var begin-death! nil)

(defn finish-flow!
  [battle action]
  (def flow (get battle :sans-flow))
  (put battle :sans-flow nil)
  (case action
    :start-attack (start-selected-attack! battle)
    :resume-attack
    (do
      (put battle :phase :enemy-attack)
      (sans-timeline/resume! (get battle :attack)
                             (get flow :generation)))
    :victory (do
               (put battle :complete? true)
               (put battle :outcome :victory)
               (put battle :phase :victory))
    nil))

(defn step-flow!
  [battle input]
  (when-let [flow (get battle :sans-flow nil)]
    (when (pressed? input :cancel)
      (reveal-dialogue! battle))
    (when (pressed? input :confirm)
      (if-not (dialogue-complete? battle)
        (reveal-dialogue! battle)
        (let [next-index (inc (get flow :index))
              lines (get flow :lines)]
          (if (< next-index (length lines))
            (do
              (put flow :index next-index)
              (set-dialogue! battle (get lines next-index) (get flow :style)))
            (finish-flow! battle (get flow :on-done))))))))

(defn menu-flavor-for
  [sans]
  (def attempts (get sans :hit-attempts))
  (def next (get sans :next-attack))
  (cond
    (= attempts 13) "* Sans is taking a break."
    (= attempts 15) "* The REAL battle finally begins."
    (= attempts 19) "* Reading this doesn't seem\n  like the best use of time."
    (= attempts 20) "* Sans is starting to look\n  really tired."
    (= attempts 21) "* Sans is preparing something."
    (= attempts 22) "* Sans is getting ready to\n  use his special attack."
    (and (< attempts 13) (= next 1))
    "* You feel like you're going to\n  have a bad time."
    :else "* You felt your sins crawling\n  on your back."))

(defn menu-flavor
  [battle]
  (menu-flavor-for (sans-state battle)))

(defn flavor-text
  [enemy category rng]
  (menu-flavor-for enemy))

(def command-positions [[48 453] [200 453] [360 453] [512 453]])

(defn open-player-menu!
  [battle]
  (def player (get battle :player))
  (def arena (get battle :arena))
  (put battle :phase :player-menu)
  (put battle :menu @{:screen :commands :cursor 0 :saved-command 0
                       :target-id 1})
  (put player :visible? true)
  (put player :movement-enabled? false)
  (put player :x 48)
  (put player :y 453)
  (put arena :visible? true)
  (put arena :target-left 33)
  (put arena :target-top 251)
  (put arena :target-right 608)
  (put arena :target-bottom 391)
  (put arena :resizing? true)
  (set-dialogue! battle (menu-flavor battle) :battle)
  (event! battle [:pause-music :sans/music-megalovania])
  battle)

(defn install-attack!
  [battle id]
  (def generation (inc (get battle :attack-generation 0)))
  (put battle :attack-generation generation)
  (sans-mechanics/reset-attack! battle)
  (put battle :attack (sans-timeline/new-attack (programs) id generation))
  (put battle :phase :enemy-attack)
  (put (get battle :player) :movement-enabled? true)
  (unless (= id :sans-spare)
    (event! battle [:resume-music :sans/music-megalovania]))
  (when (and (> (get (sans-state battle) :hit-attempts) 13)
             (<= (get (sans-state battle) :hit-attempts) 22))
    (event! battle [:stop-music :music-2]))
  (sans-timeline/drain! (get battle :attack) battle sans-mechanics/dispatch!)
  id)

(defn start-selected-attack-impl!
  [battle]
  (def id (select-attack! battle))
  (when (= id :sans-spare)
    (event! battle [:pause-music :sans/music-megalovania]))
  (install-attack! battle id))
(set start-selected-attack! start-selected-attack-impl!)

(defn start-attack!
  [battle player]
  (start-selected-attack! battle))

(defn start!
  [battle]
  (put battle :inventory
       @[:butterscotch-pie :instant-noodles :face-steak
         :legendary-hero :legendary-hero :legendary-hero :legendary-hero
         :legendary-hero])
  (put battle :hazards @[])
  (put battle :platforms @[])
  (put battle :attack-generation 0)
  (event! battle [:music :sans/music-megalovania])
  (start-selected-attack! battle)
  battle)

(defn start-victory!
  [battle]
  (def sans (sans-state battle))
  (put sans :animation :tired)
  (put sans :head :tired-2)
  (put sans :body nil)
  (put (get battle :player) :visible? false)
  (event! battle [:stop-all-audio])
  (begin-flow! battle :sans-victory
               @["huff... puff..." "alright, i guess\nyou win."]
               :victory :sans))

(defn finish-attack!
  [battle]
  (def attack (get battle :attack))
  (unless (get attack :encounter-ended? false)
    (put attack :encounter-ended? true)
    (array/clear (get battle :hazards))
    (array/clear (get battle :platforms))
    (put (get battle :player) :movement-enabled? false)
    (if (> (get (sans-state battle) :hit-attempts) 22)
      (start-victory! battle)
      (do
        (open-player-menu! battle)
        (def attempts (get (sans-state battle) :hit-attempts))
        (when (and (> attempts 13) (<= attempts 22)
                   (not= attempts 16) (not= attempts 17))
          (sans-mechanics/spawn-menu-bone-left! battle))
        (when (and (> attempts 15) (<= attempts 22))
          (sans-mechanics/enable-bottom-menu-bones! battle))))))

(defn step-attack!
  [battle input]
  (when-let [attack (get battle :attack nil)]
    (when (and (= (get battle :phase) :enemy-attack)
               (not (get attack :encounter-ended? false)))
      (sans-timeline/step! attack battle sans-mechanics/dispatch!)
      (when (= (get battle :phase) :enemy-attack)
        (consume-sans-text! battle))
      (when (get attack :ended? false)
        (finish-attack! battle))))
  battle)

(defn start-fight-meter!
  [battle]
  (def from-left? (= 0 (math/rng-int (get battle :combat-rng) 2)))
  (def arena (get battle :arena))
  (put battle :fight
       @{:state :moving
         :target @{:x 320 :y 320 :w 548 :h 117 :opacity 255}
         :choice @{:x (if from-left? (get arena :left) (get arena :right))
                   :y 320 :direction (if from-left? 0 2)
                   :vx (if from-left? 12 -12)}
         :strike nil :miss nil})
  (put battle :phase :fight-meter)
  (put (get battle :player) :visible? false)
  battle)

(defn confirm-fight!
  [battle]
  (def fight (get battle :fight))
  (def sans (sans-state battle))
  (put (get fight :choice) :vx 0)
  (put fight :state :dodge)
  (put fight :strike @{:x (get sans :x) :y (- (get sans :y) 96)
                       :scale 1.5 :ticks 0})
  (put sans :dodge-state 1)
  (put sans :dodge-ticks 0)
  (put sans :dodge-timer 0)
  (put sans :just-dodged? false)
  (put battle :phase :fight-dodge)
  (event! battle [:sound :sans/sfx-player-fight]))

(defn finish-dodge!
  [battle]
  (def sans (sans-state battle))
  (put sans :x 320)
  (put sans :dodge-state 0)
  (put sans :dodge-ticks 0)
  (put sans :dodge-timer 0)
  (put sans :hit-attempts (inc (get sans :hit-attempts)))
  (put sans :just-dodged? true)
  (when-let [fight (get battle :fight nil)]
    (put fight :state :fade)
    (put fight :strike nil))
  (start-selected-attack! battle))

(defn step-fight-meter!
  [battle input]
  (def fight (get battle :fight))
  (def choice (get fight :choice))
  (if (pressed? input :confirm)
    (confirm-fight! battle)
    (do
      (put choice :x (+ (get choice :x) (get choice :vx)))
      (def arena (get battle :arena))
      (when (or (> (get choice :x) (get arena :right))
                (< (get choice :x) (get arena :left)))
        (put fight :state :miss)
        (put fight :miss @{:text "MISS" :x 272 :y 76 :ticks 30})
        (put battle :phase :fight-miss)))))

(defn step-fight-miss!
  [battle]
  (def miss (get (get battle :fight) :miss))
  (put miss :ticks (dec (get miss :ticks)))
  (when (<= (get miss :ticks) 0)
    (put battle :fight nil)
    (start-selected-attack! battle)))

(defn step-fight-dodge!
  [battle]
  (def sans (sans-state battle))
  (def state (get sans :dodge-state))
  (def ticks (inc (get sans :dodge-ticks)))
  (put sans :dodge-ticks ticks)
  (put sans :dodge-timer (/ ticks 30.0))
  (case state
    1
    (do
      (put sans :x
           (- 320 (* (math/sin (* (/ ticks 30.0) 225
                                  (/ math/pi 180.0)))
                     100)))
      (when (>= ticks fight-out-ticks)
        (put sans :x 220)
        (put sans :dodge-state 2)
        (put sans :dodge-ticks 0)
        (put sans :dodge-timer 0)))

    2
    (do
      (when (and (= ticks 6) (nil? (get (get battle :fight) :miss nil)))
        (put (get battle :fight) :miss
             @{:text "MISS" :x 272 :y 50 :ticks 45}))
      (when (>= ticks fight-hold-ticks)
        (put sans :dodge-state 3)
        (put sans :dodge-ticks 0)
        (put sans :dodge-timer 0)))

    3
    (do
      (put sans :x
           (- 320 (* (math/cos (* (/ ticks 30.0) 225
                                  (/ math/pi 180.0)))
                     100)))
      (when (>= ticks fight-return-ticks)
        (finish-dodge! battle)))))

(defn resolve-fight!
  [battle]
  (put battle :fight-target-pending? true)
  (put (get battle :player) :visible? true)
  (put (get battle :player) :x 72)
  (put (get battle :player) :y 280)
  battle)

(defn resolve-act!
  [battle act-id]
  (when (or (= act-id :check) (= act-id 0))
    (def lines
      (if (> (get (sans-state battle) :hit-attempts) 0)
        @["* SANS 1 ATK 1 DEF\n* The easiest enemy.\n* Can only deal 1 damage."
          "* Can't keep dodging forever.\n* Keep attacking."]
        @["* SANS 1 ATK 1 DEF\n* The easiest enemy.\n* Can only deal 1 damage."]))
    (put (get battle :player) :visible? false)
    (begin-flow! battle :sans-result lines :start-attack :battle)))

(defn inventory-index
  [inventory item-id]
  (if (number? item-id)
    item-id
    (do
      (var found -1)
      (eachp [index id] inventory
        (when (and (= found -1) (= id item-id))
          (set found index)))
      found)))

(defn resolve-item!
  [battle item-id]
  (def inventory (get battle :inventory))
  (when (not (empty? inventory))
    (def index (inventory-index inventory item-id))
    (when (and (>= index 0) (< index (length inventory)))
      (def id (get inventory index))
      (def item (get item-defs id))
      (def player (get battle :player))
      (put player :hp (min (get player :max-hp)
                           (+ (get player :hp) (get item :heal))))
      (array/remove inventory index)
      (put player :visible? false)
      (event! battle [:sound :sans/sfx-player-heal])
      (begin-flow! battle :sans-result
                   @[(string "* You eat the " (get item :name) ".\n"
                             "* You recovered " (get item :heal) " HP!")]
                   :start-attack :battle))))

(defn resolve-mercy!
  [battle]
  (put (get battle :player) :visible? false)
  (start-selected-attack! battle))

(defn command-options
  [battle screen]
  (case screen
    :fight @[{:id :sans :text "* Sans"}]
    :act @[{:id :check :text "* Check"}]
    :item (map |{:id $ :text (string "* " (get (get item-defs $) :short))}
               (get battle :inventory))
    :mercy @[{:id :spare :text "* Spare"}]
    @[]))

(defn consume-sans-text-impl!
  [battle]
  (def events (get battle :events))
  (var index 0)
  (var consumed? false)
  (while (and (not consumed?) (< index (length events)))
    (def event (get events index))
    (if (= (get event 0 nil) :sans/text)
      (do
        (array/remove events index)
        (begin-flow! battle :sans-script-dialogue
                     @[(get event 1)] :resume-attack :sans)
        (put (get battle :sans-flow) :generation (get event 2))
        (set consumed? true))
      (++ index)))
  consumed?)
(set consume-sans-text! consume-sans-text-impl!)

(defn step-fight-effects!
  [battle]
  (when-let [fight (get battle :fight nil)]
    (when-let [strike (get fight :strike nil)]
      (put strike :ticks (inc (get strike :ticks))))
    (when-let [miss (get fight :miss nil)]
      (unless (= (get battle :phase) :fight-miss)
        (put miss :ticks (dec (get miss :ticks)))
        (when (<= (get miss :ticks) 0)
          (put fight :miss nil))))
    (when (= (get fight :state) :fade)
      (def target (get fight :target))
      (put target :w (max 0 (- (get target :w) 32)))
      (put target :opacity (max 0 (- (get target :opacity) 8)))
      (when (<= (get target :opacity) 0)
        (put battle :fight nil)))))

(defn step-fight-target!
  [battle input]
  (var started? false)
  (when (get battle :fight-target-pending? false)
    (if (not= (get (get battle :menu) :screen nil) :fight)
      (put battle :fight-target-pending? false)
      (when (pressed? input :confirm)
        (put battle :fight-target-pending? false)
        (event! battle [:sound :sans/sfx-menu-select])
        (start-fight-meter! battle)
        (set started? true))))
  started?)

(defn step-dialogue-audio!
  [battle]
  (def dialogue (get battle :dialogue))
  (def visible (get dialogue :visible 0))
  (def spoken (get battle :sans-spoken-visible 0))
  (when (> visible spoken)
    (def sound (if (= (get dialogue :style :battle) :sans)
                 :sans/sfx-sans-speak
                 :sans/sfx-battle-text))
    (for _ spoken visible
      (event! battle [:sound sound]))
    (put battle :sans-spoken-visible visible)))

(defn step!
  [battle input]
  (unless (= (get battle :phase) :death)
    (sans-mechanics/step! battle input))
  (when (and (not= (get battle :phase) :death)
             (<= (get (get battle :player) :hp) 0))
    (begin-death! battle))
  (step-fight-effects! battle)
  (def target-confirmed?
    (and (= (get battle :phase) :player-menu)
         (step-fight-target! battle input)))
  (when (= (get battle :phase) :enemy-attack)
    (consume-sans-text! battle))
  (unless target-confirmed?
    (case (get battle :phase)
      :fight-meter (step-fight-meter! battle input)
      :fight-miss (step-fight-miss! battle)
      :fight-dodge (step-fight-dodge! battle)
      :sans-result (step-flow! battle input)
      :sans-script-dialogue (step-flow! battle input)
      :sans-victory (step-flow! battle input)))
  battle)

(defn spawn-death-shards!
  [battle death]
  (for i 0 6
    (def angle (* (math/rng-uniform (get battle :fx-rng)) 2 math/pi))
    (array/push (get death :shards)
                @{:x (get death :x) :y (get death :y)
                  :vx (* (math/cos angle) 6)
                  :vy (* (math/sin angle) 6)
                  :frame (% i 4) :anim-ticks 0})))

(defn begin-death-impl!
  [battle]
  (def player (get battle :player))
  (when-let [attack (get battle :attack nil)]
    (sans-timeline/stop! attack))
  (array/clear (get battle :hazards))
  (array/clear (get battle :platforms))
  (put player :mode :red)
  (put player :visible? true)
  (put player :movement-enabled? false)
  (put player :sprite :normal)
  (put battle :phase :death)
  (put battle :death @{:stage :pre-split :ticks 0
                       :x (get player :x) :y (get player :y)
                       :black? true :shards @[]})
  (event! battle [:stop-all-audio]))
(set begin-death! begin-death-impl!)

(defn step-death!
  [battle]
  (def existing (get battle :death nil))
  (unless (and existing
               (or (= (get existing :stage nil) :pre-split)
                   (= (get existing :stage nil) :split)
                   (= (get existing :stage nil) :shards)))
    (begin-death! battle))
  (def death (get battle :death))
  (put death :ticks (inc (get death :ticks)))
  (case (get death :stage)
    :pre-split
    (when (>= (get death :ticks) 20)
      (put death :stage :split)
      (put death :ticks 0)
      (put (get battle :player) :sprite :split)
      (event! battle [:sound :sans/sfx-heart-split]))

    :split
    (when (>= (get death :ticks) 40)
      (put death :stage :shards)
      (put death :ticks 0)
      (put (get battle :player) :visible? false)
      (spawn-death-shards! battle death)
      (event! battle [:sound :sans/sfx-heart-shatter]))

    :shards
    (do
      (each shard (get death :shards)
        (put shard :x (+ (get shard :x) (get shard :vx)))
        (put shard :y (+ (get shard :y) (get shard :vy)))
        (put shard :vy (+ (get shard :vy) (/ 300.0 900.0)))
        (put shard :anim-ticks (inc (get shard :anim-ticks)))
        (when (>= (get shard :anim-ticks) 2)
          (put shard :frame (% (inc (get shard :frame)) 4))
          (put shard :anim-ticks 0)))
      (when (>= (get death :ticks) 60)
        (put battle :complete? true)
        (put battle :outcome :game-over))))
  battle)

# Render model ---------------------------------------------------------------

(defn sprite
  [role animation x y &opt scale origin rotation tint visible?]
  {:kind :sprite :role role :animation animation :position [x y]
   :scale (default scale [1 1]) :origin (default origin [0.5 0.5])
   :rotation (default rotation 0) :tint (default tint [255 255 255 255])
   :visible? (default visible? true)})

(defn rect-item
  [role rect color]
  {:kind :rect :role role :rect rect :color color :visible? true})

(defn text-item
  [role font text rect scale tint]
  {:kind :text :role role :font font :text text :rect rect
   :scale scale :tint tint :visible? true})

(defn append-all!
  [target source]
  (each item source (array/push target item))
  target)

(defn sans-items
  [battle]
  (def sans (sans-state battle))
  (def x (get sans :x))
  (def torso-x (+ x (get sans :torso-offset-x 0)))
  (def torso-y (+ 176 (get sans :torso-offset-y 0)))
  (def head-x (+ x (get sans :head-offset-x 0)))
  (def head-y (+ 128 (get sans :head-offset-y 0)))
  (def items @[])
  (array/push items (sprite :sans-legs
                            (keyword (string "sans/legs/" (string (get sans :legs))))
                            x 224 [2 2]))
  (if-let [body (get sans :body nil)]
    (array/push items (sprite :sans-body
                              (keyword (string "sans/body/" (string body)))
                              torso-x 176 [2 2]))
    (array/push items (sprite :sans-torso
                              (keyword (string "sans/torso/" (string (get sans :torso))))
                              torso-x torso-y [2 2])))
  (array/push items (sprite :sans-head
                            (keyword (string "sans/head/" (string (get sans :head))))
                            head-x head-y [2 2]))
  (when (> (get sans :sweat) 0)
    (array/push items (sprite :sans-sweat
                              (keyword (string "sans/sweat/" (get sans :sweat)))
                              head-x (- head-y 60) [2 2])))
  items)

(defn hazard-tint
  [hazard]
  (or (get hazard :tint nil)
      (case (get hazard :color :white)
        :blue [20 169 255 255]
        1 [20 169 255 255]
        :orange [255 160 64 255]
        2 [255 160 64 255]
        [255 255 255 255])))

(defn hazard-item
  [hazard clip]
  (def kind (get hazard :kind))
  (def menu? (or (= kind :menu-bone-left)
                 (= kind :menu-bone-bottom)))
  (def entity-clip (if menu? nil clip))
  (def texture
    (or (get hazard :texture nil)
        (case kind
          :bone-h :sans/bone-h
          :bone-v :sans/bone-v
          :bone-stab-h :sans/bone-stab-h
          :bone-stab-v :sans/bone-stab-v
          :bone-stab-warn :sans/bone-stab-warn
          :gaster-blaster :sans/gaster-blaster/default
          :gaster-blast :sans/gaster-blast-1
          :menu-bone-left :sans/menu-bone-left/default
          :menu-bone-bottom :sans/menu-bone-bottom/default
          :sans/bone-v)))
  (cond
    (or (= kind :gaster-blaster) menu?)
    {:kind :sprite :role kind
     :animation (if (and (= kind :gaster-blaster)
                         (get hazard :beam-visible? false))
                  :sans/gaster-blaster/fire
                  texture)
     :position [(get hazard :x) (get hazard :y)]
     :scale (if menu?
              [1 1]
              [(get hazard :scale 1) (get hazard :scale 1)])
     :origin (if menu? [0 0] [0.5 0.5])
     :rotation (get hazard :angle 0)
     :tint (hazard-tint hazard)
     :ticks (get hazard :age 0)
     :visible? (get hazard :visible? true) :clip entity-clip}

    (= kind :gaster-blast)
    {:kind :tile :role kind :texture texture
     :rect [(get hazard :x) (get hazard :y)
            (get hazard :w (get hazard :width 112))
            (get hazard :h (get hazard :height 32))]
     :rotation (get hazard :angle 0)
     :tint (hazard-tint hazard)
     :visible? (get hazard :visible? true) :clip entity-clip}

    :else
    {:kind :nine-patch :role kind :texture texture
     :rect [(get hazard :x) (get hazard :y)
            (get hazard :w (get hazard :width 10))
            (get hazard :h (get hazard :height 10))]
     :tint (hazard-tint hazard)
     :visible? (get hazard :visible? true) :clip entity-clip}))

(defn gaster-beam-item
  [hazard clip]
  (when (and (= (get hazard :kind) :gaster-blaster)
             (get hazard :beam-visible? false))
    (def angle (get hazard :angle 0))
    (def radians (* angle (/ math/pi 180.0)))
    (def scale (get hazard :scale 1))
    (def opacity (get hazard :beam-opacity 255))
    {:kind :tile :role :gaster-blast :texture :sans/gaster-blast-1
     :rect [(+ (get hazard :x) (* (math/cos radians) 70 scale))
            (+ (get hazard :y) (* (math/sin radians) 70 scale))
            1000
            (get hazard :beam-size (get hazard :base-size 32))]
     :origin [0 0.5] :rotation angle
     :tint [255 255 255 (if (<= opacity 1) (* opacity 255) opacity)]
     :visible? true :clip clip}))

(defn platform-items
  [battle clip]
  (def items @[])
  (each platform (get battle :platforms)
    (array/push items
                {:kind :nine-patch :role :platform-body
                 :texture :sans/platform-1
                 :rect [(get platform :x) (get platform :y)
                        (get platform :width) 7]
                 :tint [255 255 255 255] :visible? true :clip clip})
    (array/push items
                {:kind :nine-patch :role :platform-top
                 :texture :sans/platform-2
                 :rect [(get platform :x) (- (get platform :y) 4)
                        (get platform :width) 7]
                 :tint [255 255 255 255] :visible? true :clip clip}))
  items)

(defn hud-items
  [battle]
  (def player (get battle :player))
  (def hp (get player :hp))
  (def max-hp (get player :max-hp))
  (def kr (get player :kr))
  (def bar-width (math/floor (* max-hp 1.2)))
  (def hp-width (* bar-width (/ hp max-hp)))
  (def kr-width (math/ceil (* bar-width (/ kr max-hp))))
  @[(text-item :player-label :sans/font-battle "CHARA  LV 19"
               [32 402 192 20] 3 [255 255 255 255])
    (sprite :hp-label :sans/hp-label/default 224 416 [1 1] [0 1])
    (rect-item :hp-background [256 400 bar-width 21] [128 0 0 255])
    (rect-item :hp-bar [256 400 hp-width 21] [255 255 0 255])
    (rect-item :kr-bar [(+ 256 (* bar-width (/ (- hp kr) max-hp)))
                        400 kr-width 21]
               [255 0 255 255])
    (text-item :hp-value :sans/font-battle
               (string (if (< hp 10) "0" "") hp " / " max-hp)
               [416 400 128 20] 3
               [255 (if (> kr 0) 0 255) 255 255])])

(defn button-items
  [battle]
  (def selected
    (if (and (= (get battle :phase) :player-menu)
             (= (get (get battle :menu) :screen nil) :commands))
      (get (get battle :menu) :cursor 0)
      -1))
  (def specs [[:fight 32] [:act 184] [:item 344] [:mercy 496]])
  (def items @[])
  (eachp [index spec] specs
    (def name (get spec 0))
    (def state (if (= index selected) "highlight" "default"))
    (array/push items
                (sprite name
                        (keyword (string "sans/ui-" (string name) "/" state))
                        (get spec 1) 432 [1 1] [0 0])))
  items)

(defn dialogue-items
  [battle]
  (def dialogue (get battle :dialogue))
  (def visible (min (get dialogue :visible 0)
                    (length (get dialogue :text ""))))
  (def text (string/slice (get dialogue :text "") 0 visible))
  (if (= (get dialogue :style :battle) :sans)
    @[(sprite :speech-bubble :sans/speech-bubble/default
              (+ (get (sans-state battle) :x) 64) 96 [1 1] [0 0])
      (text-item :sans-dialogue :sans/font-sans text
                 [(+ (get (sans-state battle) :x) 96) 112 205 64]
                 1 [0 0 0 255])]
    (if (empty? text)
      @[]
      @[(text-item :battle-dialogue :sans/font-default text
                   [48 270 544 104] 1 [255 255 255 255])])))

(defn submenu-items
  [battle]
  (def menu (get battle :menu))
  (def screen (get menu :screen :commands))
  (if (= screen :commands)
    @[]
    (let [options (command-options battle screen)
          cursor (get menu :cursor 0)
          page (if (= screen :item) (math/floor (/ cursor 4)) 0)
          start (* page 4)
          finish (min (length options) (+ start 4))
          items @[]]
      (for index start finish
        (def slot (- index start))
        (def x (if (= (% slot 2) 0) 96 352))
        (def y (if (< slot 2) 272 304))
        (array/push items
                    (text-item :submenu-option :sans/font-default
                               (get (get options index) :text)
                               [x y 240 16] 1 [255 255 255 255])))
      items)))

(defn fight-items
  [battle]
  (if-let [fight (get battle :fight nil)]
    (let [items @[]
          target (get fight :target)]
      (array/push items
                  (sprite :fight-target :sans/target/default
                          (get target :x) (get target :y)
                          [(/ (get target :w) 548.0) 1] [0.5 0.5]
                          0 [255 255 255 (get target :opacity 255)]))
      (when-let [choice (get fight :choice nil)]
        (array/push items
                    (sprite :fight-choice :sans/target-choice/default
                            (get choice :x) (get choice :y))))
      (when-let [strike (get fight :strike nil)]
        (array/push items
                    {:kind :sprite :role :fight-strike
                     :animation :sans/strike/default
                     :position [(get strike :x) (get strike :y)]
                     :scale [(get strike :scale) (get strike :scale)]
                     :origin [0.5 0.5] :rotation 0
                     :tint [255 255 255 255] :visible? true
                     :ticks (get strike :ticks)}))
      (when-let [miss (get fight :miss nil)]
        (array/push items
                    (text-item :fight-miss :sans/font-damage "MISS"
                               [(get miss :x) (get miss :y) 176 32]
                               1 [128 128 128 255])))
      items)
    @[]))

(defn death-items
  [battle]
  (if-let [death (get battle :death nil)]
    (let [items @[]]
      (when (get death :black? false)
        (array/push items (rect-item :death-overlay [0 0 640 480]
                                    [0 0 0 255])))
      (def player (get battle :player))
      (when (get player :visible? false)
        (array/push items
                    (sprite :death-heart
                            (if (= (get player :sprite :normal) :split)
                              :sans/player-heart/split
                              :sans/player-heart/default)
                            (get death :x) (get death :y)
                            [1 1] [0.5 0.5] 90 [255 0 0 255])))
      (each shard (get death :shards)
        (array/push items
                    {:kind :sprite :role :heart-shard
                     :animation :sans/heart-shard/default
                     :position [(get shard :x) (get shard :y)]
                     :scale [1 1] :origin [0.5 0.5] :rotation 0
                     :tint [255 255 255 255] :visible? true
                     :frame (get shard :frame)}))
      items)
    @[]))

(defn heart-items
  [battle]
  (def player (get battle :player))
  (if (or (= (get battle :phase) :death)
          (not (get player :visible? false)))
    @[]
    @[(sprite :heart
              (if (= (get player :sprite :normal) :split)
                :sans/player-heart/split
                :sans/player-heart/default)
              (get player :x) (get player :y) [1 1] [0.5 0.5]
              (* (get player :gravity-dir 1) 90)
              (if (= (get player :mode) :blue)
                [0 60 255 255]
                [255 0 0 255]))]))

(defn render-model
  [battle]
  (def arena (get battle :arena))
  (def clip [(get arena :left) (get arena :top)
             (- (get arena :right) (get arena :left))
             (- (get arena :bottom) (get arena :top))])
  (def clipped @[])
  (each hazard (get battle :hazards)
    (array/push clipped (hazard-item hazard clip))
    (when-let [beam (gaster-beam-item hazard clip)]
      (array/push clipped beam)))
  (append-all! clipped (platform-items battle clip))
  (def overlay
    @[{:kind :nine-patch :role :arena
       :texture :sans/combat-zone
       :rect clip :tint [255 255 255 255]
       :visible? (get arena :visible? true)}])
  (append-all! overlay (fight-items battle))
  (append-all! overlay (submenu-items battle))
  (append-all! overlay (dialogue-items battle))
  (append-all! overlay (death-items battle))
  (when (get battle :black-screen? false)
    (array/push overlay (rect-item :black-screen [0 0 640 480]
                                   [0 0 0 255])))
  {:logical-size [640 480]
   :layers {:background (hud-items battle)
            :enemies (sans-items battle)
            :buttons (button-items battle)
            :player (heart-items battle)
            :clipped-attacks clipped
            :overlay overlay
            :touch @[]}})

(def encounter
  {:id :sans
   :assets sans-assets/manifest
   :enemy-def sans-definition
   :new-player new-player
   :new-arena new-arena
   :new-enemies new-enemies
   :flavor-text flavor-text
   :initial-inventory initial-inventory
   :command-player-positions command-positions
   :submenu-player-positions [[72 280] [328 280] [72 312] [328 312]
                              [72 280] [328 280] [72 312] [328 312]]
   :menu-cursor-sound :sans/sfx-menu-cursor
   :menu-select-sound :sans/sfx-menu-select
   :start! start!
   :step! step!
   :after-dialogue-step! step-dialogue-audio!
   :start-attack! start-attack!
   :step-attack! step-attack!
   :resolve-fight! resolve-fight!
   :resolve-act! resolve-act!
   :resolve-item! resolve-item!
   :resolve-mercy! resolve-mercy!
   :step-death! step-death!
   :command-options command-options
   :render-model render-model})
