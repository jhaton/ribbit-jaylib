(import ./froggit)
(import ./sans)

(def default-id :froggit)

(def registry
  {:froggit froggit/encounter
   :sans sans/encounter})

(defn encounter
  [id]
  (get registry id))

(defn ids
  []
  (keys registry))
