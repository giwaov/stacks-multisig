;; Multisig Wallet Contract - Multi-signature transactions
;; Built with @stacks/transactions

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_SIGNED (err u101))
(define-constant ERR_NOT_ENOUGH_SIGNATURES (err u102))
(define-constant ERR_TX_NOT_FOUND (err u103))
(define-constant ERR_TX_ALREADY_EXECUTED (err u104))
(define-constant ERR_TX_EXPIRED (err u105))
(define-constant ERR_TX_CANCELLED (err u106))
(define-constant ERR_ALREADY_OWNER (err u107))
(define-constant ERR_NOT_OWNER (err u108))
(define-constant ERR_CANNOT_REMOVE_SELF (err u109))
(define-constant ERR_MIN_OWNERS (err u110))
(define-constant TX_EXPIRY_BLOCKS u1008) ;; ~7 days

;; Data vars
(define-data-var tx-count uint u0)
(define-data-var required-signatures uint u2)
(define-data-var owner-count uint u1)
(define-data-var total-executed uint u0)
(define-data-var wallet-name (string-utf8 50) u"Multisig Wallet")

;; Maps
(define-map owners principal bool)
(define-map transactions uint {
  to: principal,
  amount: uint,
  signatures: uint,
  executed: bool,
  cancelled: bool,
  created-at: uint,
  memo: (string-utf8 100)
})
(define-map has-signed { tx-id: uint, signer: principal } bool)
(define-map owner-proposals uint {
  action: (string-ascii 10),
  target: principal,
  signatures: uint,
  executed: bool
})
(define-map owner-proposal-signed { proposal-id: uint, signer: principal } bool)

;; Initialize deployer as first owner
(map-set owners tx-sender true)

;; Read-only functions
(define-read-only (get-tx-count)
  (var-get tx-count))

(define-read-only (get-required-signatures)
  (var-get required-signatures))

(define-read-only (get-owner-count)
  (var-get owner-count))

(define-read-only (get-total-executed)
  (var-get total-executed))

(define-read-only (get-wallet-name)
  (var-get wallet-name))

(define-read-only (is-owner (user principal))
  (default-to false (map-get? owners user)))

(define-read-only (get-transaction (id uint))
  (map-get? transactions id))

(define-read-only (has-user-signed (tx-id uint) (signer principal))
  (default-to false (map-get? has-signed { tx-id: tx-id, signer: signer })))

(define-read-only (is-tx-expired (tx-id uint))
  (match (map-get? transactions tx-id)
    tx (> block-height (+ (get created-at tx) TX_EXPIRY_BLOCKS))
    true))

(define-read-only (can-execute (tx-id uint))
  (match (map-get? transactions tx-id)
    tx (and
      (>= (get signatures tx) (var-get required-signatures))
      (not (get executed tx))
      (not (get cancelled tx))
      (not (is-tx-expired tx-id)))
    false))

(define-read-only (get-wallet-balance)
  (stx-get-balance (as-contract tx-sender)))

(define-read-only (get-pending-count)
  ;; Returns approximate - for UI display
  (- (var-get tx-count) (var-get total-executed)))

;; Public functions
(define-public (submit-transaction (to principal) (amount uint) (memo (string-utf8 100)))
  (let ((new-id (+ (var-get tx-count) u1)))
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (map-set transactions new-id {
      to: to,
      amount: amount,
      signatures: u1,
      executed: false,
      cancelled: false,
      created-at: block-height,
      memo: memo
    })
    (map-set has-signed { tx-id: new-id, signer: tx-sender } true)
    (var-set tx-count new-id)
    (ok new-id)))

(define-public (sign-transaction (tx-id uint))
  (let (
    (tx (unwrap! (map-get? transactions tx-id) ERR_TX_NOT_FOUND))
    (new-sigs (+ (get signatures tx) u1))
  )
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (has-user-signed tx-id tx-sender)) ERR_ALREADY_SIGNED)
    (asserts! (not (get executed tx)) ERR_TX_ALREADY_EXECUTED)
    (asserts! (not (get cancelled tx)) ERR_TX_CANCELLED)
    (asserts! (not (is-tx-expired tx-id)) ERR_TX_EXPIRED)
    (map-set has-signed { tx-id: tx-id, signer: tx-sender } true)
    (map-set transactions tx-id (merge tx { signatures: new-sigs }))
    (ok new-sigs)))

(define-public (revoke-signature (tx-id uint))
  (let (
    (tx (unwrap! (map-get? transactions tx-id) ERR_TX_NOT_FOUND))
  )
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (has-user-signed tx-id tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (get executed tx)) ERR_TX_ALREADY_EXECUTED)
    (map-set has-signed { tx-id: tx-id, signer: tx-sender } false)
    (map-set transactions tx-id (merge tx { 
      signatures: (- (get signatures tx) u1)
    }))
    (ok true)))

(define-public (cancel-transaction (tx-id uint))
  (let (
    (tx (unwrap! (map-get? transactions tx-id) ERR_TX_NOT_FOUND))
  )
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (get executed tx)) ERR_TX_ALREADY_EXECUTED)
    ;; Only submitter or after expiry can cancel
    (map-set transactions tx-id (merge tx { cancelled: true }))
    (ok true)))

(define-public (execute-transaction (tx-id uint))
  (let ((tx (unwrap! (map-get? transactions tx-id) ERR_TX_NOT_FOUND)))
    (asserts! (>= (get signatures tx) (var-get required-signatures)) ERR_NOT_ENOUGH_SIGNATURES)
    (asserts! (not (get executed tx)) ERR_TX_ALREADY_EXECUTED)
    (asserts! (not (get cancelled tx)) ERR_TX_CANCELLED)
    (asserts! (not (is-tx-expired tx-id)) ERR_TX_EXPIRED)
    (try! (as-contract (stx-transfer? (get amount tx) tx-sender (get to tx))))
    (map-set transactions tx-id (merge tx { executed: true }))
    (var-set total-executed (+ (var-get total-executed) u1))
    (ok true)))

;; Owner management - requires multisig approval
(define-public (propose-add-owner (new-owner principal))
  (let ((proposal-id (+ (var-get tx-count) u1000000))) ;; Use high IDs for proposals
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-owner new-owner)) ERR_ALREADY_OWNER)
    (map-set owner-proposals proposal-id {
      action: "add",
      target: new-owner,
      signatures: u1,
      executed: false
    })
    (map-set owner-proposal-signed { proposal-id: proposal-id, signer: tx-sender } true)
    (ok proposal-id)))

(define-public (propose-remove-owner (target-owner principal))
  (let ((proposal-id (+ (var-get tx-count) u2000000)))
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-owner target-owner) ERR_NOT_OWNER)
    (asserts! (not (is-eq tx-sender target-owner)) ERR_CANNOT_REMOVE_SELF)
    (asserts! (> (var-get owner-count) u1) ERR_MIN_OWNERS)
    (map-set owner-proposals proposal-id {
      action: "remove",
      target: target-owner,
      signatures: u1,
      executed: false
    })
    (map-set owner-proposal-signed { proposal-id: proposal-id, signer: tx-sender } true)
    (ok proposal-id)))

(define-public (sign-owner-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? owner-proposals proposal-id) ERR_TX_NOT_FOUND))
  )
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (default-to false (map-get? owner-proposal-signed { proposal-id: proposal-id, signer: tx-sender }))) ERR_ALREADY_SIGNED)
    (map-set owner-proposal-signed { proposal-id: proposal-id, signer: tx-sender } true)
    (map-set owner-proposals proposal-id (merge proposal { 
      signatures: (+ (get signatures proposal) u1)
    }))
    (ok true)))

(define-public (execute-owner-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? owner-proposals proposal-id) ERR_TX_NOT_FOUND))
  )
    (asserts! (>= (get signatures proposal) (var-get required-signatures)) ERR_NOT_ENOUGH_SIGNATURES)
    (asserts! (not (get executed proposal)) ERR_TX_ALREADY_EXECUTED)
    (if (is-eq (get action proposal) "add")
      (begin
        (map-set owners (get target proposal) true)
        (var-set owner-count (+ (var-get owner-count) u1)))
      (begin
        (map-set owners (get target proposal) false)
        (var-set owner-count (- (var-get owner-count) u1))))
    (map-set owner-proposals proposal-id (merge proposal { executed: true }))
    (ok true)))

;; Deposit STX to wallet
(define-public (deposit (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender)))

;; Update required signatures (needs multisig approval)
(define-public (update-required-signatures (new-required uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-required (var-get owner-count)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-required u0) ERR_NOT_AUTHORIZED)
    (var-set required-signatures new-required)
    (ok true)))
