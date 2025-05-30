;; Research Protocol Contract
;; Records consciousness exploration methodologies

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_PROTOCOL (err u202))

;; Protocol data structure
(define-map research-protocols
  { protocol-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    methodology: (string-ascii 300),
    consciousness-domain: (string-ascii 100),
    created-by: principal,
    creation-date: uint,
    status: (string-ascii 20),
    peer-reviews: uint,
    approval-status: (string-ascii 20)
  }
)

;; Protocol counter
(define-data-var protocol-counter uint u0)

;; Protocol approvals
(define-map protocol-approvals
  { protocol-id: uint, reviewer: principal }
  { approved: bool, review-date: uint }
)

;; Create new research protocol
(define-public (create-protocol
  (title (string-ascii 100))
  (description (string-ascii 500))
  (methodology (string-ascii 300))
  (consciousness-domain (string-ascii 100))
)
  (let ((protocol-id (+ (var-get protocol-counter) u1)))
    (begin
      (map-set research-protocols
        { protocol-id: protocol-id }
        {
          title: title,
          description: description,
          methodology: methodology,
          consciousness-domain: consciousness-domain,
          created-by: tx-sender,
          creation-date: block-height,
          status: "draft",
          peer-reviews: u0,
          approval-status: "pending"
        }
      )
      (var-set protocol-counter protocol-id)
      (ok protocol-id)
    )
  )
)

;; Submit protocol for review
(define-public (submit-for-review (protocol-id uint))
  (match (map-get? research-protocols { protocol-id: protocol-id })
    protocol-data
    (begin
      (asserts! (is-eq (get created-by protocol-data) tx-sender) ERR_UNAUTHORIZED)
      (map-set research-protocols
        { protocol-id: protocol-id }
        (merge protocol-data { status: "under-review" })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; Peer review protocol
(define-public (peer-review (protocol-id uint) (approved bool))
  (match (map-get? research-protocols { protocol-id: protocol-id })
    protocol-data
    (begin
      (map-set protocol-approvals
        { protocol-id: protocol-id, reviewer: tx-sender }
        { approved: approved, review-date: block-height }
      )
      (map-set research-protocols
        { protocol-id: protocol-id }
        (merge protocol-data {
          peer-reviews: (+ (get peer-reviews protocol-data) u1)
        })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; Approve protocol (requires multiple peer reviews)
(define-public (approve-protocol (protocol-id uint))
  (match (map-get? research-protocols { protocol-id: protocol-id })
    protocol-data
    (begin
      (asserts! (>= (get peer-reviews protocol-data) u3) ERR_UNAUTHORIZED)
      (map-set research-protocols
        { protocol-id: protocol-id }
        (merge protocol-data {
          status: "approved",
          approval-status: "approved"
        })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; Get protocol details
(define-read-only (get-protocol (protocol-id uint))
  (map-get? research-protocols { protocol-id: protocol-id })
)

;; Get protocol count
(define-read-only (get-protocol-count)
  (var-get protocol-counter)
)

;; Check if reviewer approved protocol
(define-read-only (get-review-status (protocol-id uint) (reviewer principal))
  (map-get? protocol-approvals { protocol-id: protocol-id, reviewer: reviewer })
)
