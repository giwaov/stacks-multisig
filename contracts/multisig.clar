;; Multisig Wallet Contract - Multi-signature transactions
;; Built with @stacks/transactions

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_SIGNED (err u101))
(define-constant ERR_NOT_ENOUGH_SIGNATURES (err u102))
(define-constant ERR_TX_NOT_FOUND (err u103))

;; Data vars
(define-data-var tx-count uint u0)
(define-data-var required-signatures uint u2)
(define-data-var owner-count uint u3)

;; Maps
(define-map owners principal bool)
(define-map transactions uint {
  to: principal,
  amount: uint,
  signatures: uint,
  executed: bool
})
(define-map has-signed { tx-id: uint, signer: principal } bool)

;; Initialize owners
(map-set owners tx-sender true)

;; Read-only functions
(define-read-only (get-tx-count)
  (var-get tx-count))

(define-read-only (get-required-signatures)
  (var-get required-signatures))

(define-read-only (is-owner (user principal))
  (default-to false (map-get? owners user)))

(define-read-only (get-transaction (id uint))
  (map-get? transactions id))

(define-read-only (has-user-signed (tx-id uint) (signer principal))
  (default-to false (map-get? has-signed { tx-id: tx-id, signer: signer })))

;; Public functions
(define-public (submit-transaction (to principal) (amount uint))
  (let ((new-id (+ (var-get tx-count) u1)))
    (asserts! (is-owner tx-sender) ERR_NOT_AUTHORIZED)
    (map-set transactions new-id {
      to: to,
      amount: amount,
      signatures: u1,
      executed: false
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
    (map-set has-signed { tx-id: tx-id, signer: tx-sender } true)
    (map-set transactions tx-id (merge tx { signatures: new-sigs }))
    (ok new-sigs)))

(define-public (execute-transaction (tx-id uint))
  (let ((tx (unwrap! (map-get? transactions tx-id) ERR_TX_NOT_FOUND)))
    (asserts! (>= (get signatures tx) (var-get required-signatures)) ERR_NOT_ENOUGH_SIGNATURES)
    (try! (as-contract (stx-transfer? (get amount tx) tx-sender (get to tx))))
    (map-set transactions tx-id (merge tx { executed: true }))
    (ok true)))
