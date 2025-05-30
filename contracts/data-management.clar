;; Data Management Contract
;; Handles consciousness research data

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_ACCESS_DENIED (err u302))

;; Research data structure
(define-map research-data
  { data-id: uint }
  {
    title: (string-ascii 100),
    data-hash: (string-ascii 64),
    data-type: (string-ascii 50),
    consciousness-category: (string-ascii 100),
    researcher: principal,
    institution-id: uint,
    upload-date: uint,
    access-level: (string-ascii 20),
    validation-status: (string-ascii 20),
    download-count: uint
  }
)

;; Data counter
(define-data-var data-counter uint u0)

;; Data access permissions
(define-map data-access
  { data-id: uint, accessor: principal }
  { granted: bool, grant-date: uint }
)

;; Data validation records
(define-map data-validations
  { data-id: uint, validator: principal }
  { validated: bool, validation-date: uint, notes: (string-ascii 200) }
)

;; Upload research data
(define-public (upload-data
  (title (string-ascii 100))
  (data-hash (string-ascii 64))
  (data-type (string-ascii 50))
  (consciousness-category (string-ascii 100))
  (institution-id uint)
  (access-level (string-ascii 20))
)
  (let ((data-id (+ (var-get data-counter) u1)))
    (begin
      (map-set research-data
        { data-id: data-id }
        {
          title: title,
          data-hash: data-hash,
          data-type: data-type,
          consciousness-category: consciousness-category,
          researcher: tx-sender,
          institution-id: institution-id,
          upload-date: block-height,
          access-level: access-level,
          validation-status: "pending",
          download-count: u0
        }
      )
      (var-set data-counter data-id)
      (ok data-id)
    )
  )
)

;; Grant data access
(define-public (grant-access (data-id uint) (accessor principal))
  (match (map-get? research-data { data-id: data-id })
    data-info
    (begin
      (asserts! (is-eq (get researcher data-info) tx-sender) ERR_UNAUTHORIZED)
      (map-set data-access
        { data-id: data-id, accessor: accessor }
        { granted: true, grant-date: block-height }
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; Validate research data
(define-public (validate-data (data-id uint) (validated bool) (notes (string-ascii 200)))
  (match (map-get? research-data { data-id: data-id })
    data-info
    (begin
      (map-set data-validations
        { data-id: data-id, validator: tx-sender }
        { validated: validated, validation-date: block-height, notes: notes }
      )
      (if validated
        (map-set research-data
          { data-id: data-id }
          (merge data-info { validation-status: "validated" })
        )
        (map-set research-data
          { data-id: data-id }
          (merge data-info { validation-status: "rejected" })
        )
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; Access research data (increment download count)
(define-public (access-data (data-id uint))
  (match (map-get? research-data { data-id: data-id })
    data-info
    (let ((has-access (or
           (is-eq (get researcher data-info) tx-sender)
           (is-eq (get access-level data-info) "public")
           (default-to false (get granted (map-get? data-access { data-id: data-id, accessor: tx-sender })))
         )))
      (begin
        (asserts! has-access ERR_ACCESS_DENIED)
        (map-set research-data
          { data-id: data-id }
          (merge data-info { download-count: (+ (get download-count data-info) u1) })
        )
        (ok data-info)
      )
    )
    ERR_NOT_FOUND
  )
)

;; Get data details
(define-read-only (get-data (data-id uint))
  (map-get? research-data { data-id: data-id })
)

;; Check access permission
(define-read-only (has-data-access (data-id uint) (accessor principal))
  (match (map-get? research-data { data-id: data-id })
    data-info
    (or
      (is-eq (get researcher data-info) accessor)
      (is-eq (get access-level data-info) "public")
      (default-to false (get granted (map-get? data-access { data-id: data-id, accessor: accessor })))
    )
    false
  )
)

;; Get data count
(define-read-only (get-data-count)
  (var-get data-counter)
)
