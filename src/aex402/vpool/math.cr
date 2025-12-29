module AeX402
  module VPool
    # ==========================================================================
    # Virtual Pool Bonding Curve Math
    #
    # Implements quadratic bonding curve:
    #   price(t) = base_price + slope * tokens_sold / SCALE
    #
    # Buy: Solve quadratic for tokens received given SOL input
    # Sell: Integral of price curve for SOL output
    # ==========================================================================

    module Math
      extend self

      # ========================================================================
      # Price Calculation
      #
      # price(t) = base_price + slope * t / SCALE
      # where t = tokens_sold
      # ========================================================================

      def calc_price(tokens_sold : BigInt, base_price : BigInt, slope : BigInt) : BigInt
        base_price + slope * tokens_sold // SCALE
      end

      # ========================================================================
      # Buy Calculation
      #
      # Given SOL input, calculate tokens received.
      #
      # The integral from t to t+dt of price(x) dx = sol_in
      # => base * dt + slope/(2*SCALE) * ((t+dt)^2 - t^2) = sol_in
      # => base * dt + slope/(2*SCALE) * (dt^2 + 2*t*dt) = sol_in
      #
      # Solving quadratic: a*dt^2 + b*dt - c = 0
      # where a = slope/(2*SCALE), b = base + slope*t/SCALE, c = sol_in
      # ========================================================================

      def calc_buy(
        sol_in : BigInt,
        tokens_sold : BigInt,
        base_price : BigInt,
        slope : BigInt
      ) : BuySimulation?
        return nil if sol_in < MIN_BUY

        # Apply fee
        fee = sol_in * VPOOL_FEE_BPS // 10000
        net_sol = sol_in - fee

        # Current price
        current_price = calc_price(tokens_sold, base_price, slope)

        # If slope is zero (constant price), simple division
        if slope.zero?
          tokens_out = net_sol * SCALE // base_price
          return BuySimulation.new(
            tokens_out: tokens_out,
            new_price: current_price,
            price_impact: 0.0,
            fee: fee
          )
        end

        # Quadratic formula coefficients
        # a = slope / (2 * SCALE)
        # b = base_price + slope * tokens_sold / SCALE = current_price
        # c = net_sol
        #
        # dt = (-b + sqrt(b^2 + 4*a*c)) / (2*a)
        # dt = (-current_price + sqrt(current_price^2 + 2*slope*net_sol/SCALE)) * SCALE / slope

        discriminant = current_price * current_price + BigInt.new(2) * slope * net_sol // SCALE
        sqrt_disc = AeX402::Math.sqrt(discriminant)

        tokens_out = (sqrt_disc - current_price) * SCALE // slope

        # Cap at 2.5% wallet limit worth
        max_tokens = BigInt.new(MAX_BALANCE_UNITS) * TOKEN_QUANTUM
        tokens_out = {tokens_out, max_tokens}.min

        # New price after buy
        new_sold = tokens_sold + tokens_out
        new_price = calc_price(new_sold, base_price, slope)

        # Price impact
        impact = if current_price.zero?
                   0.0
                 else
                   (new_price - current_price).to_f64 / current_price.to_f64
                 end

        BuySimulation.new(
          tokens_out: tokens_out,
          new_price: new_price,
          price_impact: impact,
          fee: fee
        )
      end

      # ========================================================================
      # Sell Calculation
      #
      # Given tokens to sell, calculate SOL received.
      #
      # The integral from (t-dt) to t of price(x) dx = sol_out
      # => base * dt + slope/(2*SCALE) * (t^2 - (t-dt)^2) = sol_out
      # => base * dt + slope/(2*SCALE) * (2*t*dt - dt^2) = sol_out
      # ========================================================================

      def calc_sell(
        tokens_in : BigInt,
        tokens_sold : BigInt,
        base_price : BigInt,
        slope : BigInt
      ) : SellSimulation?
        return nil if tokens_in < MIN_SELL
        return nil if tokens_in > tokens_sold

        # Current price
        current_price = calc_price(tokens_sold, base_price, slope)

        # If slope is zero (constant price)
        if slope.zero?
          gross_sol = tokens_in * base_price // SCALE
          fee = gross_sol * VPOOL_FEE_BPS // 10000
          sol_out = gross_sol - fee

          return SellSimulation.new(
            sol_out: sol_out,
            new_price: current_price,
            price_impact: 0.0,
            fee: fee
          )
        end

        # Area under curve from (tokens_sold - tokens_in) to tokens_sold
        # = base * tokens_in + slope/(2*SCALE) * (2*tokens_sold*tokens_in - tokens_in^2)
        dt = tokens_in
        t = tokens_sold

        # base_part = base_price * dt / SCALE
        base_part = base_price * dt // SCALE

        # slope_part = slope * (2*t*dt - dt^2) / (2*SCALE^2)
        # = slope * dt * (2*t - dt) / (2*SCALE^2)
        slope_part = slope * dt * (BigInt.new(2) * t - dt) // (BigInt.new(2) * SCALE * SCALE)

        gross_sol = base_part + slope_part

        # Apply fee
        fee = gross_sol * VPOOL_FEE_BPS // 10000
        sol_out = gross_sol - fee

        # New price after sell
        new_sold = tokens_sold - tokens_in
        new_price = calc_price(new_sold, base_price, slope)

        # Price impact (negative for sell)
        impact = if current_price.zero?
                   0.0
                 else
                   (new_price - current_price).to_f64 / current_price.to_f64
                 end

        SellSimulation.new(
          sol_out: sol_out,
          new_price: new_price,
          price_impact: impact,
          fee: fee
        )
      end

      # ========================================================================
      # Graduation Target Calculation
      #
      # Dynamic target based on trading activity:
      #   target = 100 SOL (base)
      #          - 50% of net_buy_volume (progress bonus)
      #          + 5 SOL per churn_ratio above 3 (penalty)
      #
      # Clamped to [10 SOL, 200 SOL]
      # ========================================================================

      def calc_graduation_target(
        total_buy_sol : BigInt,
        total_sell_sol : BigInt
      ) : BigInt
        # Net buy volume
        net_buy = total_buy_sol > total_sell_sol ? total_buy_sol - total_sell_sol : BigInt.new(0)

        # Progress bonus (50% of net buy, capped at 50 SOL)
        progress_bonus = net_buy // 2
        max_bonus = TARGET_BASE_SOL // 2
        progress_bonus = {progress_bonus, max_bonus}.min

        # Churn ratio penalty
        churn_penalty = BigInt.new(0)
        if total_buy_sol > BigInt.new(0)
          # churn_ratio = sell / buy
          # If churn > 3, penalty = (churn - 3) * 5 SOL
          # Using integer math: penalty = (sell * 5 - buy * 15) / buy * SOL_UNIT
          if total_sell_sol * 1 > total_buy_sol * 3
            excess_churn = (total_sell_sol - total_buy_sol * 3) * CHURN_PENALTY_SOL // total_buy_sol
            churn_penalty = excess_churn
          end
        end

        # Calculate target
        target = TARGET_BASE_SOL - progress_bonus + churn_penalty

        # Clamp to bounds
        target = {target, TARGET_MIN_SOL}.max
        target = {target, TARGET_MAX_SOL}.min

        target
      end

      # ========================================================================
      # Vesting Calculation
      #
      # 5% per hour for holders, 2% per hour for creator
      # ========================================================================

      def calc_vesting_amount(
        unclaimed : BigInt,
        hours_elapsed : Int64,
        is_creator : Bool
      ) : BigInt
        return unclaimed if unclaimed <= VESTING_DUST

        pct_per_hour = is_creator ? 2 : 5
        total_pct = pct_per_hour * hours_elapsed

        # Cap at 100%
        total_pct = {total_pct, 100}.min

        amount = unclaimed * total_pct // 100

        # Return all if remainder is dust
        remaining = unclaimed - amount
        if remaining <= VESTING_DUST
          unclaimed
        else
          amount
        end
      end

      # ========================================================================
      # Caesar Hash for Wallet Matching
      #
      # Simple hash with rotation to compress 32-byte wallet to 6 bytes
      # ========================================================================

      def caesar_hash(wallet : Bytes, positions : Array(UInt8)) : Bytes
        result = Bytes.new(6)

        6.times do |i|
          pos = positions[i % positions.size] % 32
          result[i] = wallet[pos]
        end

        result
      end

      def wallet_matches?(wallet : Bytes, hash : Bytes, positions : Array(UInt8)) : Bool
        computed = caesar_hash(wallet, positions)
        computed == hash
      end
    end
  end
end
