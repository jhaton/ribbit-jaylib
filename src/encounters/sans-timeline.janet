(def ticks-per-second 30)
(def instruction-budget 1000)

(def attack-files
  {:sans-bluebone "sans_bluebone.csv"
   :sans-bonegap1 "sans_bonegap1.csv"
   :sans-bonegap1fast "sans_bonegap1fast.csv"
   :sans-bonegap2 "sans_bonegap2.csv"
   :sans-boneslideh "sans_boneslideh.csv"
   :sans-boneslidev "sans_boneslidev.csv"
   :sans-bonestab1 "sans_bonestab1.csv"
   :sans-bonestab2 "sans_bonestab2.csv"
   :sans-bonestab3 "sans_bonestab3.csv"
   :sans-final "sans_final.csv"
   :sans-intro "sans_intro.csv"
   :sans-multi1 "sans_multi1.csv"
   :sans-multi2 "sans_multi2.csv"
   :sans-multi3 "sans_multi3.csv"
   :sans-platformblaster "sans_platformblaster.csv"
   :sans-platformblasterfast "sans_platformblasterfast.csv"
   :sans-platforms1 "sans_platforms1.csv"
   :sans-platforms2 "sans_platforms2.csv"
   :sans-platforms3 "sans_platforms3.csv"
   :sans-platforms4 "sans_platforms4.csv"
   :sans-platforms4hard "sans_platforms4hard.csv"
   :sans-randomblaster1 "sans_randomblaster1.csv"
   :sans-randomblaster2 "sans_randomblaster2.csv"
   :sans-spare "sans_spare.csv"})

(def attack-ids
  [:sans-bluebone
   :sans-bonegap1
   :sans-bonegap1fast
   :sans-bonegap2
   :sans-boneslideh
   :sans-boneslidev
   :sans-bonestab1
   :sans-bonestab2
   :sans-bonestab3
   :sans-final
   :sans-intro
   :sans-multi1
   :sans-multi2
   :sans-multi3
   :sans-platformblaster
   :sans-platformblasterfast
   :sans-platforms1
   :sans-platforms2
   :sans-platforms3
   :sans-platforms4
   :sans-platforms4hard
   :sans-randomblaster1
   :sans-randomblaster2
   :sans-spare])

(def cpu-commands
  {"SET" true
   "ADD" true
   "SUB" true
   "MUL" true
   "DIV" true
   "MOD" true
   "FLOOR" true
   "DEG" true
   "RAD" true
   "SIN" true
   "COS" true
   "ANGLE" true
   "RND" true
   "JMPABS" true
   "JMPREL" true
   "JMPZ" true
   "JMPNZ" true
   "JMPE" true
   "JMPNE" true
   "JMPL" true
   "JMPNL" true
   "JMPG" true
   "JMPNG" true
   "GetHeartPos" true
   "TLPause" true
   "TLResume" true
   "TLStop" true
   "Debug" true})

(def program-cache @{})

(defn- label-command?
  [command]
  (and (string? command) (string/has-prefix? ":" command)))

(defn- parse-program
  [path]
  (def text (slurp path))
  (def lines (string/split "\n" text))
  (def rows @[])
  (def labels @{})
  (for source-index 0 (length lines)
    (def raw-line (get lines source-index))
    # Construct treats CRLF as one newline delimiter. Preserve every other
    # byte; stripping the terminal CR keeps final arguments such as TLResume
    # exact without turning this into a permissive CSV parser.
    (def line (if (string/has-suffix? "\r" raw-line)
                (string/slice raw-line 0 (dec (length raw-line)))
                raw-line))
    # A terminal newline is a delimiter, not a 971st empty instruction.
    (unless (and (= source-index (dec (length lines))) (empty? line))
      (def fields (string/split "," line))
      (when (< (length fields) 2)
        (errorf "Malformed Sans timeline row %d in %s" (inc source-index) path))
      (def row (tuple/slice fields))
      (array/push rows row)
      (def command (get row 1))
      (when (label-command? command)
        (put labels (string/slice command 1) (dec (length rows))))))
  (freeze {:rows rows :labels labels}))

(defn load-programs
  [root]
  (if-let [cached (get program-cache root)]
    cached
    (let [programs @{}]
      (each id attack-ids
        (def filename (get attack-files id))
        (put programs id (parse-program (string root "/" filename))))
      (def immutable-programs (freeze programs))
      (put program-cache root immutable-programs)
      immutable-programs)))

(defn- numeric
  [value]
  (cond
    (number? value) value
    (nil? value) 0
    :else (or (scan-number (string value)) 0)))

(defn- integer
  [value]
  (def number (numeric value))
  (if (< number 0) (math/ceil number) (math/floor number)))

(defn seconds->ticks
  [value]
  (def seconds (numeric value))
  (cond
    (= seconds 0) 0
    (> seconds 0) (max 1 (math/floor (+ (* seconds ticks-per-second) 0.5)))
    :else (- (max 1 (math/floor (+ (* (- seconds) ticks-per-second) 0.5))))))

(defn- mark-error!
  [attack message]
  (put attack :status :error)
  (put attack :error message)
  (put attack :pause-reason nil)
  attack)

(defn- substitute
  [vars value]
  (if (and (string? value) (string/has-prefix? "$" value))
    (or (get vars (string/slice value 1)) 0)
    value))

(defn- load-current!
  [attack]
  (def pc (get attack :pc))
  (def rows (get attack :rows))
  (if (or (< pc 0) (>= pc (length rows)))
    (if (= pc (length rows))
      (mark-error! attack
                   (string/format "Attack %v reached EOF without EndAttack after row %d"
                                  (get attack :id) pc))
      (mark-error! attack
                   (string/format "Attack %v jumped outside its program to row %d"
                                  (get attack :id) (inc pc))))
    (let [raw-row (get rows pc)
          row (tuple/slice (map |(substitute (get attack :vars) $) raw-row))]
      (put attack :current row)
      (put attack :next (+ (get attack :next)
                           (seconds->ticks (get row 0))))
      attack)))

(defn new-attack
  [programs id generation]
  (def program (get programs id))
  (unless program
    (errorf "Unknown Sans attack %v" id))
  (def attack
    @{:id id
      :status :running
      :generation generation
      :clock 0
      :next 0
      :pc 0
      :vars @{"pi" math/pi}
      :rows (get program :rows)
      :labels (get program :labels)
      :current nil
      :pause-reason nil
      :ended? false
      :error nil})
  (load-current! attack)
  attack)

(defn running?
  [attack]
  (= :running (get attack :status)))

(defn paused?
  [attack]
  (= :paused (get attack :status)))

(defn done?
  [attack]
  (or (get attack :ended?) (= :done (get attack :status))))

(defn pause!
  [attack reason]
  (when (running? attack)
    (put attack :status :paused)
    (put attack :pause-reason reason))
  attack)

(defn resume!
  [attack generation]
  (if (and (= generation (get attack :generation))
           (paused? attack)
           (not (get attack :ended?)))
    (do
      (put attack :status :running)
      (put attack :pause-reason nil)
      true)
    false))

(defn stop!
  [attack]
  (put attack :generation (inc (get attack :generation)))
  (put attack :status :stopped)
  (put attack :pause-reason nil)
  (put attack :current nil)
  attack)

(defn- put-var!
  [attack name value]
  (put (get attack :vars) (string name) value))

(defn- argument
  [args index]
  (if (< index (length args)) (get args index) nil))

(defn- numeric-target?
  [target]
  (if (or (not (string? target)) (empty? target))
    false
    (do
      (var numeric? true)
      (for index 0 (length target)
        (def byte (get target index))
        (when (or (< byte 48) (> byte 57))
          (set numeric? false)))
      numeric?)))

(defn- absolute-jump!
  [attack target]
  (def target-string (string target))
  (def destination
    (if (numeric-target? target-string)
      (dec (integer target-string))
      (get (get attack :labels) target-string)))
  (if (nil? destination)
    (mark-error! attack
                 (string/format "Label %s does not exist at row %d"
                                target-string (inc (get attack :pc))))
    # The common post-instruction increment lands on destination.
    (put attack :pc (dec destination))))

(defn- relative-jump!
  [attack offset]
  # The common post-instruction increment makes this current + offset.
  (put attack :pc (+ (get attack :pc) (integer offset) -1)))

(defn- remainder
  [left right]
  (def quotient (/ left right))
  (def truncated (if (< quotient 0) (math/ceil quotient) (math/floor quotient)))
  (- left (* truncated right)))

(defn- angle-degrees
  [x1 y1 x2 y2]
  (def degrees
    (* (math/atan2 (- y2 y1) (- x2 x1)) (/ 180 math/pi)))
  (if (< degrees 0) (+ degrees 360) degrees))

(defn- execute-cpu!
  [attack battle dispatch command args]
  (case command
    "SET"
    (put-var! attack (argument args 0) (argument args 1))

    "ADD"
    (put-var! attack (argument args 0)
              (+ (numeric (argument args 1)) (numeric (argument args 2))))

    "SUB"
    (put-var! attack (argument args 0)
              (- (numeric (argument args 1)) (numeric (argument args 2))))

    "MUL"
    (put-var! attack (argument args 0)
              (* (numeric (argument args 1)) (numeric (argument args 2))))

    "DIV"
    (put-var! attack (argument args 0)
              (/ (numeric (argument args 1)) (numeric (argument args 2))))

    "MOD"
    (put-var! attack (argument args 0)
              (remainder (numeric (argument args 1)) (numeric (argument args 2))))

    "FLOOR"
    (put-var! attack (argument args 0) (math/floor (numeric (argument args 1))))

    "DEG"
    (put-var! attack (argument args 0)
              (* (numeric (argument args 1)) (/ 180 math/pi)))

    "RAD"
    (put-var! attack (argument args 0)
              (* (numeric (argument args 1)) (/ math/pi 180)))

    "SIN"
    (put-var! attack (argument args 0)
              (math/sin (* (numeric (argument args 1)) (/ math/pi 180))))

    "COS"
    (put-var! attack (argument args 0)
              (math/cos (* (numeric (argument args 1)) (/ math/pi 180))))

    "ANGLE"
    (put-var! attack (argument args 0)
              (angle-degrees (numeric (argument args 1))
                             (numeric (argument args 2))
                             (numeric (argument args 3))
                             (numeric (argument args 4))))

    "RND"
    (let [bound (integer (argument args 1))]
      (if (> bound 0)
        (put-var! attack (argument args 0)
                  (math/rng-int (get battle :combat-rng) bound))
        (mark-error! attack
                     (string/format "RND bound must be positive at row %d"
                                    (inc (get attack :pc))))))

    "JMPABS"
    (absolute-jump! attack (argument args 0))

    "JMPREL"
    (relative-jump! attack (argument args 0))

    "JMPZ"
    (when (= 0 (numeric (argument args 1)))
      (absolute-jump! attack (argument args 0)))

    "JMPNZ"
    (when (not= 0 (numeric (argument args 1)))
      (absolute-jump! attack (argument args 0)))

    "JMPE"
    (when (= (numeric (argument args 1)) (numeric (argument args 2)))
      (absolute-jump! attack (argument args 0)))

    "JMPNE"
    (when (not= (numeric (argument args 1)) (numeric (argument args 2)))
      (absolute-jump! attack (argument args 0)))

    "JMPL"
    (when (< (numeric (argument args 1)) (numeric (argument args 2)))
      (absolute-jump! attack (argument args 0)))

    "JMPNL"
    (when (>= (numeric (argument args 1)) (numeric (argument args 2)))
      (absolute-jump! attack (argument args 0)))

    "JMPG"
    (when (> (numeric (argument args 1)) (numeric (argument args 2)))
      (absolute-jump! attack (argument args 0)))

    "JMPNG"
    (when (<= (numeric (argument args 1)) (numeric (argument args 2)))
      (absolute-jump! attack (argument args 0)))

    "GetHeartPos"
    (let [player (get battle :player)]
      (put-var! attack (argument args 0) (get player :x))
      (put-var! attack (argument args 1) (get player :y)))

    "TLPause"
    (pause! attack :script)

    "TLResume"
    (resume! attack (get attack :generation))

    "TLStop"
    (stop! attack)

    "Debug"
    (pause! attack :debug)

    (mark-error! attack
                 (string/format "Unknown timeline CPU command %s at row %d"
                                command (inc (get attack :pc))))))

(defn- execute-current!
  [attack battle dispatch]
  (def row (get attack :current))
  (def command-value (get row 1))
  (def command (string command-value))
  (unless (label-command? command)
    (def args (tuple/slice row 2))
    (if (get cpu-commands command)
      (execute-cpu! attack battle dispatch command args)
      (dispatch battle attack command args))))

(defn drain!
  [attack battle dispatch]
  (var executed 0)
  (while (and (running? attack)
              (<= (get attack :next) (get attack :clock)))
    (execute-current! attack battle dispatch)
    (++ executed)

    # Construct advances and loads the next row even when this row pauses.
    (put attack :pc (inc (get attack :pc)))

    (cond
      (>= executed instruction-budget)
      (mark-error! attack
                   (string/format "Infinite loop detected at row %d"
                                  (inc (get attack :pc))))

      (= :error (get attack :status))
      nil

      (get attack :ended?)
      (do
        (put attack :status :done)
        (put attack :pause-reason nil)
        (put attack :current nil))

      (or (running? attack) (paused? attack))
      (load-current! attack)))
  attack)

(defn step!
  [attack battle dispatch]
  (when (running? attack)
    (put attack :clock (inc (get attack :clock)))
    (drain! attack battle dispatch))
  attack)
