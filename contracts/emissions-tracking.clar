;; Carbon Emissions Tracking Contract
;; Monitors and reduces greenhouse gas emissions from public transportation

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-DATA (err u501))
(define-constant ERR-VEHICLE-NOT-FOUND (err u502))
(define-constant ERR-ROUTE-NOT-FOUND (err u503))
(define-constant ERR-INVALID-FUEL-TYPE (err u504))

;; Fuel type constants
(define-constant FUEL-DIESEL u1)
(define-constant FUEL-ELECTRIC u2)
(define-constant FUEL-HYBRID u3)
(define-constant FUEL-HYDROGEN u4)
(define-constant FUEL-CNG u5)

;; Data Variables
(define-data-var next-vehicle-id uint u1)
(define-data-var carbon-reduction-target uint u20) ;; 20% reduction target
(define-data-var tracking-active bool true)

;; Data Maps
(define-map vehicle-emissions
  { vehicle-id: uint }
  {
    vehicle-type: (string-ascii 50),
    fuel-type: uint,
    daily-emissions: uint, ;; grams of CO2
    fuel-efficiency: uint, ;; km per liter or kWh per 100km
    annual-mileage: uint,
    last-maintenance: uint,
    emission-standard: (string-ascii 20)
  }
)

(define-map route-emissions
  { route-id: uint, date: uint }
  {
    total-emissions: uint,
    passenger-count: uint,
    emissions-per-passenger: uint,
    fuel-consumed: uint,
    distance-covered: uint,
    efficiency-rating: uint
  }
)

(define-map emission-targets
  { target-year: uint }
  {
    baseline-emissions: uint,
    target-reduction: uint,
    current-emissions: uint,
    progress-percentage: uint,
    strategies: (string-ascii 300)
  }
)

(define-map carbon-offsets
  { offset-id: uint }
  {
    offset-type: (string-ascii 100),
    carbon-credits: uint,
    cost: uint,
    verification-status: bool,
    purchase-date: uint,
    expiry-date: uint
  }
)

(define-map sustainability-metrics
  { metric-date: uint }
  {
    total-fleet-emissions: uint,
    renewable-energy-usage: uint,
    passenger-miles-per-gallon: uint,
    carbon-intensity: uint,
    green-vehicle-percentage: uint
  }
)

(define-map emission-reports
  { report-id: uint }
  {
    reporting-period: { start: uint, end: uint },
    total-emissions: uint,
    emission-sources: (list 10 { source: (string-ascii 50), amount: uint }),
    reduction-achieved: uint,
    recommendations: (string-ascii 500)
  }
)

;; Authorization check
(define-private (is-authorized (sender principal))
  (or (is-eq sender CONTRACT-OWNER)
      (is-eq sender tx-sender)))

;; Validation functions
(define-private (is-valid-fuel-type (fuel-type uint))
  (and (>= fuel-type u1) (<= fuel-type u5)))

(define-private (is-valid-emissions (emissions uint))
  (<= emissions u100000)) ;; Max 100kg CO2 per day

(define-private (is-valid-efficiency (efficiency uint))
  (and (> efficiency u0) (<= efficiency u50))) ;; Reasonable efficiency range

;; Public Functions

;; Register vehicle emissions profile
(define-public (register-vehicle (vehicle-type (string-ascii 50)) (fuel-type uint) (daily-emissions uint) (fuel-efficiency uint) (annual-mileage uint) (emission-standard (string-ascii 20)))
  (let ((vehicle-id (var-get next-vehicle-id)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-fuel-type fuel-type) ERR-INVALID-FUEL-TYPE)
    (asserts! (is-valid-emissions daily-emissions) ERR-INVALID-DATA)
    (asserts! (is-valid-efficiency fuel-efficiency) ERR-INVALID-DATA)
    (asserts! (> annual-mileage u0) ERR-INVALID-DATA)

    (map-set vehicle-emissions
      { vehicle-id: vehicle-id }
      {
        vehicle-type: vehicle-type,
        fuel-type: fuel-type,
        daily-emissions: daily-emissions,
        fuel-efficiency: fuel-efficiency,
        annual-mileage: annual-mileage,
        last-maintenance: block-height,
        emission-standard: emission-standard
      }
    )

    (var-set next-vehicle-id (+ vehicle-id u1))
    (ok vehicle-id)
  )
)

;; Record route emissions
(define-public (record-route-emissions (route-id uint) (total-emissions uint) (passenger-count uint) (fuel-consumed uint) (distance-covered uint))
  (let ((emissions-per-passenger (if (> passenger-count u0) (/ total-emissions passenger-count) u0))
        (efficiency-rating (calculate-efficiency-rating total-emissions distance-covered passenger-count)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-emissions total-emissions) ERR-INVALID-DATA)
    (asserts! (> distance-covered u0) ERR-INVALID-DATA)

    (map-set route-emissions
      { route-id: route-id, date: block-height }
      {
        total-emissions: total-emissions,
        passenger-count: passenger-count,
        emissions-per-passenger: emissions-per-passenger,
        fuel-consumed: fuel-consumed,
        distance-covered: distance-covered,
        efficiency-rating: efficiency-rating
      }
    )

    (ok true)
  )
)

;; Set emission reduction targets
(define-public (set-emission-targets (target-year uint) (baseline-emissions uint) (target-reduction uint) (strategies (string-ascii 300)))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> target-year block-height) ERR-INVALID-DATA)
    (asserts! (> baseline-emissions u0) ERR-INVALID-DATA)
    (asserts! (and (> target-reduction u0) (<= target-reduction u100)) ERR-INVALID-DATA)

    (map-set emission-targets
      { target-year: target-year }
      {
        baseline-emissions: baseline-emissions,
        target-reduction: target-reduction,
        current-emissions: baseline-emissions,
        progress-percentage: u0,
        strategies: strategies
      }
    )

    (ok true)
  )
)

;; Purchase carbon offsets
(define-public (purchase-carbon-offsets (offset-id uint) (offset-type (string-ascii 100)) (carbon-credits uint) (cost uint) (expiry-date uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> carbon-credits u0) ERR-INVALID-DATA)
    (asserts! (> cost u0) ERR-INVALID-DATA)
    (asserts! (> expiry-date block-height) ERR-INVALID-DATA)

    (map-set carbon-offsets
      { offset-id: offset-id }
      {
        offset-type: offset-type,
        carbon-credits: carbon-credits,
        cost: cost,
        verification-status: false,
        purchase-date: block-height,
        expiry-date: expiry-date
      }
    )

    (ok true)
  )
)

;; Update sustainability metrics
(define-public (update-sustainability-metrics (total-fleet-emissions uint) (renewable-energy uint) (passenger-mpg uint) (carbon-intensity uint) (green-percentage uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-emissions total-fleet-emissions) ERR-INVALID-DATA)
    (asserts! (<= renewable-energy u100) ERR-INVALID-DATA)
    (asserts! (> passenger-mpg u0) ERR-INVALID-DATA)
    (asserts! (<= green-percentage u100) ERR-INVALID-DATA)

    (map-set sustainability-metrics
      { metric-date: block-height }
      {
        total-fleet-emissions: total-fleet-emissions,
        renewable-energy-usage: renewable-energy,
        passenger-miles-per-gallon: passenger-mpg,
        carbon-intensity: carbon-intensity,
        green-vehicle-percentage: green-percentage
      }
    )

    (ok true)
  )
)

;; Generate emission report
(define-public (generate-emission-report (report-id uint) (start-period uint) (end-period uint) (total-emissions uint) (emission-sources (list 10 { source: (string-ascii 50), amount: uint })) (reduction-achieved uint) (recommendations (string-ascii 500)))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (< start-period end-period) ERR-INVALID-DATA)
    (asserts! (is-valid-emissions total-emissions) ERR-INVALID-DATA)

    (map-set emission-reports
      { report-id: report-id }
      {
        reporting-period: { start: start-period, end: end-period },
        total-emissions: total-emissions,
        emission-sources: emission-sources,
        reduction-achieved: reduction-achieved,
        recommendations: recommendations
      }
    )

    (ok true)
  )
)

;; Update vehicle maintenance
(define-public (update-vehicle-maintenance (vehicle-id uint) (new-emissions uint) (new-efficiency uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-emissions new-emissions) ERR-INVALID-DATA)
    (asserts! (is-valid-efficiency new-efficiency) ERR-INVALID-DATA)

    (match (map-get? vehicle-emissions { vehicle-id: vehicle-id })
      vehicle
      (begin
        (map-set vehicle-emissions
          { vehicle-id: vehicle-id }
          (merge vehicle {
            daily-emissions: new-emissions,
            fuel-efficiency: new-efficiency,
            last-maintenance: block-height
          })
        )
        (ok true)
      )
      ERR-VEHICLE-NOT-FOUND
    )
  )
)

;; Private helper functions
(define-private (calculate-efficiency-rating (emissions uint) (distance uint) (passengers uint))
  (if (and (> distance u0) (> passengers u0))
    (let ((emissions-per-km-per-passenger (/ emissions (* distance passengers))))
      (if (< emissions-per-km-per-passenger u50)
        u5 ;; Excellent
        (if (< emissions-per-km-per-passenger u100)
          u4 ;; Good
          (if (< emissions-per-km-per-passenger u150)
            u3 ;; Average
            (if (< emissions-per-km-per-passenger u200)
              u2 ;; Poor
              u1 ;; Very poor
            )
          )
        )
      )
    )
    u1
  )
)

;; Read-only Functions

;; Get vehicle emissions
(define-read-only (get-vehicle-emissions (vehicle-id uint))
  (map-get? vehicle-emissions { vehicle-id: vehicle-id })
)

;; Get route emissions
(define-read-only (get-route-emissions (route-id uint) (date uint))
  (map-get? route-emissions { route-id: route-id, date: date })
)

;; Get emission targets
(define-read-only (get-emission-targets (target-year uint))
  (map-get? emission-targets { target-year: target-year })
)

;; Get carbon offsets
(define-read-only (get-carbon-offsets (offset-id uint))
  (map-get? carbon-offsets { offset-id: offset-id })
)

;; Get sustainability metrics
(define-read-only (get-sustainability-metrics (metric-date uint))
  (map-get? sustainability-metrics { metric-date: metric-date })
)

;; Get emission report
(define-read-only (get-emission-report (report-id uint))
  (map-get? emission-reports { report-id: report-id })
)

;; Get carbon reduction target
(define-read-only (get-carbon-reduction-target)
  (var-get carbon-reduction-target)
)

;; Get tracking status
(define-read-only (get-tracking-status)
  (var-get tracking-active)
)

;; Calculate total fleet emissions
(define-read-only (calculate-total-fleet-emissions (vehicle-ids (list 100 uint)))
  (fold calculate-vehicle-emissions vehicle-ids u0)
)

(define-private (calculate-vehicle-emissions (vehicle-id uint) (total uint))
  (match (get-vehicle-emissions vehicle-id)
    vehicle
    (+ total (get daily-emissions vehicle))
    total
  )
)

;; Get next vehicle ID
(define-read-only (get-next-vehicle-id)
  (var-get next-vehicle-id)
)

;; Calculate carbon footprint per passenger
(define-read-only (calculate-carbon-per-passenger (route-id uint) (date uint))
  (match (get-route-emissions route-id date)
    route-data
    (some (get emissions-per-passenger route-data))
    none
  )
)
