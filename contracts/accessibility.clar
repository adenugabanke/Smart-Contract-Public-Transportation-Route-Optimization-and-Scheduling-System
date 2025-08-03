;; Accessibility Accommodation Contract
;; Ensures transit systems meet the needs of disabled passengers

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-REQUEST (err u401))
(define-constant ERR-INVALID-DATA (err u402))
(define-constant ERR-REQUEST-NOT-FOUND (err u403))
(define-constant ERR-FACILITY-NOT-FOUND (err u404))

;; Accessibility feature constants
(define-constant FEATURE-WHEELCHAIR u1)
(define-constant FEATURE-AUDIO u2)
(define-constant FEATURE-VISUAL u3)
(define-constant FEATURE-COGNITIVE u4)
(define-constant FEATURE-MOBILITY u5)

;; Data Variables
(define-data-var next-request-id uint u1)
(define-data-var next-facility-id uint u1)
(define-data-var compliance-active bool true)

;; Data Maps
(define-map accessibility-features
  { facility-id: uint }
  {
    facility-name: (string-ascii 100),
    location: (string-ascii 100),
    wheelchair-accessible: bool,
    audio-announcements: bool,
    visual-displays: bool,
    tactile-guidance: bool,
    elevator-access: bool,
    ramp-access: bool,
    accessible-restrooms: bool,
    compliance-score: uint
  }
)

(define-map accommodation-requests
  { request-id: uint }
  {
    passenger-id: principal,
    route-id: uint,
    accommodation-type: uint,
    request-details: (string-ascii 200),
    priority-level: uint,
    status: (string-ascii 20),
    created-at: uint,
    resolved-at: (optional uint)
  }
)

(define-map compliance-records
  { facility-id: uint, audit-date: uint }
  {
    ada-compliant: bool,
    accessibility-score: uint,
    violations: (list 10 uint),
    improvements-needed: (string-ascii 300),
    next-audit-date: uint
  }
)

(define-map passenger-profiles
  { passenger-id: principal }
  {
    accessibility-needs: (list 10 uint),
    preferred-accommodations: (string-ascii 200),
    emergency-contact: (string-ascii 100),
    mobility-device: (optional (string-ascii 50)),
    communication-preference: uint
  }
)

(define-map service-alerts
  { alert-id: uint }
  {
    affected-routes: (list 20 uint),
    accessibility-impact: (string-ascii 300),
    alternative-options: (string-ascii 300),
    estimated-duration: uint,
    severity-level: uint,
    created-at: uint
  }
)

;; Authorization check
(define-private (is-authorized (sender principal))
  (or (is-eq sender CONTRACT-OWNER)
      (is-eq sender tx-sender)))

;; Validation functions
(define-private (is-valid-feature (feature-type uint))
  (and (>= feature-type u1) (<= feature-type u5)))

(define-private (is-valid-priority (priority uint))
  (and (>= priority u1) (<= priority u5)))

(define-private (is-valid-score (score uint))
  (and (>= score u0) (<= score u100)))

;; Public Functions

;; Register accessibility facility
(define-public (register-facility (facility-name (string-ascii 100)) (location (string-ascii 100)) (wheelchair bool) (audio bool) (visual bool) (tactile bool) (elevator bool) (ramp bool) (restrooms bool))
  (let ((facility-id (var-get next-facility-id))
        (compliance-score (calculate-compliance-score wheelchair audio visual tactile elevator ramp restrooms)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (map-set accessibility-features
      { facility-id: facility-id }
      {
        facility-name: facility-name,
        location: location,
        wheelchair-accessible: wheelchair,
        audio-announcements: audio,
        visual-displays: visual,
        tactile-guidance: tactile,
        elevator-access: elevator,
        ramp-access: ramp,
        accessible-restrooms: restrooms,
        compliance-score: compliance-score
      }
    )

    (var-set next-facility-id (+ facility-id u1))
    (ok facility-id)
  )
)

;; Submit accommodation request
(define-public (submit-accommodation-request (route-id uint) (accommodation-type uint) (request-details (string-ascii 200)) (priority-level uint))
  (let ((request-id (var-get next-request-id)))
    (asserts! (is-valid-feature accommodation-type) ERR-INVALID-DATA)
    (asserts! (is-valid-priority priority-level) ERR-INVALID-DATA)

    (map-set accommodation-requests
      { request-id: request-id }
      {
        passenger-id: tx-sender,
        route-id: route-id,
        accommodation-type: accommodation-type,
        request-details: request-details,
        priority-level: priority-level,
        status: "pending",
        created-at: block-height,
        resolved-at: none
      }
    )

    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Update accommodation request status
(define-public (update-request-status (request-id uint) (new-status (string-ascii 20)))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (match (map-get? accommodation-requests { request-id: request-id })
      request
      (begin
        (map-set accommodation-requests
          { request-id: request-id }
          (merge request {
            status: new-status,
            resolved-at: (if (is-eq new-status "resolved") (some block-height) none)
          })
        )
        (ok true)
      )
      ERR-REQUEST-NOT-FOUND
    )
  )
)

;; Record compliance audit
(define-public (record-compliance-audit (facility-id uint) (ada-compliant bool) (accessibility-score uint) (violations (list 10 uint)) (improvements (string-ascii 300)) (next-audit uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-score accessibility-score) ERR-INVALID-DATA)

    (map-set compliance-records
      { facility-id: facility-id, audit-date: block-height }
      {
        ada-compliant: ada-compliant,
        accessibility-score: accessibility-score,
        violations: violations,
        improvements-needed: improvements,
        next-audit-date: next-audit
      }
    )

    (ok true)
  )
)

;; Create passenger accessibility profile
(define-public (create-passenger-profile (accessibility-needs (list 10 uint)) (preferred-accommodations (string-ascii 200)) (emergency-contact (string-ascii 100)) (mobility-device (optional (string-ascii 50))) (communication-pref uint))
  (begin
    (map-set passenger-profiles
      { passenger-id: tx-sender }
      {
        accessibility-needs: accessibility-needs,
        preferred-accommodations: preferred-accommodations,
        emergency-contact: emergency-contact,
        mobility-device: mobility-device,
        communication-preference: communication-pref
      }
    )

    (ok true)
  )
)

;; Create service alert
(define-public (create-service-alert (alert-id uint) (affected-routes (list 20 uint)) (accessibility-impact (string-ascii 300)) (alternatives (string-ascii 300)) (duration uint) (severity uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= severity u1) (<= severity u5)) ERR-INVALID-DATA)

    (map-set service-alerts
      { alert-id: alert-id }
      {
        affected-routes: affected-routes,
        accessibility-impact: accessibility-impact,
        alternative-options: alternatives,
        estimated-duration: duration,
        severity-level: severity,
        created-at: block-height
      }
    )

    (ok true)
  )
)

;; Update facility accessibility features
(define-public (update-facility-features (facility-id uint) (feature-updates (list 10 { feature: uint, enabled: bool })))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (match (map-get? accessibility-features { facility-id: facility-id })
      facility
      (let ((updated-facility (apply-feature-updates facility feature-updates)))
        (map-set accessibility-features
          { facility-id: facility-id }
          updated-facility
        )
        (ok true)
      )
      ERR-FACILITY-NOT-FOUND
    )
  )
)

;; Private helper functions
(define-private (calculate-compliance-score (wheelchair bool) (audio bool) (visual bool) (tactile bool) (elevator bool) (ramp bool) (restrooms bool))
  (let ((score-base u0)
        (score-wheelchair (if wheelchair u20 u0))
        (score-audio (if audio u15 u0))
        (score-visual (if visual u15 u0))
        (score-tactile (if tactile u10 u0))
        (score-elevator (if elevator u15 u0))
        (score-ramp (if ramp u15 u0))
        (score-restrooms (if restrooms u10 u0)))
    (+ score-base score-wheelchair score-audio score-visual score-tactile score-elevator score-ramp score-restrooms)
  )
)

(define-private (apply-feature-updates (facility { facility-name: (string-ascii 100), location: (string-ascii 100), wheelchair-accessible: bool, audio-announcements: bool, visual-displays: bool, tactile-guidance: bool, elevator-access: bool, ramp-access: bool, accessible-restrooms: bool, compliance-score: uint }) (updates (list 10 { feature: uint, enabled: bool })))
  facility ;; Simplified - would implement actual feature updates
)

;; Read-only Functions

;; Get accessibility features
(define-read-only (get-accessibility-features (facility-id uint))
  (map-get? accessibility-features { facility-id: facility-id })
)

;; Get accommodation request
(define-read-only (get-accommodation-request (request-id uint))
  (map-get? accommodation-requests { request-id: request-id })
)

;; Get compliance record
(define-read-only (get-compliance-record (facility-id uint) (audit-date uint))
  (map-get? compliance-records { facility-id: facility-id, audit-date: audit-date })
)

;; Get passenger profile
(define-read-only (get-passenger-profile (passenger-id principal))
  (map-get? passenger-profiles { passenger-id: passenger-id })
)

;; Get service alert
(define-read-only (get-service-alert (alert-id uint))
  (map-get? service-alerts { alert-id: alert-id })
)

;; Get compliance status
(define-read-only (get-compliance-status)
  (var-get compliance-active)
)

;; Check route accessibility
(define-read-only (check-route-accessibility (route-id uint) (required-features (list 10 uint)))
  (let ((accessibility-rating (calculate-route-accessibility route-id required-features)))
    (some accessibility-rating)
  )
)

(define-private (calculate-route-accessibility (route-id uint) (features (list 10 uint)))
  u85 ;; Simplified calculation
)

;; Get next request ID
(define-read-only (get-next-request-id)
  (var-get next-request-id)
)

;; Get next facility ID
(define-read-only (get-next-facility-id)
  (var-get next-facility-id)
)

;; Calculate facility accessibility score
(define-read-only (calculate-facility-score (facility-id uint))
  (match (get-accessibility-features facility-id)
    facility
    (some (get compliance-score facility))
    none
  )
)
