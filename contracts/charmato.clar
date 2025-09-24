;; title: charity-matching-token
;; version: 1.0
;; summary: A token system that matches user donations based on token holdings
;; TODO: Implement NFT trait when trait system is properly configured
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u1001))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1002))
(define-constant ERR-INVALID-CAUSE (err u1003))
;; Data variables
(define-data-var token-uri (string-utf8 256) u"")
(define-data-var contract-owner principal tx-sender)
(define-data-var matching-pool uint u0)
(define-data-var total-supply uint u0)
;; Data maps
(define-map token-balances principal uint)
(define-map approved-causes (string-ascii 64) bool)
(define-map donation-history
{ donor: principal, cause: (string-ascii 64) }
{ amount: uint, matched: uint })
;; SIP-009 NFT Required Functions
(define-read-only (get-last-token-id)
(ok (var-get total-supply)))
(define-read-only (get-token-uri (token-id uint))
(ok (some (var-get token-uri))))
(define-read-only (get-owner (token-id uint))
(ok (some tx-sender)))
;; Core token transfer function
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
(let ((current-balance (default-to u0 (map-get? token-balances sender))))
(begin
(asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
(asserts! (>= current-balance u1) ERR-INSUFFICIENT-BALANCE)
(map-set token-balances sender
(- current-balance u1))
(map-set token-balances recipient
(+ (default-to u0 (map-get? token-balances recipient)) u1))
(ok true))))
;; Register approved charitable cause
(define-public (register-cause (cause-id (string-ascii 64)))
(begin
(asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
(map-set approved-causes cause-id true)
(ok true)))

;; Make donation with matching
(define-public (donate (cause-id (string-ascii 64)) (amount uint))
(let (
(user-balance (default-to u0 (map-get? token-balances tx-sender)))
(cause-valid (default-to false (map-get? approved-causes cause-id)))
(matching-amount (calculate-match amount user-balance))
)
(asserts! cause-valid ERR-INVALID-CAUSE)
(asserts! (> amount u0) ERR-INVALID-AMOUNT)
;; Record donation and matching
(map-set donation-history
{ donor: tx-sender, cause: cause-id }
{ amount: amount, matched: matching-amount })
;; Update matching pool
(var-set matching-pool (- (var-get matching-pool) matching-amount))
(ok { donated: amount, matched: matching-amount })))
;; Internal function to calculate matching amount
(define-private (calculate-match (donation uint) (token-balance uint))
(let (
   (match-ratio (/ token-balance u1000)) ;; 0.1% match per token held
   (potential-match (* donation match-ratio))
   (available-pool (var-get matching-pool))
)
(if (> potential-match available-pool)
available-pool
potential-match)))
;; Mint new tokens
(define-public (mint (recipient principal))
(begin
(asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
(var-set total-supply (+ (var-get total-supply) u1))
(map-set token-balances recipient
(+ (default-to u0 (map-get? token-balances recipient)) u1))
(ok (var-get total-supply))))
;; Add funds to matching pool
(define-public (fund-matching-pool (amount uint))
(begin
(asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
(var-set matching-pool (+ (var-get matching-pool) amount))
(ok true)))
;; Read-only functions
(define-read-only (get-balance (account principal))
(ok (default-to u0 (map-get? token-balances account))))
(define-read-only (get-donation-history (donor principal) (cause-id (string-ascii 64)))
(ok (map-get? donation-history { donor: donor, cause: cause-id })))
(define-read-only (get-matching-pool)
(ok (var-get matching-pool)))
(define-read-only (is-cause-approved (cause-id (string-ascii 64)))
(ok (default-to false (map-get? approved-causes cause-id))))