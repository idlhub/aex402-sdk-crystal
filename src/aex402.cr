# AeX402 SDK - Hybrid StableSwap AMM with Virtual Pools on Solana
#
# Crystal SDK for interacting with the AeX402 AMM program.
# Supports both stable pools (AeX402 curve) and volatile pools (constant product).

require "./aex402/version"
require "./aex402/constants"
require "./aex402/errors"
require "./aex402/types"
require "./aex402/accounts"
require "./aex402/instructions"
require "./aex402/math"
require "./aex402/pda"
require "./aex402/vpool"

# AeX402 Hybrid AMM SDK
#
# This module provides a complete interface for interacting with the AeX402
# AMM program on Solana, including:
#
# - Pool creation and management
# - Swaps (2-token and N-token)
# - Liquidity operations
# - Farming and staking
# - Lottery system
# - Virtual pool graduation
# - On-chain analytics
#
# Example usage:
# ```crystal
# require "aex402"
#
# # Parse pool account data
# pool = AeX402::Accounts.parse_pool(data)
# puts "Pool balance 0: #{pool.bal0}"
#
# # Simulate a swap
# out = AeX402::Math.simulate_swap(
#   bal_in: pool.bal0,
#   bal_out: pool.bal1,
#   amount_in: 1_000_000_u64,
#   amp: pool.amp,
#   fee_bps: pool.fee_bps
# )
# puts "Expected output: #{out}"
#
# # Build swap instruction
# ix = AeX402::Instructions.swap_t0_t1(
#   pool: pool_pubkey,
#   vault0: pool.vault0,
#   vault1: pool.vault1,
#   user_token0: user_t0,
#   user_token1: user_t1,
#   user: user_pubkey,
#   amount_in: 1_000_000_u64,
#   min_out: out - (out / 100)
# )
# ```
module AeX402
  # VERSION is defined in ./aex402/version.cr
end
