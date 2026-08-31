(use jaylib)
(import ./assets)
(import ./battle)
(import ./dialogue)
(import ./render)
(import ./encounters/init :as encounters)

(def logical-width 640)
(def logical-height 480)
(def fixed-dt (/ 1.0 30.0))
(def edge-actions
  [:left :right :up :down :confirm :cancel
   :left-released :right-released :up-released :down-released])

(def instructions-text
  " --- Instructions --- \n\n[Z or ENTER] - Confirm\n[X or SHIFT] - Cancel\n[F4] - Fullscreen\n[ESC] - Quit\nWhen HP is 0, you lose.\n\n[Press Z or ENTER] to begin game")

(defn parse-options
  [args]
  (var smoke? false)
  (var encounter-id encounters/default-id)
  (var i 0)
  (while (< i (length args))
    (case (get args i)
      "--smoke" (set smoke? true)
      "--encounter"
      (do
        (when (>= (inc i) (length args))
          (error "--encounter requires one of: froggit, sans"))
        (set encounter-id (keyword (get args (inc i))))
        (++ i)))
    (++ i))
  (def encounter (encounters/encounter encounter-id))
  (unless encounter
    (error (string "unknown encounter '" encounter-id
                   "'; expected froggit or sans")))
  {:smoke? smoke?
   :encounter encounter
   :encounter-id encounter-id})

(defn poll-input
  []
  @{:left (or (key-pressed? :left) (key-pressed? :a))
    :right (or (key-pressed? :right) (key-pressed? :d))
    :up (or (key-pressed? :up) (key-pressed? :w))
    :down (or (key-pressed? :down) (key-pressed? :s))
    :left-released (or (key-released? :left) (key-released? :a))
    :right-released (or (key-released? :right) (key-released? :d))
    :up-released (or (key-released? :up) (key-released? :w))
    :down-released (or (key-released? :down) (key-released? :s))
    :confirm (or (key-pressed? :z) (key-pressed? :enter))
    :cancel (or (key-pressed? :x)
                (key-pressed? :left-shift)
                (key-pressed? :right-shift))
    :left-down (or (key-down? :left) (key-down? :a))
    :right-down (or (key-down? :right) (key-down? :d))
    :up-down (or (key-down? :up) (key-down? :w))
    :down-down (or (key-down? :down) (key-down? :s))
    :cancel-down (or (key-down? :x)
                     (key-down? :left-shift)
                     (key-down? :right-shift))})

(defn latch-input!
  [pending sampled]
  (each action edge-actions
    (when (get sampled action)
      (put pending action true)))
  (each action [:left-down :right-down :up-down :down-down :cancel-down]
    (put pending action (get sampled action false))))

(defn consume-edges!
  [pending]
  (each action edge-actions
    (put pending action false)))

(defn begin-fade-in!
  [game]
  (put game :fade-ticks 30))

(defn step-fade!
  [game]
  (when (> (get game :fade-ticks) 0)
    (put game :fade-ticks (dec (get game :fade-ticks)))))

(defn new-game
  [seed encounter]
  @{:screen :splash
    :battle nil
    :encounter encounter
    :seed seed
    :running? true
    :fade-ticks 0
    :pending-input @{}
    :game-over-dialogue (dialogue/new)})

(defn enter-battle!
  [game]
  (put game :battle
       (battle/new-battle (get game :seed) (get game :encounter)))
  (put game :seed (inc (get game :seed)))
  (put game :screen :battle)
  (begin-fade-in! game))

(defn enter-game-over!
  [game asset-store]
  (put game :screen :game-over)
  (dialogue/set-text! (get game :game-over-dialogue)
                      "You cannot give up just yet... \nStay determined."
                      0.5)
  (assets/play-music! asset-store :game-over)
  (begin-fade-in! game))

(defn step-screen!
  [game asset-store input]
  # Shake is gameplay-timed; retire the prior tick before new hits can start it.
  (when-let [battle-state (get game :battle)]
    (when (> (get battle-state :shake-ticks) 0)
      (put battle-state :shake-ticks (dec (get battle-state :shake-ticks)))))
  (case (get game :screen)
    :splash
    (when (get input :confirm false)
      (put game :screen :instructions))

    :instructions
    (when (get input :confirm false)
      (enter-battle! game))

    :battle
    (let [battle-state (get game :battle)]
      (battle/step! battle-state input)
      (each event (battle/drain-events! battle-state)
        (assets/handle-event! asset-store event))
      (when (get battle-state :complete?)
        (case (get battle-state :outcome)
          :victory (put game :running? false)
          :game-over (enter-game-over! game asset-store))))

    :game-over
    (do
      (dialogue/step! (get game :game-over-dialogue))
      (when (get input :confirm false)
        (enter-battle! game))))
  (step-fade! game))

(defn draw-screen
  [game asset-store fonts splash-font]
  (case (get game :screen)
    :splash
    (do
      (clear-background :black)
      (draw-texture (assets/texture asset-store :splash) 0 0 :white)
      (render/draw-bitmap-text asset-store splash-font "[PRESS Z OR ENTER]" [50 400]))

    :instructions
    (do
      (clear-background :black)
      (render/draw-bitmap-text asset-store (get fonts :main) instructions-text [170 100]))

    :battle
    (render/draw-battle asset-store fonts (get game :battle))

    :game-over
    (do
      (clear-background :black)
      (draw-texture (assets/texture asset-store :game-over) 0 0 :white)
      (render/draw-bitmap-text asset-store (get fonts :main)
                               (dialogue/visible-text (get game :game-over-dialogue))
                               [140 300])))

  (when (> (get game :fade-ticks) 0)
    (def alpha (/ (get game :fade-ticks) 30.0))
    (draw-rectangle 0 0 logical-width logical-height [0 0 0 alpha])))

(defn display-target
  [target-texture shake?]
  (def screen-width (get-screen-width))
  (def screen-height (get-screen-height))
  (def scale (min (/ screen-width logical-width)
                  (/ screen-height logical-height)))
  (def width (* logical-width scale))
  (def height (* logical-height scale))
  (def x (/ (- screen-width width) 2.0))
  (def y (/ (- screen-height height) 2.0))
  # The source moves the camera view by [-2 -2], shifting world content down-right.
  (def shake-offset (if shake? (* 2 scale) 0))
  (draw-texture-pro target-texture
                    [0 0 logical-width (- logical-height)]
                    [(+ x shake-offset) (+ y shake-offset) width height]
                    [0 0] 0 :white))

(defn run-loop!
  [asset-store fonts splash-font target target-texture smoke? encounter]
  (def seed (% (math/floor (* (get-time) 1000)) 4294967295))
  (def game (new-game seed encounter))
  (assets/play-music! asset-store :menu)
  (when smoke?
    (enter-battle! game))

  (var accumulator 0.0)
  (var rendered-frames 0)
  (while (and (get game :running?) (not (window-should-close)))
    (when (key-pressed? :f4)
      (toggle-fullscreen))

    (def sampled (poll-input))
    (latch-input! (get game :pending-input) sampled)
    (set accumulator (+ accumulator (min (get-frame-time) 0.25)))

    (while (>= accumulator fixed-dt)
      (step-screen! game asset-store (get game :pending-input))
      (consume-edges! (get game :pending-input))
      (set accumulator (- accumulator fixed-dt)))

    (assets/update! asset-store)

    (begin-texture-mode target)
    (draw-screen game asset-store fonts splash-font)
    (end-texture-mode)

    (begin-drawing)
    (clear-background :black)
    (def battle-state (get game :battle))
    (def shake? (and (= (get game :screen) :battle)
                     battle-state
                     (> (get battle-state :shake-ticks) 0)))
    (display-target target-texture shake?)
    (end-drawing)
    (when smoke?
      (++ rendered-frames)
      (when (= rendered-frames 90)
        (def capture (load-image-from-texture target-texture))
        (image-flip-vertical capture)
        (export-image capture "smoke.png")
        (unload-image capture))
      (when (>= rendered-frames 120)
        (put game :running? false)))))

(defn main
  [& args]
  (def options (parse-options args))
  (def smoke? (get options :smoke?))
  (def encounter (get options :encounter))
  (set-config-flags :window-resizable)
  (init-window logical-width logical-height "Undertale: Ribbit Edition — Janet/raylib")
  (defer (close-window)
    (set-window-min-size logical-width logical-height)
    (set-target-fps 60)

    (init-audio-device)
    (defer (close-audio-device)
      (def asset-store
        (assets/load-all (get encounter :assets)))
      (defer (assets/unload-all! asset-store)
        (def fonts (render/load-fonts asset-store))
        (def splash-font
          (render/load-bitmap-font :font-main "assets/fonts/glyphs_fnt_main.csv" 0.8))

        (def target (load-render-texture logical-width logical-height))
        (defer (unload-render-texture target)
          (def target-texture (get-render-texture-texture2d target))
          (set-texture-filter target-texture :point)
          (run-loop! asset-store fonts splash-font target target-texture
                     smoke? encounter))))))
