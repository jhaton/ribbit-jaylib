(declare-project
  :name "ribbit-jaylib"
  :description "Undertale: Ribbit Edition battle engine ported to Janet and raylib"
  :dependencies ["https://github.com/janet-lang/jaylib.git"])

(declare-executable
  :name "ribbit-jaylib"
  :entry "src/main.janet"
  :deps ["src/assets.janet"
         "src/battle.janet"
         "src/dialogue.janet"
         "src/render.janet"
         "src/encounters/froggit.janet"
         "src/encounters/sans-assets.janet"
         "src/encounters/sans-timeline.janet"
         "src/encounters/sans-mechanics.janet"
         "src/encounters/sans.janet"
         "src/encounters/init.janet"])
