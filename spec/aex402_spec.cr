require "./spec_helper"

describe AeX402 do
  describe "Constants" do
    it "has correct program ID" do
      AeX402::PROGRAM_ID.should eq("3AMM53MsJZy2Jvf7PeHHga3bsGjWV4TSaYz29WUtcdje")
    end

    it "has correct pool constants" do
      AeX402::MIN_AMP.should eq(1_u64)
      AeX402::MAX_AMP.should eq(100_000_u64)
      AeX402::DEFAULT_FEE_BPS.should eq(30_u64)
      AeX402::NEWTON_ITERATIONS.should eq(255)
      AeX402::MAX_TOKENS.should eq(8)
    end

    it "has correct discriminators" do
      AeX402::Discriminators::CREATEPOOL.size.should eq(8)
      AeX402::Discriminators::SWAP.size.should eq(8)
      AeX402::AccountDiscriminators::POOL.should eq("POOLSWAP".to_slice)
    end
  end

  describe "Pubkey" do
    it "creates from bytes" do
      bytes = Bytes.new(32, 1_u8)
      pubkey = AeX402::Pubkey.new(bytes)
      pubkey.bytes.size.should eq(32)
    end

    it "creates from base58 string" do
      # Example valid base58 pubkey
      pubkey = AeX402::Pubkey.new("11111111111111111111111111111111")
      pubkey.bytes.size.should eq(32)
    end

    it "detects zero pubkey" do
      pubkey = AeX402::Pubkey.default
      pubkey.zero?.should be_true
    end
  end

  describe "Math" do
    describe "calc_d" do
      it "calculates invariant D for equal balances" do
        d = AeX402::Math.calc_d(1_000_000_u64, 1_000_000_u64, 100_u64)
        d.should_not be_nil
        d.not_nil!.should be > BigInt.new(0)
      end

      it "returns zero for zero balances" do
        d = AeX402::Math.calc_d(0_u64, 0_u64, 100_u64)
        d.should eq(BigInt.new(0))
      end
    end

    describe "calc_y" do
      it "calculates output amount" do
        d = AeX402::Math.calc_d(1_000_000_u64, 1_000_000_u64, 100_u64)
        d.should_not be_nil

        # Swap 10% of pool
        new_x = 1_100_000_u64
        y = AeX402::Math.calc_y(new_x, d.not_nil!, 100_u64)
        y.should_not be_nil
        y.not_nil!.should be < BigInt.new(1_000_000)
      end
    end

    describe "simulate_swap" do
      it "simulates swap with fee" do
        out = AeX402::Math.simulate_swap(
          bal_in: 1_000_000_u64,
          bal_out: 1_000_000_u64,
          amount_in: 100_000_u64,
          amp: 100_u64,
          fee_bps: 30_u64
        )
        out.should_not be_nil
        out.not_nil!.should be > BigInt.new(0)
        out.not_nil!.should be < BigInt.new(100_000) # Less than input due to fee
      end
    end

    describe "calc_lp_tokens" do
      it "calculates initial deposit LP tokens" do
        lp = AeX402::Math.calc_lp_tokens(
          amt0: 1_000_000_u64,
          amt1: 1_000_000_u64,
          bal0: 0_u64,
          bal1: 0_u64,
          lp_supply: 0_u64,
          amp: 100_u64
        )
        lp.should_not be_nil
        lp.not_nil!.should eq(BigInt.new(1_000_000)) # sqrt(1M * 1M)
      end
    end

    describe "sqrt" do
      it "calculates integer square root" do
        AeX402::Math.sqrt(BigInt.new(0)).should eq(BigInt.new(0))
        AeX402::Math.sqrt(BigInt.new(1)).should eq(BigInt.new(1))
        AeX402::Math.sqrt(BigInt.new(4)).should eq(BigInt.new(2))
        AeX402::Math.sqrt(BigInt.new(9)).should eq(BigInt.new(3))
        AeX402::Math.sqrt(BigInt.new(1_000_000)).should eq(BigInt.new(1000))
      end
    end

    describe "get_current_amp" do
      it "returns target amp after ramp end" do
        amp = AeX402::Math.get_current_amp(
          amp: 100_u64,
          target_amp: 200_u64,
          ramp_start: 0_i64,
          ramp_end: 100_i64,
          now: 150_i64
        )
        amp.should eq(200_u64)
      end

      it "interpolates during ramp" do
        amp = AeX402::Math.get_current_amp(
          amp: 100_u64,
          target_amp: 200_u64,
          ramp_start: 0_i64,
          ramp_end: 100_i64,
          now: 50_i64
        )
        amp.should eq(150_u64)
      end
    end
  end

  describe "Candle" do
    it "decodes delta-encoded candle" do
      candle = AeX402::Candle.new(
        open: 1_000_000_u32,
        high_d: 100_u16,
        low_d: 50_u16,
        close_d: 25_i16,
        volume: 1000_u16
      )

      decoded = candle.decode
      decoded.open.should eq(1_000_000_u32)
      decoded.high.should eq(1_000_100_u32)
      decoded.low.should eq(999_950_u32)
      decoded.close.should eq(1_000_025_i64)
    end
  end

  describe "TwapResult" do
    it "decodes from u64" do
      # price=1000000, samples=24, confidence=9500
      encoded = 1_000_000_u64 | (24_u64 << 32) | (9500_u64 << 48)
      result = AeX402::TwapResult.decode(encoded)

      result.price.should eq(1_000_000_u32)
      result.samples.should eq(24_u16)
      result.confidence.should eq(9500_u16)
      result.price_f.should eq(1.0)
      result.confidence_pct.should eq(95.0)
    end
  end

  describe "Instructions" do
    it "builds swap_t0_t1 instruction" do
      ix = AeX402::Instructions.swap_t0_t1(
        pool: "11111111111111111111111111111111",
        vault0: "22222222222222222222222222222222",
        vault1: "33333333333333333333333333333333",
        user_token0: "44444444444444444444444444444444",
        user_token1: "55555555555555555555555555555555",
        user: "66666666666666666666666666666666",
        args: AeX402::SwapSimpleArgs.new(
          amount_in: 1_000_000_u64,
          min_out: 900_000_u64
        )
      )

      ix.program_id.should eq(AeX402::PROGRAM_ID)
      ix.accounts.size.should eq(7)
      ix.data.size.should eq(24)
    end

    it "builds add_liquidity instruction" do
      ix = AeX402::Instructions.add_liquidity(
        pool: "11111111111111111111111111111111",
        vault0: "22222222222222222222222222222222",
        vault1: "33333333333333333333333333333333",
        lp_mint: "44444444444444444444444444444444",
        user_token0: "55555555555555555555555555555555",
        user_token1: "66666666666666666666666666666666",
        user_lp: "77777777777777777777777777777777",
        user: "88888888888888888888888888888888",
        args: AeX402::AddLiqArgs.new(
          amount0: 1_000_000_u64,
          amount1: 1_000_000_u64,
          min_lp: 900_000_u64
        )
      )

      ix.program_id.should eq(AeX402::PROGRAM_ID)
      ix.accounts.size.should eq(9)
      ix.data.size.should eq(32)
    end
  end
end

describe AeX402::VPool do
  describe "Constants" do
    it "has correct fee constants" do
      AeX402::VPool::VPOOL_FEE_BPS.should eq(100)
      AeX402::VPool::FEE_BALANCE_BPS.should eq(50)
    end

    it "has correct graduation constants" do
      AeX402::VPool::TARGET_BASE_SOL.should eq(BigInt.new("100000000000"))
      AeX402::VPool::TARGET_MIN_SOL.should eq(BigInt.new("10000000000"))
    end
  end

  describe "Math" do
    describe "calc_price" do
      it "calculates price on bonding curve" do
        price = AeX402::VPool::Math.calc_price(
          tokens_sold: BigInt.new(1_000_000),
          base_price: BigInt.new(1_000_000),
          slope: BigInt.new(1_000)
        )
        price.should be > BigInt.new(1_000_000)
      end
    end

    describe "calc_graduation_target" do
      it "calculates base target with no activity" do
        target = AeX402::VPool::Math.calc_graduation_target(
          total_buy_sol: BigInt.new(0),
          total_sell_sol: BigInt.new(0)
        )
        target.should eq(AeX402::VPool::TARGET_BASE_SOL)
      end

      it "reduces target with net buy volume" do
        target = AeX402::VPool::Math.calc_graduation_target(
          total_buy_sol: BigInt.new("50000000000"), # 50 SOL
          total_sell_sol: BigInt.new(0)
        )
        target.should be < AeX402::VPool::TARGET_BASE_SOL
      end
    end

    describe "calc_vesting_amount" do
      it "vests 5% per hour for holders" do
        amount = AeX402::VPool::Math.calc_vesting_amount(
          unclaimed: BigInt.new(1_000_000),
          hours_elapsed: 1_i64,
          is_creator: false
        )
        amount.should eq(BigInt.new(50_000)) # 5%
      end

      it "vests 2% per hour for creator" do
        amount = AeX402::VPool::Math.calc_vesting_amount(
          unclaimed: BigInt.new(1_000_000),
          hours_elapsed: 1_i64,
          is_creator: true
        )
        amount.should eq(BigInt.new(20_000)) # 2%
      end

      it "returns all if dust remains" do
        amount = AeX402::VPool::Math.calc_vesting_amount(
          unclaimed: BigInt.new(500),
          hours_elapsed: 1_i64,
          is_creator: false
        )
        amount.should eq(BigInt.new(500)) # All, since < VESTING_DUST
      end
    end
  end
end
