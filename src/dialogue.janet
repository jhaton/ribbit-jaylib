(def ticks-per-second 30)
(def default-letter-ticks 2)

(defn new
  []
  @{:text ""
    :visible 0
    :delay-ticks 0
    :letter-ticks default-letter-ticks
    :letter-timer 0
    :started? false
    :active? false})

(defn set-text!
  [dialogue text &opt delay-seconds]
  (def delay (default delay-seconds 0.5))
  (put dialogue :text text)
  (put dialogue :visible 0)
  # BattleText performs one update that starts the clock even for zero delay.
  (put dialogue :delay-ticks (max 1 (math/ceil (* delay ticks-per-second))))
  (put dialogue :letter-timer 0)
  (put dialogue :started? false)
  (put dialogue :active? true)
  dialogue)

(defn clear!
  [dialogue]
  (set-text! dialogue "" 0))

(defn step!
  [dialogue]
  (when (get dialogue :active?)
    (if-not (get dialogue :started?)
      (do
        (put dialogue :delay-ticks (dec (get dialogue :delay-ticks)))
        (when (<= (get dialogue :delay-ticks) 0)
          (put dialogue :started? true)
          (put dialogue :letter-timer 0)))
      (if (< (get dialogue :visible) (length (get dialogue :text)))
        (do
          (put dialogue :letter-timer (inc (get dialogue :letter-timer)))
          (when (>= (get dialogue :letter-timer) (get dialogue :letter-ticks))
            (put dialogue :visible (inc (get dialogue :visible)))
            (put dialogue :letter-timer 0)))
        (put dialogue :active? false))))
  dialogue)

(defn visible-text
  [dialogue]
  (if (get dialogue :started?)
    (string/slice (get dialogue :text) 0 (get dialogue :visible))
    ""))

(defn complete?
  [dialogue]
  (>= (get dialogue :visible) (length (get dialogue :text))))
