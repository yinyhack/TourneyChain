# Gaming Tournament System

A comprehensive smart contract for managing competitive gaming tournaments on the Stacks blockchain. This system supports multiple tournament formats, automated bracket management, prize distribution, and player rankings.

## Features

### 🏆 Tournament Management
- **Multiple Tournament Types**: Single-elimination, double-elimination, and round-robin formats
- **Flexible Bracket Sizes**: Support for 4 to 64 participants with automatic bracket sizing
- **Game Type Support**: Chess, cards, battle games, puzzles, and more
- **Automated Prize Distribution**: Configurable prize pools with platform fees

### 🎮 Player Experience
- **Easy Registration**: Simple tournament registration with entry fee payment
- **Real-time Bracket Updates**: Live tournament brackets and match results
- **Player Statistics**: Comprehensive tracking of wins, losses, and ELO ratings
- **Tournament History**: Complete record of all tournament participation
- **Dispute System**: Built-in mechanism for contesting match results

### 💰 Prize System
- **Flexible Prize Distribution**: Customizable percentage splits for winners
- **Automatic Payouts**: Smart contract handles all prize distributions
- **Platform Fees**: Built-in revenue model with configurable platform fees
- **Refund System**: Automatic refunds for cancelled tournaments

## Tournament Lifecycle

### 1. Tournament Creation
Organizers can create tournaments by specifying:
- Tournament name and game type
- Entry fee and maximum participants
- Tournament format (single/double elimination, round-robin)
- Registration and tournament duration

### 2. Registration Phase
- Players register by paying the entry fee
- Automatic seeding based on registration order
- Waiting list support for full tournaments
- Registration deadline enforcement

### 3. Tournament Execution
- Automated bracket generation
- Round-by-round match creation
- Player-submitted match results
- Automatic advancement to next rounds

### 4. Prize Distribution
- Automatic calculation based on prize distribution settings
- Immediate payout to winners
- Platform fee collection
- Tournament completion

## Smart Contract Functions

### Core Functions

#### `create-tournament`
```clarity
(create-tournament name game-type entry-fee max-participants tournament-type registration-duration tournament-duration)
```
Creates a new tournament with specified parameters.

#### `register-for-tournament`
```clarity
(register-for-tournament tournament-id)
```
Registers a player for a tournament by paying the entry fee.

#### `start-tournament`
```clarity
(start-tournament tournament-id)
```
Initiates the tournament (organizer only) and creates the first round matches.

#### `submit-match-result`
```clarity
(submit-match-result match-id winner)
```
Submits the result of a match (players only).

### Administrative Functions

#### `cancel-tournament`
```clarity
(cancel-tournament tournament-id reason)
```
Cancels a tournament and refunds all participants.

#### `raise-match-dispute`
```clarity
(raise-match-dispute match-id reason)
```
Raises a dispute for a match result.

#### `resolve-dispute`
```clarity
(resolve-dispute match-id resolution new-winner)
```
Resolves a match dispute (admin only).

### Query Functions

#### `get-tournament`
```clarity
(get-tournament tournament-id)
```
Returns complete tournament information.

#### `get-player-history`
```clarity
(get-player-history player)
```
Returns a player's complete tournament history and statistics.

#### `get-match`
```clarity
(get-match match-id)
```
Returns match details including players and results.

## Data Structures

### Tournament Structure
- Basic tournament information (name, game type, organizer)
- Participant limits and current registration count
- Prize pool and distribution settings
- Tournament timeline and status
- Bracket configuration and current round

### Player Statistics
- Tournament participation history
- Win/loss records and ELO ratings
- Prize money earned
- Achievement tracking (tournaments won, runner-up, third place)

### Match System
- Player matchups and results
- Game-specific data storage
- Dispute tracking and resolution
- Round and bracket position management

## Tournament Types

### Single Elimination
- Players are eliminated after one loss
- Bracket size automatically calculated as next power of 2
- Fast tournament completion
- Winner-takes-all or tiered prize distribution

### Double Elimination
- Players must lose twice to be eliminated
- More complex bracket with winner's and loser's brackets
- Gives players a second chance
- Longer tournament duration

### Round Robin
- Every player plays every other player
- Points-based scoring system
- Best for smaller tournaments
- Most comprehensive results

## Game Types Supported

- **Chess**: Turn-based strategy games
- **Cards**: Poker, blackjack, and other card games
- **Battle**: Real-time combat games
- **Puzzle**: Logic and puzzle games
- **Custom**: Extensible for additional game types

## Prize Distribution

Default prize distribution (customizable):
- **1st Place**: 50% of prize pool
- **2nd Place**: 30% of prize pool
- **3rd Place**: 15% of prize pool
- **Platform Fee**: 5% of prize pool

## Error Codes

- `u100`: Owner-only function called by non-owner
- `u101`: Tournament or match not found
- `u102`: Unauthorized access
- `u103`: Tournament full
- `u104`: Tournament already started
- `u105`: Registration closed
- `u106`: Insufficient funds
- `u107`: Invalid bracket configuration
- `u108`: Match not ready
- `u109`: Already registered
- `u110`: Invalid result

## Security Features

- **Access Control**: Function-level permissions for organizers and admins
- **Validation**: Comprehensive input validation and state checking
- **Dispute Resolution**: Built-in system for handling contested results
- **Emergency Controls**: Admin functions for handling edge cases
- **Automatic Refunds**: Safe handling of cancelled tournaments

## Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Basic understanding of smart contract interactions

### Deployment
1. Deploy the contract to Stacks blockchain
2. Configure platform fees and tournament size limits
3. Begin creating tournaments

### Creating Your First Tournament
```clarity
(contract-call? .tournament-system create-tournament 
  "Chess Masters Cup" 
  "chess" 
  u1000000 ;; 1 STX entry fee
  u16      ;; 16 players max
  "single-elimination"
  u1440    ;; 24 hours registration
  u4320    ;; 72 hours tournament duration
)
```

### Registering for a Tournament
```clarity
(contract-call? .tournament-system register-for-tournament u1)
```

## Use Cases

- **Esports Tournaments**: Organize competitive gaming events
- **Chess Clubs**: Manage chess tournaments and ratings
- **Card Game Competitions**: Poker tournaments with automated payouts
- **Community Gaming**: Local gaming community tournaments
- **Professional Gaming**: Large-scale competitive events

## Future Enhancements

- **Multi-game Tournaments**: Tournaments spanning multiple games
- **Team Tournaments**: Support for team-based competitions
- **Streaming Integration**: Live tournament streaming features
- **NFT Prizes**: Support for NFT rewards
- **Cross-chain Compatibility**: Integration with other blockchains

## Contributing

This project is open for contributions. Areas of interest include:
- Additional tournament formats
- Enhanced dispute resolution
- UI/UX improvements
- Performance optimizations
- Security enhancements

## Support

For technical support, bug reports, or feature requests, please refer to the project documentation or community forums.
