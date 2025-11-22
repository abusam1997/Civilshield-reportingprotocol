;; CivicShield.clar
;; CivicShield - Crime Reporting Protocol (CCRP)
;; Version 1.0
;; Author: generated for user

;; ----------------------------
;; Constants & Errors
;; ----------------------------

(define-constant contract-owner tx-sender) ;; set owner at deploy time

(define-constant ERR-NOT-AUTHORIZED u401)
(define-constant ERR-ALREADY-REGISTERED u402)
(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-ALREADY-VOTED u409)
(define-constant ERR-INVALID-INPUT u410)

;; ----------------------------
;; Storage
;; ----------------------------

;; Auto-incrementing report counter
(define-data-var report-counter uint u0)

;; Map: report-id -> report record
(define-map crime-reports
  { id: uint }
  {
    reporter: principal,
    anonymous: bool,
    category: (string-ascii 40),
    description: (string-ascii 512),
    location: (string-ascii 80),
    proof-hash: (optional (string-ascii 64)),
    status: (string-ascii 24),
    timestamp: uint
  }
)

;; Map: agency-principal -> approved?: bool
(define-map agencies { agency: principal } { approved: bool })

;; Map: report-id -> duplicate vote count
(define-map duplicate-counts { id: uint } { count: uint })

;; Map: composite key {id, voter} -> voted?: bool (prevents double voting)
(define-map duplicate-voters { id: uint, voter: principal } { voted: bool })

;; ----------------------------
;; Events (using print statements)
;; ----------------------------
;; Note: define-event doesn't exist in Clarity; we use print statements instead

;; ----------------------------
;; Helpers / Internal checks
;; ----------------------------

(define-read-only (is-owner (p principal))
  (is-eq p contract-owner)
)

(define-read-only (is-agency (p principal))
  (match (map-get? agencies { agency: p })
    entry (get approved entry)
    false
  )
)

;; ----------------------------
;; Public: Agency management (owner only)
;; ----------------------------

(define-public (register-agency (agency principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq agency (as-contract tx-sender))) (err ERR-INVALID-INPUT))
    (match (map-get? agencies { agency: agency })
      existing (err ERR-ALREADY-REGISTERED)
      (begin
        (map-set agencies { agency: agency } { approved: true })
        (print { event: "agency-registered", agency: agency, registered-by: tx-sender })
        (ok true)
      )
    )
  )
)

(define-public (unregister-agency (agency principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq agency (as-contract tx-sender))) (err ERR-INVALID-INPUT))
    (match (map-get? agencies { agency: agency })
      entry
        (begin
          (map-delete agencies { agency: agency })
          (ok true)
        )
      (err ERR-NOT-FOUND)
    )
  )
)

;; ----------------------------
;; Public: Submit report
;; ----------------------------
;; category, description, location are fixed-size ascii strings for readability/testing
;; proof-hash is optional (IPFS/Arweave hash stored off-chain)
(define-public (submit-report
              (category (string-ascii 40))
              (description (string-ascii 512))
              (location (string-ascii 80))
              (proof-hash (optional (string-ascii 64)))
              (anonymous bool))
  (let ((id (+ (var-get report-counter) u1))
        (time u0))
    (begin
      ;; basic input checks
      (asserts! (not (is-eq (len category) u0)) (err ERR-INVALID-INPUT))
      (asserts! (not (is-eq (len description) u0)) (err ERR-INVALID-INPUT))
      (asserts! (not (is-eq (len location) u0)) (err ERR-INVALID-INPUT))
      (asserts! (match proof-hash
        entry (not (is-eq (len entry) u0))
        true) (err ERR-INVALID-INPUT))
      ;; store
      (map-set crime-reports { id: id }
        {
          reporter: tx-sender,
          anonymous: anonymous,
          category: category,
          description: description,
          location: location,
          proof-hash: proof-hash,
          status: "pending",
          timestamp: time
        }
      )
      (var-set report-counter id)
      (print { event: "report-submitted", id: id, reporter: tx-sender, anonymous: anonymous, category: category, timestamp: time })
      (ok id)
    )
  )
)

;; ----------------------------
;; Public: Update status (agencies only)
;; ----------------------------
;; new-status is a string like: "pending", "under-investigation", "resolved", "dismissed"
(define-public (update-status (report-id uint) (new-status (string-ascii 24)))
  (begin
    ;; must be an approved agency
    (asserts! (> report-id u0) (err ERR-INVALID-INPUT))
    (asserts! (is-eq (get approved (unwrap-panic (map-get? agencies { agency: tx-sender }))) true) (err ERR-NOT-AUTHORIZED))
    (match (map-get? crime-reports { id: report-id })
      report-data
        (let ((old-status (get status report-data))
              (time u0))
          (begin
            (map-set crime-reports { id: report-id }
              (merge report-data { status: new-status }))
            (print { event: "status-updated", id: report-id, by: tx-sender, old-status: old-status, new-status: new-status, timestamp: time })
            (ok true)
          )
        )
      (err ERR-NOT-FOUND)
    )
  )
)

;; ----------------------------
;; Public: Duplicate vote (any user can flag duplicates, 1 vote per wallet per report)
;; ----------------------------
(define-public (vote-duplicate (report-id uint))
  (begin
    (asserts! (> report-id u0) (err ERR-INVALID-INPUT))
    ;; ensure report exists
    (match (map-get? crime-reports { id: report-id })
      report-data
        (let ((voted? (map-get? duplicate-voters { id: report-id, voter: tx-sender })))
          (match voted?
            entry (err ERR-ALREADY-VOTED)
            (begin
              ;; mark voted
              (map-set duplicate-voters { id: report-id, voter: tx-sender } { voted: true })
              ;; increment count
              (let ((current (match (map-get? duplicate-counts { id: report-id })
                              entry (get count entry)
                              u0)))
                (map-set duplicate-counts { id: report-id } { count: (+ current u1) })
                (let ((new-count (+ current u1)))
                  (print { event: "duplicate-voted", id: report-id, voter: tx-sender, new-count: new-count })
                  (ok new-count)
                )
              )
            )
          )
        )
      (err ERR-NOT-FOUND)
    )
  )
)

;; ----------------------------
;; Read-only: Public views
;; ----------------------------

;; get the raw report (owner/agency/reporter only - else reporter is masked by returning none)
(define-read-only (get-report (report-id uint))
  (match (map-get? crime-reports { id: report-id })
    report
      (let ((is-authorized (or (is-eq tx-sender contract-owner)
                               (match (map-get? agencies { agency: tx-sender }) a (get approved a) false)
                               (is-eq tx-sender (get reporter report)))))
        (ok
          (tuple
            (id report-id)
            (reporter (if is-authorized (some (get reporter report)) none))
            (anonymous (get anonymous report))
            (category (get category report))
            (description (get description report))
            (location (get location report))
            (proof-hash (get proof-hash report))
            (status (get status report))
            (timestamp (get timestamp report))
          )
        )
      )
    (err ERR-NOT-FOUND)
  )
)

;; get duplicate count for a report
(define-read-only (get-duplicate-count (report-id uint))
  (ok (match (map-get? duplicate-counts { id: report-id })
        entry (get count entry)
        u0))
)

;; get total report count
(define-read-only (get-report-count)
  (ok (var-get report-counter))
)

;; list a range of reports (from start (inclusive) count number)
;; returns a tuple array is not supported; we'll return a simple helper that returns the id at index (1-based)
(define-read-only (get-report-id-by-index (index uint))
  (let ((total (var-get report-counter)))
    (if (or (<= index u0) (> index total))
        (err ERR-NOT-FOUND)
        (ok index)
    )
  )
)
