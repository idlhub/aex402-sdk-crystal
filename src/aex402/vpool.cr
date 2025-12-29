# Virtual Pool module for graduation system
require "./vpool/constants"
require "./vpool/types"
require "./vpool/accounts"
require "./vpool/instructions"
require "./vpool/math"

module AeX402
  # ============================================================================
  # Virtual Pool (VPool) Module
  #
  # Implements zero-rent token launches with bonding curves that graduate
  # to real AMM pools when reaching certain thresholds.
  # ============================================================================

  module VPool
    # Re-export for convenience
    extend self

    # Calculate current price for a virtual pool
    def current_price(slot : VPoolSlot) : BigInt
      Math.calc_price(slot.tokens_sold, slot.base_price, slot.slope)
    end

    # Calculate graduation target for a virtual pool
    def graduation_target(slot : VPoolSlot) : BigInt
      Math.calc_graduation_target(
        slot.total_buy_sol,
        slot.total_sell_sol
      )
    end

    # Check if a virtual pool can graduate
    def can_graduate?(slot : VPoolSlot) : Bool
      return false unless slot.status.active?

      target = graduation_target(slot)
      slot.sol_raised >= target
    end

    # Calculate progress to graduation (0-100%)
    def graduation_progress(slot : VPoolSlot) : Float64
      target = graduation_target(slot)
      return 100.0 if target.zero?

      progress = slot.sol_raised.to_f64 / target.to_f64 * 100.0
      {progress, 100.0}.min
    end

    # Get pool statistics
    def stats(slot : VPoolSlot, now : Int64) : VPoolStats
      target = graduation_target(slot)
      current = current_price(slot)
      market_cap = current * slot.tokens_sold // SCALE

      churn = if slot.total_buy_sol.zero?
               0.0
             else
               slot.total_sell_sol.to_f64 / slot.total_buy_sol.to_f64
             end

      age = now - slot.created_at
      stale = age > VPOOL_FLUSH_SECS && !slot.status.graduated?

      VPoolStats.new(
        current_price: current,
        market_cap_sol: market_cap,
        graduation_progress: graduation_progress(slot),
        can_graduate: can_graduate?(slot),
        graduation_target: target,
        churn_ratio: churn,
        age_seconds: age,
        is_stale: stale
      )
    end
  end
end
