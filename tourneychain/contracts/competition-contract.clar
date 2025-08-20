;; Gaming Tournament System Contract
;; Tournament management with brackets, prizes, and rankings

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-tournament-full (err u103))
(define-constant err-tournament-started (err u104))
(define-constant err-registration-closed (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-already-registered (err u107))
(define-constant err-invalid-result (err u108))

;; Data Variables
(define-data-var next-tournament-id uint u1)
(define-data-var next-match-id uint u1)
(define-data-var platform-fee uint u500) ;; 5% platform fee (500/10000)
(define-data-var min-tournament-size uint u4)
(define-data-var max-tournament-size uint u32)

;; Tournament structure
(define-map tournaments 
  uint 
  {
    name: (string-ascii 64),
    game-type: (string-ascii 32), ;; "chess", "cards", "battle"
    organizer: principal,
    entry-fee: uint,
    max-participants: uint,
    current-participants: uint,
    prize-pool: uint,
    status: (string-ascii 16), ;; "registration", "active", "finished"
    registration-end: uint,
    tournament-start: uint,
    winner: (optional principal),
    current-round: uint,
    total-rounds: uint
  }
)

;; Participant registration
(define-map tournament-participants 
  {tournament-id: uint, participant: principal} 
  {
    registration-block: uint,
    seed: uint,
    current-score: uint,
    games-played: uint,
    eliminated: bool
  }
)

;; Tournament participant list
(define-map tournament-participant-lists 
  uint 
  {
    participants: (list 32 principal),
    participant-count: uint
  }
)

;; Match structure
(define-map tournament-matches 
  uint 
  {
    tournament-id: uint,
    round: uint,
    match-number: uint,
    player1: (optional principal),
    player2: (optional principal),
    winner: (optional principal),
    status: (string-ascii 16), ;; "waiting", "ready", "finished"
    start-block: uint,
    result-confirmed: bool
  }
)

;; Player tournament history
(define-map player-tournament-history 
  principal 
  {
    tournaments-entered: uint,
    tournaments-won: uint,
    total-prize-money: uint,
    current-elo: uint,
    total-matches: uint,
    total-wins: uint
  }
)

;; Create tournament
(define-public (create-tournament 
  (tournament-id uint)
  (name (string-ascii 64)) 
  (game-type (string-ascii 32)) 
  (entry-fee uint) 
  (max-participants uint) 
  (registration-duration uint)
)
  (let 
    (
      (current-block block-height)
      (registration-end (+ current-block registration-duration))
      (tournament-start (+ registration-end u144)) ;; 24 hour buffer
      (total-rounds (calculate-total-rounds max-participants))
    )
    
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= max-participants (var-get min-tournament-size)) 
                   (<= max-participants (var-get max-tournament-size))) err-invalid-result)
    (asserts! (> entry-fee u0) err-insufficient-funds)
    
    ;; Create tournament
    (map-set tournaments tournament-id
      {
        name: name,
        game-type: game-type,
        organizer: tx-sender,
        entry-fee: entry-fee,
        max-participants: max-participants,
        current-participants: u0,
        prize-pool: u0,
        status: "registration",
        registration-end: registration-end,
        tournament-start: tournament-start,
        winner: none,
        current-round: u0,
        total-rounds: total-rounds
      }
    )
    
    ;; Initialize participant list
    (map-set tournament-participant-lists tournament-id
      {
        participants: (list),
        participant-count: u0
      }
    )
    
    (var-set next-tournament-id (+ tournament-id u1))
    (ok tournament-id)
  )
)

;; Calculate total rounds for bracket
(define-private (calculate-total-rounds (max-participants uint))
  (if (<= max-participants u4) u2
    (if (<= max-participants u8) u3
      (if (<= max-participants u16) u4 u5)
    )
  )
)

;; Register for tournament
(define-public (register-for-tournament (tournament-id uint))
  (let 
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (participant-list (unwrap! (map-get? tournament-participant-lists tournament-id) err-not-found))
      (player-history (default-to 
                        {tournaments-entered: u0, tournaments-won: u0, total-prize-money: u0, current-elo: u1200, total-matches: u0, total-wins: u0}
                        (map-get? player-tournament-history tx-sender)))
    )
    
    ;; Validate registration conditions
    (asserts! (is-eq (get status tournament) "registration") err-registration-closed)
    (asserts! (<= block-height (get registration-end tournament)) err-registration-closed)
    (asserts! (is-none (map-get? tournament-participants {tournament-id: tournament-id, participant: tx-sender})) err-already-registered)
    (asserts! (< (get current-participants tournament) (get max-participants tournament)) err-tournament-full)
    
    ;; Transfer entry fee
    (try! (stx-transfer? (get entry-fee tournament) tx-sender (as-contract tx-sender)))
    
    ;; Register participant
    (map-set tournament-participants {tournament-id: tournament-id, participant: tx-sender}
      {
        registration-block: block-height,
        seed: (+ (get current-participants tournament) u1),
        current-score: u0,
        games-played: u0,
        eliminated: false
      }
    )
    
    ;; Update participant list
    (map-set tournament-participant-lists tournament-id
      (merge participant-list 
        {
          participants: (unwrap! (as-max-len? (append (get participants participant-list) tx-sender) u32) err-tournament-full),
          participant-count: (+ (get participant-count participant-list) u1)
        }
      )
    )
    
    ;; Update tournament
    (map-set tournaments tournament-id
      (merge tournament 
        {
          current-participants: (+ (get current-participants tournament) u1),
          prize-pool: (+ (get prize-pool tournament) (get entry-fee tournament))
        }
      )
    )
    
    ;; Update player history
    (map-set player-tournament-history tx-sender
      (merge player-history {tournaments-entered: (+ (get tournaments-entered player-history) u1)})
    )
    
    (ok true)
  )
)

;; Start tournament (organizer only) - simplified to avoid circular dependencies
(define-public (start-tournament (tournament-id uint))
  (let 
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (participant-list (unwrap! (map-get? tournament-participant-lists tournament-id) err-not-found))
    )
    
    (asserts! (is-eq tx-sender (get organizer tournament)) err-unauthorized)
    (asserts! (is-eq (get status tournament) "registration") err-tournament-started)
    (asserts! (>= (get current-participants tournament) (var-get min-tournament-size)) err-invalid-result)
    (asserts! (>= block-height (get tournament-start tournament)) err-registration-closed)
    
    ;; Update tournament status
    (map-set tournaments tournament-id
      (merge tournament 
        {
          status: "active",
          current-round: u1
        }
      )
    )
    
    (ok true)
  )
)

;; Create single match (separate function to avoid circular dependencies)
(define-public (create-match (tournament-id uint) (round uint) (match-number uint) (player1 principal) (player2 principal))
  (let 
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (match-id (var-get next-match-id))
    )
    
    (asserts! (is-eq tx-sender (get organizer tournament)) err-unauthorized)
    (asserts! (is-eq (get status tournament) "active") err-tournament-started)
    
    (map-set tournament-matches match-id
      {
        tournament-id: tournament-id,
        round: round,
        match-number: match-number,
        player1: (some player1),
        player2: (some player2),
        winner: none,
        status: "ready",
        start-block: block-height,
        result-confirmed: false
      }
    )
    
    (var-set next-match-id (+ match-id u1))
    (ok match-id)
  )
)

;; Submit match result
(define-public (submit-match-result (match-id uint) (winner principal))
  (let 
    (
      (match (unwrap! (map-get? tournament-matches match-id) err-not-found))
      (tournament (unwrap! (map-get? tournaments (get tournament-id match)) err-not-found))
      (player1 (get player1 match))
      (player2 (get player2 match))
    )
    
    ;; Validate result submission
    (asserts! (is-eq (get status tournament) "active") err-tournament-started)
    (asserts! (is-eq (get status match) "ready") err-invalid-result)
    (asserts! (or (is-eq (some tx-sender) player1) (is-eq (some tx-sender) player2)) err-unauthorized)
    (asserts! (or (is-eq (some winner) player1) (is-eq (some winner) player2)) err-invalid-result)
    
    (let 
      (
        (loser (if (is-eq (some winner) player1) (unwrap-panic player2) (unwrap-panic player1)))
      )
      
      ;; Update match
      (map-set tournament-matches match-id
        (merge match 
          {
            winner: (some winner),
            status: "finished",
            result-confirmed: true
          }
        )
      )
      
      ;; Update participant records
      (update-participant-stats (get tournament-id match) winner true)
      (update-participant-stats (get tournament-id match) loser false)
      
      (ok true)
    )
  )
)

;; Update participant statistics
(define-private (update-participant-stats (tournament-id uint) (participant principal) (won bool))
  (let 
    (
      (participant-data (unwrap-panic (map-get? tournament-participants {tournament-id: tournament-id, participant: participant})))
      (player-history (default-to 
                        {tournaments-entered: u0, tournaments-won: u0, total-prize-money: u0, current-elo: u1200, total-matches: u0, total-wins: u0}
                        (map-get? player-tournament-history participant)))
    )
    
    ;; Update tournament participant data
    (map-set tournament-participants {tournament-id: tournament-id, participant: participant}
      (merge participant-data 
        {
          current-score: (if won (+ (get current-score participant-data) u1) (get current-score participant-data)),
          games-played: (+ (get games-played participant-data) u1),
          eliminated: (not won)
        }
      )
    )
    
    ;; Update player history
    (map-set player-tournament-history participant
      (merge player-history 
        {
          total-matches: (+ (get total-matches player-history) u1),
          total-wins: (if won (+ (get total-wins player-history) u1) (get total-wins player-history)),
          current-elo: (if won (+ (get current-elo player-history) u20) 
                          (if (> (get current-elo player-history) u20) (- (get current-elo player-history) u20) u0))
        }
      )
    )
    true
  )
)

;; End tournament and distribute prizes
(define-public (end-tournament (tournament-id uint))
  (let 
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (total-pool (get prize-pool tournament))
      (platform-cut (/ (* total-pool (var-get platform-fee)) u10000))
      (remaining-pool (- total-pool platform-cut))
      (winner-prize (/ (* remaining-pool u70) u100)) ;; 70% to winner
    )
    
    (asserts! (is-eq tx-sender (get organizer tournament)) err-unauthorized)
    (asserts! (is-eq (get status tournament) "active") err-tournament-started)
    
    ;; Update tournament status
    (map-set tournaments tournament-id
      (merge tournament 
        {
          status: "finished",
          winner: (some tx-sender) ;; Simplified - organizer sets winner
        }
      )
    )
    
    ;; Distribute prizes (simplified)
    (try! (as-contract (stx-transfer? winner-prize tx-sender tx-sender)))
    (try! (as-contract (stx-transfer? platform-cut tx-sender contract-owner)))
    
    ;; Update winner statistics
    (update-winner-stats tx-sender winner-prize)
    
    (ok true)
  )
)

;; Update winner statistics
(define-private (update-winner-stats (winner principal) (prize-amount uint))
  (let 
    (
      (player-history (default-to 
                        {tournaments-entered: u0, tournaments-won: u0, total-prize-money: u0, current-elo: u1200, total-matches: u0, total-wins: u0}
                        (map-get? player-tournament-history winner)))
    )
    (map-set player-tournament-history winner
      (merge player-history 
        {
          tournaments-won: (+ (get tournaments-won player-history) u1),
          total-prize-money: (+ (get total-prize-money player-history) prize-amount)
        }
      )
    )
  )
)

;; Cancel tournament (organizer or admin only)
(define-public (cancel-tournament (tournament-id uint))
  (let 
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
    )
    (asserts! (or (is-eq tx-sender (get organizer tournament)) (is-eq tx-sender contract-owner)) err-unauthorized)
    (asserts! (not (is-eq (get status tournament) "finished")) err-tournament-started)
    
    ;; Update tournament status
    (map-set tournaments tournament-id
      (merge tournament {status: "cancelled"})
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-tournament (tournament-id uint))
  (map-get? tournaments tournament-id)
)

(define-read-only (get-tournament-participants (tournament-id uint))
  (map-get? tournament-participant-lists tournament-id)
)

(define-read-only (get-participant-info (tournament-id uint) (participant principal))
  (map-get? tournament-participants {tournament-id: tournament-id, participant: participant})
)

(define-read-only (get-match (match-id uint))
  (map-get? tournament-matches match-id)
)

(define-read-only (get-player-history (player principal))
  (map-get? player-tournament-history player)
)

(define-read-only (is-tournament-full (tournament-id uint))
  (match (map-get? tournaments tournament-id)
    tournament (>= (get current-participants tournament) (get max-participants tournament))
    false
  )
)

;; Admin functions
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-insufficient-funds) ;; Max 10%
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (set-tournament-size-limits (min-size uint) (max-size uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< min-size max-size) err-invalid-result)
    (var-set min-tournament-size min-size)
    (var-set max-tournament-size max-size)
    (ok true)
  )
)

(define-public (emergency-finish-tournament (tournament-id uint))
  (let 
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set tournaments tournament-id
      (merge tournament {status: "finished"})
    )
    (ok true)
  )
)