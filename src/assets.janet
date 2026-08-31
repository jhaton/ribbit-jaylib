(use jaylib)

(def texture-paths
  {:battle-bg "assets/img/spr_battlebg_0.png"
   :fight "assets/img/spr_fightbt_0.png"
   :fight-selected "assets/img/spr_fightbt_1.png"
   :act "assets/img/spr_talkbt_0.png"
   :act-selected "assets/img/spr_talkbt_1.png"
   :item "assets/img/spr_itembt_0.png"
   :item-selected "assets/img/spr_itembt_1.png"
   :mercy "assets/img/spr_sparebt_0.png"
   :mercy-selected "assets/img/spr_sparebt_1.png"
   :heart "assets/img/spr_heart_0.png"
   :heart-hurt "assets/img/spr_heart_1.png"
   :transparent "assets/img/transparent.png"
   :font-main "assets/fonts/fnt_main.png"
   :font-small "assets/fonts/fnt_small.png"
   :splash "assets/img/splash.png"
   :game-over "assets/img/spr_gameoverbg.png"
   :heart-break "assets/img/spr_heartbreak.png"
   :heart-shard-0 "assets/img/spr_heartshards_0.png"
   :heart-shard-1 "assets/img/spr_heartshards_1.png"
   :heart-shard-2 "assets/img/spr_heartshards_2.png"
   :heart-shard-3 "assets/img/spr_heartshards_3.png"})

(def sound-paths
  {:squeak "assets/sounds/snd_squeak.wav"
   :select "assets/sounds/snd_select.wav"
   :laz "assets/sounds/snd_laz_c.wav"
   :heal "assets/sounds/snd_heal_c.wav"
   :hurt "assets/sounds/snd_hurt1.wav"
   :vaporized "assets/sounds/snd_vaporized.wav"
   :break1 "assets/sounds/snd_break1.wav"
   :break2 "assets/sounds/snd_break2.wav"})

(def music-paths
  {:menu "assets/mus/mus_menu0.ogg"
   :battle "assets/mus/mus_battle1.ogg"
   :game-over "assets/mus/mus_gameover.ogg"})

(defn combined-manifest
  [base extra kind]
  (def result @{})
  (each id (keys base)
    (put result id (get base id)))
  (each id (keys (get extra kind {}))
    (put result id (get (get extra kind) id)))
  result)

(defn load-all
  [&opt encounter-assets]
  (def supplied (default encounter-assets {}))
  (def extra (get supplied :manifest supplied))
  (def texture-manifest (combined-manifest texture-paths extra :textures))
  (def sound-manifest (combined-manifest sound-paths extra :sounds))
  (def music-manifest (combined-manifest music-paths extra :music))
  (def textures @{})
  (def sounds @{})
  (def music @{})
  (each id (keys texture-manifest)
    (def texture (load-texture (get texture-manifest id)))
    (set-texture-filter texture :point)
    (put textures id texture))
  (each id (keys (get extra :tiles {}))
    (def texture-id (get (get (get extra :tiles) id) :texture-id))
    (when-let [texture (get textures texture-id)]
      (set-texture-wrap texture :repeat)))
  (each id (keys sound-manifest)
    (put sounds id (load-sound (get sound-manifest id))))
  (each id (keys music-manifest)
    (put music id (load-music-stream (get music-manifest id))))
  @{:textures textures
    :sounds sounds
    :music music
    :animations (get extra :animations {})
    :fixed-cell-fonts (get extra :fixed-cell-fonts {})
    :nine-patches (get extra :nine-patches {})
    :tiles (get extra :tiles {})
    :current-music nil})

(defn texture
  [assets id]
  (get (get assets :textures) id))

(defn animation
  [asset-store id]
  (get (get asset-store :animations) id))

(defn fixed-cell-font
  [asset-store id]
  (get (get asset-store :fixed-cell-fonts) id))

(defn nine-patch
  [asset-store id]
  (get (get asset-store :nine-patches) id))

(defn tile
  [asset-store id]
  (get (get asset-store :tiles) id))

(defn play-sound!
  [assets id &opt rate]
  (when-let [sound (get (get assets :sounds) id)]
    (set-sound-pitch sound (default rate 1.0))
    (play-sound sound)))

(defn stop-music!
  [assets]
  (when-let [id (get assets :current-music)]
    (stop-music-stream (get (get assets :music) id))
    (put assets :current-music nil)))

(defn play-music!
  [assets id]
  (when (not= id (get assets :current-music))
    (stop-music! assets)
    (when-let [stream (get (get assets :music) id)]
      (play-music-stream stream)
      (put assets :current-music id))))

(defn pause-music!
  [asset-store id]
  (when-let [stream (get (get asset-store :music) id)]
    (pause-music-stream stream)))

(defn resume-music!
  [asset-store id]
  (when-let [stream (get (get asset-store :music) id)]
    (resume-music-stream stream)
    (put asset-store :current-music id)))

(defn pause-current-music!
  [asset-store]
  (when-let [id (get asset-store :current-music)]
    (pause-music! asset-store id)))

(defn resume-current-music!
  [asset-store]
  (when-let [id (get asset-store :current-music)]
    (resume-music! asset-store id)))

(defn update!
  [assets]
  (when-let [id (get assets :current-music)]
    (update-music-stream (get (get assets :music) id))))

(defn stop-all-audio!
  [asset-store]
  (stop-music! asset-store)
  (each id (keys (get asset-store :sounds))
    (stop-sound (get (get asset-store :sounds) id))))

(defn handle-stop-music!
  [asset-store event]
  (when (or (= (length event) 1)
            (= (get event 1) (get asset-store :current-music)))
    (stop-music! asset-store)))

(defn handle-event!
  [asset-store event]
  (case (get event 0)
    :sound (play-sound! asset-store (get event 1) (get event 2 1.0))
    :music (play-music! asset-store (get event 1))
    :pause-music (pause-music! asset-store (get event 1))
    :resume-music (resume-music! asset-store (get event 1))
    :audio-pause-tag (pause-current-music! asset-store)
    :audio-resume-tag (resume-current-music! asset-store)
    :stop-music (handle-stop-music! asset-store event)
    :stop-all-audio (stop-all-audio! asset-store)))

(defn unload-all!
  [assets]
  (stop-music! assets)
  (each id (keys (get assets :music))
    (unload-music-stream (get (get assets :music) id)))
  (each id (keys (get assets :sounds))
    (unload-sound (get (get assets :sounds) id)))
  (each id (keys (get assets :textures))
    (unload-texture (get (get assets :textures) id))))
