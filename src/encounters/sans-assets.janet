# Battle-local assets and renderer metadata for the canonical Sans encounter.
# Frame timing is expressed both as Construct duration multipliers and 30 Hz ticks.

(defn frame
  [texture-id path width height duration ticks origin image-points]
  {:texture-id texture-id
   :path path
   :size [width height]
   :duration duration
   :ticks ticks
   :origin origin
   :image-points image-points})

(defn static-animation
  [texture-id path width height origin image-points]
  {:speed 5
   :static? true
   :loop? false
   :loop-back nil
   :frames [(frame texture-id path width height 1 nil origin image-points)]})

(def animations
  {:sans/ui-act/default
   (static-animation :sans/ui-act/default/000
                     "assets/sans/animations/UIAct/Default/000.png"
                     110 42 [0 0] {:heart [0.145455 0.5]})
   :sans/ui-act/highlight
   (static-animation :sans/ui-act/highlight/000
                     "assets/sans/animations/UIAct/Highlight/000.png"
                     110 42 [0 0] {:heart [0.145455 0.5]})
   :sans/ui-fight/default
   (static-animation :sans/ui-fight/default/000
                     "assets/sans/animations/UIFight/Default/000.png"
                     110 42 [0 0] {:heart [0.145455 0.5]})
   :sans/ui-fight/highlight
   (static-animation :sans/ui-fight/highlight/000
                     "assets/sans/animations/UIFight/Highlight/000.png"
                     110 42 [0 0] {:heart [0.145455 0.5]})
   :sans/ui-item/default
   (static-animation :sans/ui-item/default/000
                     "assets/sans/animations/UIItem/Default/000.png"
                     110 42 [0 0] {:heart [0.145455 0.5]})
   :sans/ui-item/highlight
   (static-animation :sans/ui-item/highlight/000
                     "assets/sans/animations/UIItem/Highlight/000.png"
                     110 42 [0 0] {:heart [0.145455 0.5]})
   :sans/ui-mercy/default
   (static-animation :sans/ui-mercy/default/000
                     "assets/sans/animations/UIMercy/Default/000.png"
                     110 42 [0 0] {:heart [0.145455 0.5]})
   :sans/ui-mercy/highlight
   (static-animation :sans/ui-mercy/highlight/000
                     "assets/sans/animations/UIMercy/Highlight/000.png"
                     110 42 [0 0] {:heart [0.145455 0.5]})

   :sans/target/default
   (static-animation :sans/target/default/000
                     "assets/sans/animations/Target/Default/000.png"
                     548 117 [0.5 0.504274] {})
   :sans/target-choice/default
   {:speed 30
    :static? false
    :loop? true
    :loop-back 0
    :frames [(frame :sans/target-choice/default/000
                    "assets/sans/animations/TargetChoice/Default/000.png"
                    14 128 3 3 [0.5 0.5] {})
             (frame :sans/target-choice/default/001
                    "assets/sans/animations/TargetChoice/Default/001.png"
                    14 128 2 2 [0.5 0.5] {})]}
   :sans/strike/default
   {:speed 10
    :static? false
    :loop? false
    :loop-back nil
    :frames [(frame :sans/strike/default/000
                    "assets/sans/animations/Strike/Default/000.png"
                    4 6 1 3 [-1 5.66667] {})
             (frame :sans/strike/default/001
                    "assets/sans/animations/Strike/Default/001.png"
                    4 22 1 3 [-0.5 1.36364] {})
             (frame :sans/strike/default/002
                    "assets/sans/animations/Strike/Default/002.png"
                    6 42 1 3 [0 0.428571] {})
             (frame :sans/strike/default/003
                    "assets/sans/animations/Strike/Default/003.png"
                    8 64 1 3 [0 0.15625] {})
             (frame :sans/strike/default/004
                    "assets/sans/animations/Strike/Default/004.png"
                    14 32 1 3 [0 -0.75] {})
             (frame :sans/strike/default/005
                    "assets/sans/animations/Strike/Default/005.png"
                    14 12 1 3 [-0.142857 -4] {})]}

   :sans/hp-label/default
   (static-animation :sans/hp-label/default/000
                     "assets/sans/animations/HP/Default/000.png"
                     23 10 [0 1] {})
   :sans/kr-label/default
   (static-animation :sans/kr-label/default/000
                     "assets/sans/animations/KR/Default/000.png"
                     23 10 [1 1] {})

   :sans/head/default
   (static-animation :sans/head/default/000
                     "assets/sans/animations/SansHead/Default/000.png"
                     32 30 [0.5 1] {:sweat [0.5 0]})
   :sans/head/look-left
   (static-animation :sans/head/look-left/000
                     "assets/sans/animations/SansHead/LookLeft/000.png"
                     32 30 [0.5 1] {:sweat [0.5 0]})
   :sans/head/wink
   (static-animation :sans/head/wink/000
                     "assets/sans/animations/SansHead/Wink/000.png"
                     32 30 [0.5 1] {:sweat [0.5 0]})
   :sans/head/closed-eyes
   (static-animation :sans/head/closed-eyes/000
                     "assets/sans/animations/SansHead/ClosedEyes/000.png"
                     32 30 [0.5 1] {:sweat [0.5 0]})
   :sans/head/no-eyes
   (static-animation :sans/head/no-eyes/000
                     "assets/sans/animations/SansHead/NoEyes/000.png"
                     32 30 [0.5 1] {:sweat [0.5 0]})
   :sans/head/tired-1
   (static-animation :sans/head/tired-1/000
                     "assets/sans/animations/SansHead/Tired1/000.png"
                     32 30 [0.5 1] {:sweat [0.5 0]})
   :sans/head/tired-2
   (static-animation :sans/head/tired-2/000
                     "assets/sans/animations/SansHead/Tired2/000.png"
                     32 30 [0.5 1] {:sweat [0.5 0]})
   :sans/head/blue-eye
   {:speed 5
    :static? false
    :loop? false
    :loop-back nil
    :frames [(frame :sans/head/blue-eye/000
                    "assets/sans/animations/SansHead/BlueEye/000.png"
                    32 30 1 6 [0.5 1] {:sweat [0.5 0]})
             (frame :sans/head/blue-eye/001
                    "assets/sans/animations/SansHead/BlueEye/001.png"
                    32 30 1 6 [0.5 1] {:sweat [0.5 0]})]}

   :sans/body/hand-down
   {:speed 15
    :static? false
    :loop? false
    :loop-back nil
    :frames [(frame :sans/body/hand-down/000
                    "assets/sans/animations/SansBody/HandDown/000.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.4]})
             (frame :sans/body/hand-down/001
                    "assets/sans/animations/SansBody/HandDown/001.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.385714]})
             (frame :sans/body/hand-down/002
                    "assets/sans/animations/SansBody/HandDown/002.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.428571]})
             (frame :sans/body/hand-down/003
                    "assets/sans/animations/SansBody/HandDown/003.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.442857]})]}
   :sans/body/hand-up
   {:speed 15
    :static? false
    :loop? false
    :loop-back nil
    :frames [(frame :sans/body/hand-up/000
                    "assets/sans/animations/SansBody/HandUp/000.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.428571]})
             (frame :sans/body/hand-up/001
                    "assets/sans/animations/SansBody/HandUp/001.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.442857]})
             (frame :sans/body/hand-up/002
                    "assets/sans/animations/SansBody/HandUp/002.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.4]})
             (frame :sans/body/hand-up/003
                    "assets/sans/animations/SansBody/HandUp/003.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.385714]})
             (frame :sans/body/hand-up/004
                    "assets/sans/animations/SansBody/HandUp/004.png"
                    64 70 1 2 [0.46875 1] {:head [0.46875 0.4]})]}
   :sans/body/hand-right
   {:speed 15
    :static? false
    :loop? false
    :loop-back nil
    :frames [(frame :sans/body/hand-right/000
                    "assets/sans/animations/SansBody/HandRight/000.png"
                    96 48 1 2 [0.34375 1] {:head [0.34375 0.125]})
             (frame :sans/body/hand-right/001
                    "assets/sans/animations/SansBody/HandRight/001.png"
                    96 48 1 2 [0.34375 1] {:head [0.322917 0.125]})
             (frame :sans/body/hand-right/002
                    "assets/sans/animations/SansBody/HandRight/002.png"
                    96 48 1 2 [0.34375 1] {:head [0.3125 0.125]})
             (frame :sans/body/hand-right/003
                    "assets/sans/animations/SansBody/HandRight/003.png"
                    96 48 1 2 [0.34375 1] {:head [0.375 0.125]})
             (frame :sans/body/hand-right/004
                    "assets/sans/animations/SansBody/HandRight/004.png"
                    96 48 1 2 [0.34375 1] {:head [0.354167 0.125]})]}
   :sans/body/hand-left
   {:speed 15
    :static? false
    :loop? false
    :loop-back nil
    :frames [(frame :sans/body/hand-left/000
                    "assets/sans/animations/SansBody/HandLeft/000.png"
                    96 48 1 2 [0.34375 1] {:head [0.354167 0.125]})
             (frame :sans/body/hand-left/001
                    "assets/sans/animations/SansBody/HandLeft/001.png"
                    96 48 1 2 [0.34375 1] {:head [0.375 0.125]})
             (frame :sans/body/hand-left/002
                    "assets/sans/animations/SansBody/HandLeft/002.png"
                    96 48 1 2 [0.34375 1] {:head [0.3125 0.125]})
             (frame :sans/body/hand-left/003
                    "assets/sans/animations/SansBody/HandLeft/003.png"
                    96 48 1 2 [0.34375 1] {:head [0.322917 0.125]})
             (frame :sans/body/hand-left/004
                    "assets/sans/animations/SansBody/HandLeft/004.png"
                    96 48 1 2 [0.34375 1] {:head [0.34375 0.125]})]}

   :sans/legs/standing
   (static-animation :sans/legs/standing/000
                     "assets/sans/animations/SansLegs/Standing/000.png"
                     44 23 [0.477273 1] {:torso [0.477273 0]})
   :sans/legs/sitting
   (static-animation :sans/legs/sitting/000
                     "assets/sans/animations/SansLegs/Sitting/000.png"
                     52 17 [0.480769 0.882353] {:torso [0.480769 0.0588235]})
   :sans/sweat/1
   (static-animation :sans/sweat/1/000
                     "assets/sans/animations/SansSweat/Sweat1/000.png"
                     32 9 [0.5 0] {})
   :sans/sweat/2
   (static-animation :sans/sweat/2/000
                     "assets/sans/animations/SansSweat/Sweat2/000.png"
                     32 9 [0.5 0] {})
   :sans/sweat/3
   (static-animation :sans/sweat/3/000
                     "assets/sans/animations/SansSweat/Sweat3/000.png"
                     32 9 [0.5 0] {})
   :sans/torso/default
   (static-animation :sans/torso/default/000
                     "assets/sans/animations/SansTorso/Default/000.png"
                     54 25 [0.5 1] {:head [0.5 0.24]})
   :sans/torso/shrug
   (static-animation :sans/torso/shrug/000
                     "assets/sans/animations/SansTorso/Shrug/000.png"
                     72 24 [0.5 1] {:head [0.5 0.208333]})

   :sans/speech-bubble/default
   (static-animation :sans/speech-bubble/default/000
                     "assets/sans/animations/SpeechBubble/Default/000.png"
                     237 104 [0 0] {})
   :sans/speech-bubble/no-effects
   (static-animation :sans/speech-bubble/no-effects/000
                     "assets/sans/animations/SpeechBubble/NoEffects/000.png"
                     237 104 [0 0] {})
   :sans/gaster-blaster/default
   (static-animation :sans/gaster-blaster/default/000
                     "assets/sans/animations/GasterBlaster/Default/000.png"
                     57 44 [0.491228 0.5] {})
   :sans/gaster-blaster/fire
   {:speed 30
    :static? false
    :loop? true
    :loop-back 3
    :frames [(frame :sans/gaster-blaster/fire/000
                    "assets/sans/animations/GasterBlaster/Fire/000.png"
                    57 44 1 1 [0.508772 0.5] {})
             (frame :sans/gaster-blaster/fire/001
                    "assets/sans/animations/GasterBlaster/Fire/001.png"
                    57 44 1 1 [0.508772 0.5] {})
             (frame :sans/gaster-blaster/fire/002
                    "assets/sans/animations/GasterBlaster/Fire/002.png"
                    57 44 1 1 [0.508772 0.5] {})
             (frame :sans/gaster-blaster/fire/003
                    "assets/sans/animations/GasterBlaster/Fire/003.png"
                    57 44 1 1 [0.508772 0.5] {})
             (frame :sans/gaster-blaster/fire/004
                    "assets/sans/animations/GasterBlaster/Fire/004.png"
                    57 44 1 1 [0.508772 0.5] {})]}

   :sans/menu-bone-left/default
   (static-animation :sans/menu-bone-left/default/000
                     "assets/sans/animations/MenuBoneLeft/Default/000.png"
                     14 44 [0 0] {})
   :sans/menu-bone-bottom/default
   (static-animation :sans/menu-bone-bottom/default/000
                     "assets/sans/animations/MenuBoneBottom/Default/000.png"
                     14 44 [0 0] {})
   :sans/player-heart/default
   {:speed 5
    :static? true
    :loop? false
    :loop-back nil
    :tintable? true
    :default-tint [1 0 0 1]
    :frames [(frame :sans/player-heart/default/000
                    "assets/sans/animations/PlayerHeart/Default/000.png"
                    16 16 1 nil [0.5 0.5] {})]}
   :sans/player-heart/split
   (static-animation :sans/player-heart/split/000
                     "assets/sans/animations/PlayerHeart/Split/000.png"
                     16 16 [0.5 0.5] {})
   :sans/player-hitbox/default
   {:speed 5
    :static? true
    :loop? false
    :loop-back nil
    :initially-visible? false
    :frames [(frame :sans/player-hitbox/default/000
                    "assets/sans/animations/PlayerHitbox/Default/000.png"
                    4 4 1 nil [0.5 0.5] {})]}
   :sans/heart-shard/default
   {:speed 15
    :static? false
    :loop? true
    :loop-back 0
    :frames [(frame :sans/heart-shard/default/000
                    "assets/sans/animations/HeartShard/Default/000.png"
                    16 16 1 2 [0.5 0.5] {})
             (frame :sans/heart-shard/default/001
                    "assets/sans/animations/HeartShard/Default/001.png"
                    16 16 1 2 [0.5 0.5] {})
             (frame :sans/heart-shard/default/002
                    "assets/sans/animations/HeartShard/Default/002.png"
                    16 16 1 2 [0.5 0.5] {})
             (frame :sans/heart-shard/default/003
                    "assets/sans/animations/HeartShard/Default/003.png"
                    16 16 1 2 [0.5 0.5] {})]}
   :sans/menu-item/default
   {:speed 5
    :static? true
    :loop? false
    :loop-back nil
    :initially-visible? false
    :frames [(frame :sans/menu-item/default/000
                    "assets/sans/animations/MenuItem/Default/000.png"
                    16 16 1 nil [0 0] {})]}})

(def textures
  @{:sans/bone-h "assets/sans/textures/BoneH.png"
    :sans/bone-v "assets/sans/textures/BoneV.png"
    :sans/bone-stab-h "assets/sans/textures/BoneStabH.png"
    :sans/bone-stab-v "assets/sans/textures/BoneStabV.png"
    :sans/bone-stab-warn "assets/sans/textures/BoneStabWarn.png"
    :sans/platform-1 "assets/sans/textures/Platform1.png"
    :sans/platform-2 "assets/sans/textures/Platform2.png"
    :sans/combat-zone "assets/sans/textures/CombatZone.png"
    :sans/combat-border "assets/sans/textures/CombatZoneBorder.png"
    :sans/combat-clipper "assets/sans/textures/CombatZoneClipper.png"
    :sans/combat-unclipper "assets/sans/textures/CombatZoneUnclipper.png"
    :sans/gaster-blast-1 "assets/sans/textures/GasterBlast1.png"
    :sans/gaster-blast-2 "assets/sans/textures/GasterBlast2.png"
    :sans/gaster-blast-3 "assets/sans/textures/GasterBlast3.png"
    :sans/gaster-blast-hit "assets/sans/textures/GasterBlastHit.png"
    :sans/hp-background "assets/sans/textures/HPBackground.png"
    :sans/hp-bar "assets/sans/textures/HPBar.png"
    :sans/kr-bar "assets/sans/textures/KRBar.png"
    :sans/font-battle "assets/sans/textures/BattleFont.png"
    :sans/font-sans "assets/sans/textures/SansFont.png"
    :sans/font-default "assets/sans/textures/DefaultFont.png"
    :sans/font-damage "assets/sans/textures/DamageFont.png"})

# Animation frames are ordinary namespaced textures to the generic loader.
(each animation-id (keys animations)
  (each animation-frame (get (get animations animation-id) :frames)
    (put textures
         (get animation-frame :texture-id)
         (get animation-frame :path))))

(def sounds
  {:sans/sfx-ding "assets/sans/sounds/Ding.ogg"
   :sans/sfx-player-fight "assets/sans/sounds/PlayerFight.ogg"
   :sans/sfx-player-damaged "assets/sans/sounds/PlayerDamaged.ogg"
   :sans/sfx-sans-speak "assets/sans/sounds/SansSpeak.ogg"
   :sans/sfx-gaster-blaster "assets/sans/sounds/GasterBlaster.ogg"
   :sans/sfx-bone-stab "assets/sans/sounds/BoneStab.ogg"
   :sans/sfx-warning "assets/sans/sounds/Warning.ogg"
   :sans/sfx-heart-shatter "assets/sans/sounds/HeartShatter.ogg"
   :sans/sfx-gaster-blast "assets/sans/sounds/GasterBlast.ogg"
   :sans/sfx-flash "assets/sans/sounds/Flash.ogg"
   :sans/sfx-slam "assets/sans/sounds/Slam.ogg"
   :sans/sfx-menu-select "assets/sans/sounds/MenuSelect.ogg"
   :sans/sfx-heart-split "assets/sans/sounds/HeartSplit.ogg"
   :sans/sfx-menu-cursor "assets/sans/sounds/MenuCursor.ogg"
   :sans/sfx-battle-text "assets/sans/sounds/BattleText.ogg"
   :sans/sfx-player-heal "assets/sans/sounds/PlayerHeal.ogg"
   :sans/sfx-gaster-blast-2 "assets/sans/sounds/GasterBlast2.ogg"})

(def music
  {:sans/music-megalovania "assets/sans/music/Megalovania.ogg"})

(def fixed-cell-fonts
  {:sans/font-battle
   {:texture-id :sans/font-battle
    :atlas-size [96 24]
    :cell-width 6
    :cell-height 6
    :charset " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
    :scale 3
    :character-spacing 0
    :line-height 0
    :origin :top-left
    :word-wrap? true
    :tintable? true
    :sampling :point}
   :sans/font-sans
   {:texture-id :sans/font-sans
    :atlas-size [256 96]
    :cell-width 16
    :cell-height 16
    :charset " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    :scale 1
    :character-spacing 0
    :line-height 0
    :origin :top-left
    :word-wrap? true
    :tintable? true
    :sampling :point
    :default-voice :sans/sfx-sans-speak}
   :sans/font-default
   {:texture-id :sans/font-default
    :atlas-size [160 96]
    :cell-width 10
    :cell-height 16
    :charset " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    :scale 1
    :character-spacing 0
    :line-height 0
    :origin :top-left
    :word-wrap? true
    :tintable? true
    :sampling :point
    :default-voice :sans/sfx-battle-text}
   :sans/font-damage
   {:texture-id :sans/font-damage
    :atlas-size [528 192]
    :cell-width 33
    :cell-height 32
    :charset " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    :scale 1
    :character-spacing 0
    :line-height 0
    :origin :top-left
    :word-wrap? true
    :tintable? true
    :sampling :point}})

(def nine-patches
  {:sans/bone-h
   {:texture-id :sans/bone-h
    :native-size [24 10]
    :nominal-size [48 10]
    :margins {:left 6 :top 0 :right 6 :bottom 0}
    :edge-mode :tile
    :fill-mode :tile
    :origin :top-left
    :tintable? true}
   :sans/bone-v
   {:texture-id :sans/bone-v
    :native-size [10 24]
    :nominal-size [10 48]
    :margins {:left 0 :top 6 :right 0 :bottom 6}
    :edge-mode :tile
    :fill-mode :tile
    :origin :top-left
    :tintable? true}
   :sans/bone-stab-h
   {:texture-id :sans/bone-stab-h
    :native-size [24 12]
    :nominal-size [48 12]
    :margins {:left 6 :top 0 :right 6 :bottom 0}
    :edge-mode :tile
    :fill-mode :tile
    :origin :top-left
    :tintable? true}
   :sans/bone-stab-v
   {:texture-id :sans/bone-stab-v
    :native-size [12 24]
    :nominal-size [12 48]
    :margins {:left 0 :top 6 :right 0 :bottom 6}
    :edge-mode :tile
    :fill-mode :tile
    :origin :top-left
    :tintable? true}
   :sans/bone-stab-warn
   {:texture-id :sans/bone-stab-warn
    :native-size [16 16]
    :nominal-size [16 16]
    :margins {:left 4 :top 4 :right 4 :bottom 4}
    :edge-mode :stretch
    :fill-mode :stretch
    :origin :top-left
    :tintable? true}
   :sans/platform-1
   {:texture-id :sans/platform-1
    :native-size [16 7]
    :nominal-size [61 7]
    :margins {:left 4 :top 2 :right 4 :bottom 2}
    :edge-mode :stretch
    :fill-mode :stretch
    :origin :top-left
    :tintable? true}
   :sans/platform-2
   {:texture-id :sans/platform-2
    :native-size [16 7]
    :nominal-size [61 7]
    :margins {:left 4 :top 2 :right 4 :bottom 2}
    :edge-mode :stretch
    :fill-mode :stretch
    :origin :top-left
    :tintable? true}
   :sans/combat-zone
   {:texture-id :sans/combat-zone
    :native-size [16 16]
    :margins {:left 5 :top 5 :right 5 :bottom 5}
    :edge-mode :stretch
    :fill-mode :transparent
    :origin :top-left
    :overlap-seams? true
    :tintable? false}})

(def tiles
  {:sans/combat-border
   {:texture-id :sans/combat-border
    :native-size [4 4]
    :nominal-size [16 16]
    :mode :tile
    :origin :top-left
    :role :collision-wall}
   :sans/combat-clipper
   {:texture-id :sans/combat-clipper
    :native-size [16 16]
    :mode :mask-begin
    :origin :top-left
    :opaque? true
    :source-color :black
    :construct-blend-mode 6
    :renderer-replacement :scissor}
   :sans/combat-unclipper
   {:texture-id :sans/combat-unclipper
    :native-size [16 16]
    :mode :mask-end
    :origin :top-left
    :opaque? true
    :source-color :white
    :construct-blend-mode 6
    :renderer-replacement :scissor-restore}
   :sans/gaster-blast-1
   {:texture-id :sans/gaster-blast-1
    :native-size [16 16]
    :nominal-size [112 32]
    :mode :tile
    :source-color :white
    :origin [0 0.5]}
   :sans/gaster-blast-2
   {:texture-id :sans/gaster-blast-2
    :native-size [16 16]
    :nominal-size [16 24]
    :mode :tile
    :source-color :white
    :origin [0 0.5]}
   :sans/gaster-blast-3
   {:texture-id :sans/gaster-blast-3
    :native-size [16 16]
    :nominal-size [16 16]
    :mode :tile
    :source-color :white
    :origin [0 0.5]}
   :sans/gaster-blast-hit
   {:texture-id :sans/gaster-blast-hit
    :native-size [16 16]
    :nominal-size [112 16]
    :mode :tile
    :source-color :red
    :origin [0 0.5]
    :role :hitbox}
   :sans/hp-background
   {:texture-id :sans/hp-background
    :native-size [16 16]
    :nominal-size [110 21]
    :mode :tile
    :source-color :dark-red
    :origin :top-left}
   :sans/hp-bar
   {:texture-id :sans/hp-bar
    :native-size [16 16]
    :mode :tile
    :source-color :yellow
    :origin :top-left
    :dynamic-size? true}
   :sans/kr-bar
   {:texture-id :sans/kr-bar
    :native-size [16 16]
    :mode :tile
    :source-color :magenta
    :origin :top-left
    :dynamic-size? true}})

(def manifest
  {:textures textures
   :sounds sounds
   :music music
   :animations animations
   :fixed-cell-fonts fixed-cell-fonts
   :nine-patches nine-patches
   :tiles tiles})
