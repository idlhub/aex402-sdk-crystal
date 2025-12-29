# AeX402 Crystal SDK

Crystal SDK for the AeX402 Hybrid AMM on Solana. Supports stable pools (AeX402 curve), volatile pools (constant product), and virtual pool graduation system.

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  aex402:
    github: aldrin-labs/aex402-crystal
    version: ~> 0.1.0
```

Then run:

```bash
shards install
```

## Usage

### Basic Example

```crystal
require "aex402"

# Parse pool account data from Solana
pool = AeX402::Accounts.parse_pool(account_data)
if pool
  puts "Pool balances: #{pool.bal0} / #{pool.bal1}"
  puts "Amp: #{pool.amp}"
  puts "Fee: #{pool.fee_bps} bps"
end

# Simulate a swap
expected_out = AeX402::Math.simulate_swap(
  bal_in: pool.bal0,
  bal_out: pool.bal1,
  amount_in: 1_000_000_u64,
  amp: pool.amp,
  fee_bps: pool.fee_bps
)

puts "Expected output: #{expected_out}"

# Build swap instruction
ix = AeX402::Instructions.swap_t0_t1(
  pool: pool_address,
  vault0: pool.vault0.to_s,
  vault1: pool.vault1.to_s,
  user_token0: user_token0_address,
  user_token1: user_token1_address,
  user: user_address,
  args: AeX402::SwapSimpleArgs.new(
    amount_in: 1_000_000_u64,
    min_out: (expected_out.not_nil! * 99 // 100).to_u64
  )
)
```

### Account Parsing

```crystal
# Parse different account types
pool = AeX402::Accounts.parse_pool(data)
npool = AeX402::Accounts.parse_npool(data)
farm = AeX402::Accounts.parse_farm(data)
user_farm = AeX402::Accounts.parse_user_farm(data)
lottery = AeX402::Accounts.parse_lottery(data)

# Get account type from data
account_type = AeX402::Accounts.get_account_type(data)
case account_type
when :pool
  # Handle pool
when :farm
  # Handle farm
end
```

### Math Operations

```crystal
# Calculate invariant D
d = AeX402::Math.calc_d(balance0, balance1, amp)

# Calculate output amount
y = AeX402::Math.calc_y(new_balance_in, d, amp)

# Simulate swap with fees
output = AeX402::Math.simulate_swap(
  bal_in: 1_000_000_u64,
  bal_out: 1_000_000_u64,
  amount_in: 100_000_u64,
  amp: 100_u64,
  fee_bps: 30_u64
)

# Calculate LP tokens for deposit
lp_tokens = AeX402::Math.calc_lp_tokens(
  amt0: deposit0,
  amt1: deposit1,
  bal0: current_bal0,
  bal1: current_bal1,
  lp_supply: current_supply,
  amp: amp
)

# Get current amp during ramping
current_amp = AeX402::Math.get_current_amp(
  amp: pool.amp,
  target_amp: pool.target_amp,
  ramp_start: pool.ramp_start,
  ramp_end: pool.ramp_stop,
  now: Time.utc.to_unix
)

# Calculate price impact
impact = AeX402::Math.calc_price_impact(bal_in, bal_out, amount_in, amp, fee_bps)

# Calculate virtual price
virtual_price = AeX402::Math.calc_virtual_price(bal0, bal1, lp_supply, amp)
```

### Instruction Building

```crystal
# Create pool
ix = AeX402::Instructions.create_pool(
  pool: pool_address,
  mint0: mint0_address,
  mint1: mint1_address,
  authority: authority_address,
  args: AeX402::CreatePoolArgs.new(amp: 100_u64, bump: bump)
)

# Add liquidity
ix = AeX402::Instructions.add_liquidity(
  pool: pool_address,
  vault0: vault0,
  vault1: vault1,
  lp_mint: lp_mint,
  user_token0: user_t0,
  user_token1: user_t1,
  user_lp: user_lp,
  user: user_address,
  args: AeX402::AddLiqArgs.new(
    amount0: 1_000_000_u64,
    amount1: 1_000_000_u64,
    min_lp: 900_000_u64
  )
)

# Remove liquidity
ix = AeX402::Instructions.remove_liquidity(...)

# Stake LP tokens
ix = AeX402::Instructions.stake_lp(
  user_position: position,
  farm: farm_address,
  user_lp: user_lp,
  lp_vault: lp_vault,
  user: user_address,
  args: AeX402::StakeArgs.new(amount: 1_000_000_u64)
)
```

### PDA Derivation

```crystal
# Derive pool PDA
result = AeX402::PDA.derive_pool_pda(mint0, mint1)
if result
  pool_address = result.address
  bump = result.bump
end

# Derive farm PDA
result = AeX402::PDA.derive_farm_pda(pool_address)

# Derive user farm position
result = AeX402::PDA.derive_user_farm_pda(farm_address, user_address)

# Derive lottery PDAs
lottery = AeX402::PDA.derive_lottery_pda(pool_address)
entry = AeX402::PDA.derive_lottery_entry_pda(lottery_address, user_address)
```

### Virtual Pool System

```crystal
# Parse global header
header = AeX402::VPool::Accounts.parse_global_header(data)

# Parse a virtual pool slot
slot = AeX402::VPool::Accounts.parse_vpool_slot(data, slot_index)

# Calculate current price on bonding curve
price = AeX402::VPool::Math.calc_price(
  tokens_sold: slot.tokens_sold,
  base_price: slot.base_price,
  slope: slot.slope
)

# Simulate buy
simulation = AeX402::VPool::Math.calc_buy(
  sol_in: BigInt.new("1000000000"),  # 1 SOL
  tokens_sold: slot.tokens_sold,
  base_price: slot.base_price,
  slope: slot.slope
)

if simulation
  puts "Tokens out: #{simulation.tokens_out}"
  puts "New price: #{simulation.new_price}"
  puts "Price impact: #{simulation.price_impact}%"
end

# Check graduation status
can_graduate = AeX402::VPool.can_graduate?(slot)
progress = AeX402::VPool.graduation_progress(slot)

# Get pool statistics
stats = AeX402::VPool.stats(slot, Time.utc.to_unix)
```

## Module Structure

- `AeX402::Constants` - Program ID, discriminators, pool constants
- `AeX402::Errors` - Error codes and messages
- `AeX402::Types` - Data structures (Pool, NPool, Farm, etc.)
- `AeX402::Accounts` - Account parsing functions
- `AeX402::Instructions` - Instruction builders
- `AeX402::Math` - StableSwap math (Newton's method)
- `AeX402::PDA` - PDA derivation utilities
- `AeX402::VPool` - Virtual pool graduation system
  - `AeX402::VPool::Constants`
  - `AeX402::VPool::Types`
  - `AeX402::VPool::Accounts`
  - `AeX402::VPool::Instructions`
  - `AeX402::VPool::Math`

## Constants

```crystal
# Program ID
AeX402::PROGRAM_ID  # => "3AMM53MsJZy2Jvf7PeHHga3bsGjWV4TSaYz29WUtcdje"

# Pool constraints
AeX402::MIN_AMP            # => 1
AeX402::MAX_AMP            # => 100_000
AeX402::DEFAULT_FEE_BPS    # => 30 (0.3%)
AeX402::NEWTON_ITERATIONS  # => 255
AeX402::MAX_TOKENS         # => 8

# Account sizes
AeX402::POOL_SIZE   # => 1024 bytes
AeX402::NPOOL_SIZE  # => 2048 bytes
```

## Error Handling

```crystal
begin
  # ... operation
rescue ex : AeX402::AeX402Error
  puts "Error code: #{ex.code}"
  puts "Message: #{ex.message}"
rescue ex : AeX402::ParseError
  puts "Failed to parse account: #{ex.message}"
rescue ex : AeX402::MathError
  puts "Math computation failed: #{ex.message}"
end
```

## Development

```bash
# Run tests
crystal spec

# Format code
crystal tool format

# Build documentation
crystal docs
```

## License

MIT
