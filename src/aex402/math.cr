require "big"

module AeX402
  # ============================================================================
  # StableSwap Math Module
  #
  # All calculations use BigInt for precision.
  # Implements Newton's method for invariant D and output Y calculations.
  # ============================================================================

  module Math
    extend self

    # FEE_DENOMINATOR = 10000 (basis points)
    FEE_DENOMINATOR = BigInt.new(10000)

    # ========================================================================
    # Invariant D Calculation (2-token pool)
    #
    # Uses Newton's method iteration to find D such that:
    #   A * n^n * sum(x_i) + D = A * n^n * D + D^(n+1) / (n^n * prod(x_i))
    #
    # For n=2:
    #   A * 4 * (x + y) + D = A * 4 * D + D^3 / (4 * x * y)
    # ========================================================================

    def calc_d(x : UInt64, y : UInt64, amp : UInt64) : BigInt?
      calc_d(BigInt.new(x), BigInt.new(y), BigInt.new(amp))
    end

    def calc_d(x : BigInt, y : BigInt, amp : BigInt) : BigInt?
      s = x + y
      return BigInt.new(0) if s.zero?

      d = s
      ann = amp * 4 # A * n^n where n=2

      NEWTON_ITERATIONS.times do
        # d_p = d^3 / (4 * x * y)
        d_p = d * d // (x * 2)
        d_p = d_p * d // (y * 2)

        d_prev = d

        # d = (ann * s + d_p * 2) * d / ((ann - 1) * d + 3 * d_p)
        num = (ann * s + d_p * 2) * d
        denom = (ann - 1) * d + d_p * 3
        d = num // denom

        # Check convergence
        diff = d > d_prev ? d - d_prev : d_prev - d
        return d if diff <= 1
      end

      nil # Failed to converge
    end

    # ========================================================================
    # Output Y Calculation (2-token pool)
    #
    # Given new balance x_new and invariant D, find y such that:
    #   A * n^n * sum + D = A * n^n * D + D^(n+1) / (n^n * prod)
    # ========================================================================

    def calc_y(x_new : UInt64, d : BigInt, amp : UInt64) : BigInt?
      calc_y(BigInt.new(x_new), d, BigInt.new(amp))
    end

    def calc_y(x_new : BigInt, d : BigInt, amp : BigInt) : BigInt?
      ann = amp * 4

      # c = d^3 / (4 * x_new * ann)
      c = d * d // (x_new * 2)
      c = c * d // (ann * 2)

      # b = x_new + d / ann
      b = x_new + d // ann

      y = d

      NEWTON_ITERATIONS.times do
        y_prev = y

        # y = (y^2 + c) / (2y + b - d)
        num = y * y + c
        denom = y * 2 + b - d
        y = num // denom

        # Check convergence
        diff = y > y_prev ? y - y_prev : y_prev - y
        return y if diff <= 1
      end

      nil # Failed to converge
    end

    # ========================================================================
    # Simulate Swap
    #
    # Returns the output amount after fees for a given input amount.
    # ========================================================================

    def simulate_swap(
      bal_in : UInt64,
      bal_out : UInt64,
      amount_in : UInt64,
      amp : UInt64,
      fee_bps : UInt64
    ) : BigInt?
      simulate_swap(
        BigInt.new(bal_in),
        BigInt.new(bal_out),
        BigInt.new(amount_in),
        BigInt.new(amp),
        BigInt.new(fee_bps)
      )
    end

    def simulate_swap(
      bal_in : BigInt,
      bal_out : BigInt,
      amount_in : BigInt,
      amp : BigInt,
      fee_bps : BigInt
    ) : BigInt?
      d = calc_d(bal_in, bal_out, amp)
      return nil unless d

      new_bal_in = bal_in + amount_in
      new_bal_out = calc_y(new_bal_in, d, amp)
      return nil unless new_bal_out

      amount_out = bal_out - new_bal_out

      # Apply fee
      fee = amount_out * fee_bps // FEE_DENOMINATOR
      amount_out - fee
    end

    # ========================================================================
    # Calculate LP Tokens for Deposit (2-token pool)
    # ========================================================================

    def calc_lp_tokens(
      amt0 : UInt64,
      amt1 : UInt64,
      bal0 : UInt64,
      bal1 : UInt64,
      lp_supply : UInt64,
      amp : UInt64
    ) : BigInt?
      calc_lp_tokens(
        BigInt.new(amt0),
        BigInt.new(amt1),
        BigInt.new(bal0),
        BigInt.new(bal1),
        BigInt.new(lp_supply),
        BigInt.new(amp)
      )
    end

    def calc_lp_tokens(
      amt0 : BigInt,
      amt1 : BigInt,
      bal0 : BigInt,
      bal1 : BigInt,
      lp_supply : BigInt,
      amp : BigInt
    ) : BigInt?
      if lp_supply.zero?
        # Initial deposit: LP = sqrt(amt0 * amt1)
        product = amt0 * amt1
        return sqrt(product)
      end

      d0 = calc_d(bal0, bal1, amp)
      d1 = calc_d(bal0 + amt0, bal1 + amt1, amp)

      return nil unless d0 && d1
      return nil if d0.zero?

      # LP tokens = lp_supply * (d1 - d0) / d0
      lp_supply * (d1 - d0) // d0
    end

    # ========================================================================
    # Calculate Tokens for LP Burn
    # ========================================================================

    struct WithdrawResult
      property amount0 : BigInt
      property amount1 : BigInt

      def initialize(@amount0, @amount1)
      end
    end

    def calc_withdraw(
      lp_amount : UInt64,
      bal0 : UInt64,
      bal1 : UInt64,
      lp_supply : UInt64
    ) : WithdrawResult?
      calc_withdraw(
        BigInt.new(lp_amount),
        BigInt.new(bal0),
        BigInt.new(bal1),
        BigInt.new(lp_supply)
      )
    end

    def calc_withdraw(
      lp_amount : BigInt,
      bal0 : BigInt,
      bal1 : BigInt,
      lp_supply : BigInt
    ) : WithdrawResult?
      return nil if lp_supply.zero?

      amount0 = bal0 * lp_amount // lp_supply
      amount1 = bal1 * lp_amount // lp_supply

      WithdrawResult.new(amount0, amount1)
    end

    # ========================================================================
    # Current Amp During Ramping
    # ========================================================================

    def get_current_amp(
      amp : UInt64,
      target_amp : UInt64,
      ramp_start : Int64,
      ramp_end : Int64,
      now : Int64
    ) : UInt64
      get_current_amp(
        BigInt.new(amp),
        BigInt.new(target_amp),
        BigInt.new(ramp_start),
        BigInt.new(ramp_end),
        BigInt.new(now)
      ).to_u64
    end

    def get_current_amp(
      amp : BigInt,
      target_amp : BigInt,
      ramp_start : BigInt,
      ramp_end : BigInt,
      now : BigInt
    ) : BigInt
      return target_amp if now >= ramp_end || ramp_end == ramp_start
      return amp if now <= ramp_start

      elapsed = now - ramp_start
      duration = ramp_end - ramp_start

      if target_amp > amp
        diff = target_amp - amp
        amp + diff * elapsed // duration
      else
        diff = amp - target_amp
        amp - diff * elapsed // duration
      end
    end

    # ========================================================================
    # Price Impact Calculation
    # ========================================================================

    def calc_price_impact(
      bal_in : UInt64,
      bal_out : UInt64,
      amount_in : UInt64,
      amp : UInt64,
      fee_bps : UInt64
    ) : Float64?
      amount_out = simulate_swap(bal_in, bal_out, amount_in, amp, fee_bps)
      return nil unless amount_out

      # Price impact = 1 - (amount_out / amount_in)
      ratio = amount_out.to_f64 / amount_in.to_f64
      1.0 - ratio
    end

    # ========================================================================
    # Slippage Tolerance
    # ========================================================================

    def calc_min_output(expected : UInt64, slippage_bps : UInt32) : UInt64
      calc_min_output(BigInt.new(expected), BigInt.new(slippage_bps)).to_u64
    end

    def calc_min_output(expected : BigInt, slippage_bps : BigInt) : BigInt
      expected * (FEE_DENOMINATOR - slippage_bps) // FEE_DENOMINATOR
    end

    # ========================================================================
    # Virtual Price (LP value relative to underlying)
    # ========================================================================

    def calc_virtual_price(
      bal0 : UInt64,
      bal1 : UInt64,
      lp_supply : UInt64,
      amp : UInt64
    ) : BigInt?
      calc_virtual_price(
        BigInt.new(bal0),
        BigInt.new(bal1),
        BigInt.new(lp_supply),
        BigInt.new(amp)
      )
    end

    def calc_virtual_price(
      bal0 : BigInt,
      bal1 : BigInt,
      lp_supply : BigInt,
      amp : BigInt
    ) : BigInt?
      return nil if lp_supply.zero?

      d = calc_d(bal0, bal1, amp)
      return nil unless d

      # Virtual price = D * 1e18 / lp_supply
      precision = BigInt.new(10) ** 18
      d * precision // lp_supply
    end

    # ========================================================================
    # Imbalance Check
    # ========================================================================

    def check_imbalance(
      bal0 : UInt64,
      bal1 : UInt64,
      max_ratio : Float64 = 10.0
    ) : Bool
      return false if bal0 == 0 || bal1 == 0

      ratio = if bal0 > bal1
                bal0.to_f64 / bal1.to_f64
              else
                bal1.to_f64 / bal0.to_f64
              end

      ratio <= max_ratio
    end

    # ========================================================================
    # N-Pool Math (2-8 tokens)
    # ========================================================================

    def calc_d_n(balances : Array(UInt64), amp : UInt64) : BigInt?
      calc_d_n(balances.map { |b| BigInt.new(b) }, BigInt.new(amp))
    end

    def calc_d_n(balances : Array(BigInt), amp : BigInt) : BigInt?
      n = balances.size
      return nil if n < 2 || n > MAX_TOKENS

      s = balances.sum
      return BigInt.new(0) if s.zero?

      d = s
      ann = amp * (n ** n) # A * n^n

      NEWTON_ITERATIONS.times do
        # d_p = d^(n+1) / (n^n * prod(balances))
        d_p = d
        balances.each do |bal|
          d_p = d_p * d // (bal * n)
        end

        d_prev = d

        # d = (ann * s + d_p * n) * d / ((ann - 1) * d + (n + 1) * d_p)
        num = (ann * s + d_p * n) * d
        denom = (ann - 1) * d + d_p * (n + 1)
        d = num // denom

        diff = d > d_prev ? d - d_prev : d_prev - d
        return d if diff <= 1
      end

      nil
    end

    def calc_y_n(
      balances : Array(BigInt),
      out_idx : Int32,
      d : BigInt,
      amp : BigInt
    ) : BigInt?
      n = balances.size
      return nil if n < 2 || n > MAX_TOKENS
      return nil if out_idx < 0 || out_idx >= n

      ann = amp * (n ** n)

      # Sum of all balances except the output
      s_without = BigInt.new(0)
      # Product of all balances except the output
      prod_without = d
      balances.each_with_index do |bal, i|
        next if i == out_idx
        s_without += bal
        prod_without = prod_without * d // (bal * n)
      end

      # c = d^(n+1) / (ann * prod_without)
      c = prod_without * d // (ann * n)

      # b = s_without + d / ann
      b = s_without + d // ann

      y = d

      NEWTON_ITERATIONS.times do
        y_prev = y

        num = y * y + c
        denom = y * 2 + b - d
        y = num // denom

        diff = y > y_prev ? y - y_prev : y_prev - y
        return y if diff <= 1
      end

      nil
    end

    # ========================================================================
    # Integer Square Root (Newton's method)
    # ========================================================================

    def sqrt(n : BigInt) : BigInt
      return BigInt.new(0) if n.zero?
      return BigInt.new(1) if n <= 3

      x = n
      y = (x + 1) // 2

      while y < x
        x = y
        y = (x + n // x) // 2
      end

      x
    end
  end
end
