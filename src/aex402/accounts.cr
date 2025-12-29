module AeX402
  # ============================================================================
  # Account Parsing Module
  # ============================================================================

  module Accounts
    extend self

    # ========================================================================
    # Buffer Reading Helpers
    # ========================================================================

    private def read_u8(data : Bytes, offset : Int32) : UInt8
      data[offset]
    end

    private def read_u16_le(data : Bytes, offset : Int32) : UInt16
      data[offset].to_u16 | (data[offset + 1].to_u16 << 8)
    end

    private def read_i16_le(data : Bytes, offset : Int32) : Int16
      read_u16_le(data, offset).to_i16!
    end

    private def read_u32_le(data : Bytes, offset : Int32) : UInt32
      data[offset].to_u32 |
        (data[offset + 1].to_u32 << 8) |
        (data[offset + 2].to_u32 << 16) |
        (data[offset + 3].to_u32 << 24)
    end

    private def read_u64_le(data : Bytes, offset : Int32) : UInt64
      result = 0_u64
      8.times do |i|
        result |= data[offset + i].to_u64 << (i * 8)
      end
      result
    end

    private def read_i64_le(data : Bytes, offset : Int32) : Int64
      read_u64_le(data, offset).to_i64!
    end

    private def read_pubkey(data : Bytes, offset : Int32) : Pubkey
      Pubkey.new(data[offset, 32].dup)
    end

    private def read_candle(data : Bytes, offset : Int32) : Candle
      Candle.new(
        open: read_u32_le(data, offset),
        high_d: read_u16_le(data, offset + 4),
        low_d: read_u16_le(data, offset + 6),
        close_d: read_i16_le(data, offset + 8),
        volume: read_u16_le(data, offset + 10)
      )
    end

    # ========================================================================
    # Pool Parsing - matches C struct in aex402.c lines 236-281
    # ========================================================================

    def parse_pool(data : Bytes) : Pool?
      return nil if data.size < 900

      disc = data[0, 8]
      return nil unless disc == AccountDiscriminators::POOL

      offset = 8

      # Pubkeys (6 * 32 = 192 bytes)
      authority = read_pubkey(data, offset); offset += 32
      mint0 = read_pubkey(data, offset); offset += 32
      mint1 = read_pubkey(data, offset); offset += 32
      vault0 = read_pubkey(data, offset); offset += 32
      vault1 = read_pubkey(data, offset); offset += 32
      lp_mint = read_pubkey(data, offset); offset += 32

      # Amp fields (5 * 8 = 40 bytes)
      amp = read_u64_le(data, offset); offset += 8
      init_amp = read_u64_le(data, offset); offset += 8
      target_amp = read_u64_le(data, offset); offset += 8
      ramp_start = read_i64_le(data, offset); offset += 8
      ramp_stop = read_i64_le(data, offset); offset += 8

      # Fee fields (2 * 8 = 16 bytes)
      fee_bps = read_u64_le(data, offset); offset += 8
      admin_fee_pct = read_u64_le(data, offset); offset += 8

      # Balance fields (5 * 8 = 40 bytes)
      bal0 = read_u64_le(data, offset); offset += 8
      bal1 = read_u64_le(data, offset); offset += 8
      lp_supply = read_u64_le(data, offset); offset += 8
      admin_fee0 = read_u64_le(data, offset); offset += 8
      admin_fee1 = read_u64_le(data, offset); offset += 8

      # Volume fields (2 * 8 = 16 bytes)
      vol0 = read_u64_le(data, offset); offset += 8
      vol1 = read_u64_le(data, offset); offset += 8

      # Flags (5 bytes + 3 padding)
      paused = read_u8(data, offset) != 0; offset += 1
      bump = read_u8(data, offset); offset += 1
      vault0_bump = read_u8(data, offset); offset += 1
      vault1_bump = read_u8(data, offset); offset += 1
      lp_mint_bump = read_u8(data, offset); offset += 1
      offset += 3 # _pad[3]

      # Pending authority (32 + 8 = 40 bytes)
      pending_auth = read_pubkey(data, offset); offset += 32
      auth_time = read_i64_le(data, offset); offset += 8

      # Pending amp (8 + 8 = 16 bytes)
      pending_amp = read_u64_le(data, offset); offset += 8
      amp_time = read_i64_le(data, offset); offset += 8

      # Analytics section
      trade_count = read_u64_le(data, offset); offset += 8
      trade_sum = read_u64_le(data, offset); offset += 8
      max_price = read_u32_le(data, offset); offset += 4
      min_price = read_u32_le(data, offset); offset += 4
      hour_slot = read_u32_le(data, offset); offset += 4
      day_slot = read_u32_le(data, offset); offset += 4
      hour_idx = read_u8(data, offset); offset += 1
      day_idx = read_u8(data, offset); offset += 1
      offset += 6 # _pad2[6]

      # Bloom filter (128 bytes)
      bloom = data[offset, BLOOM_SIZE].dup
      offset += BLOOM_SIZE

      # Hourly candles (24 * 12 = 288 bytes)
      hourly_candles = Array(Candle).new(OHLCV_24H) do |i|
        candle = read_candle(data, offset + i * 12)
        candle
      end
      offset += OHLCV_24H * 12

      # Daily candles (7 * 12 = 84 bytes)
      daily_candles = Array(Candle).new(OHLCV_7D) do |i|
        candle = read_candle(data, offset + i * 12)
        candle
      end

      Pool.new(
        discriminator: disc.dup,
        authority: authority,
        mint0: mint0,
        mint1: mint1,
        vault0: vault0,
        vault1: vault1,
        lp_mint: lp_mint,
        amp: amp,
        init_amp: init_amp,
        target_amp: target_amp,
        ramp_start: ramp_start,
        ramp_stop: ramp_stop,
        fee_bps: fee_bps,
        admin_fee_pct: admin_fee_pct,
        bal0: bal0,
        bal1: bal1,
        lp_supply: lp_supply,
        admin_fee0: admin_fee0,
        admin_fee1: admin_fee1,
        vol0: vol0,
        vol1: vol1,
        paused: paused,
        bump: bump,
        vault0_bump: vault0_bump,
        vault1_bump: vault1_bump,
        lp_mint_bump: lp_mint_bump,
        pending_auth: pending_auth,
        auth_time: auth_time,
        pending_amp: pending_amp,
        amp_time: amp_time,
        trade_count: trade_count,
        trade_sum: trade_sum,
        max_price: max_price,
        min_price: min_price,
        hour_slot: hour_slot,
        day_slot: day_slot,
        hour_idx: hour_idx,
        day_idx: day_idx,
        bloom: bloom,
        hourly_candles: hourly_candles,
        daily_candles: daily_candles
      )
    end

    # ========================================================================
    # NPool Parsing - matches C struct in aex402.c lines 284-304
    # ========================================================================

    def parse_npool(data : Bytes) : NPool?
      return nil if data.size < 800

      disc = data[0, 8]
      return nil unless disc == AccountDiscriminators::NPOOL

      offset = 8

      authority = read_pubkey(data, offset); offset += 32

      n_tokens = read_u8(data, offset); offset += 1
      paused = read_u8(data, offset) != 0; offset += 1
      bump = read_u8(data, offset); offset += 1
      offset += 5 # _pad[5]

      amp = read_u64_le(data, offset); offset += 8
      fee_bps = read_u64_le(data, offset); offset += 8
      admin_fee_pct = read_u64_le(data, offset); offset += 8
      lp_supply = read_u64_le(data, offset); offset += 8

      # Mints (8 * 32 = 256 bytes)
      mints = Array(Pubkey).new(MAX_TOKENS) do |i|
        read_pubkey(data, offset + i * 32)
      end
      offset += MAX_TOKENS * 32

      # Vaults (8 * 32 = 256 bytes)
      vaults = Array(Pubkey).new(MAX_TOKENS) do |i|
        read_pubkey(data, offset + i * 32)
      end
      offset += MAX_TOKENS * 32

      lp_mint = read_pubkey(data, offset); offset += 32

      # Balances (8 * 8 = 64 bytes)
      balances = Array(UInt64).new(MAX_TOKENS) do |i|
        read_u64_le(data, offset + i * 8)
      end
      offset += MAX_TOKENS * 8

      # Admin fees (8 * 8 = 64 bytes)
      admin_fees = Array(UInt64).new(MAX_TOKENS) do |i|
        read_u64_le(data, offset + i * 8)
      end
      offset += MAX_TOKENS * 8

      total_volume = read_u64_le(data, offset); offset += 8
      trade_count = read_u64_le(data, offset); offset += 8
      last_trade_slot = read_u64_le(data, offset); offset += 8

      NPool.new(
        discriminator: disc.dup,
        authority: authority,
        n_tokens: n_tokens,
        paused: paused,
        bump: bump,
        amp: amp,
        fee_bps: fee_bps,
        admin_fee_pct: admin_fee_pct,
        lp_supply: lp_supply,
        mints: mints,
        vaults: vaults,
        lp_mint: lp_mint,
        balances: balances,
        admin_fees: admin_fees,
        total_volume: total_volume,
        trade_count: trade_count,
        last_trade_slot: last_trade_slot
      )
    end

    # ========================================================================
    # Farm Parsing - matches C struct in aex402.c lines 332-342
    # ========================================================================

    def parse_farm(data : Bytes) : Farm?
      return nil if data.size < 120

      disc = data[0, 8]
      return nil unless disc == AccountDiscriminators::FARM

      offset = 8

      pool = read_pubkey(data, offset); offset += 32
      reward_mint = read_pubkey(data, offset); offset += 32
      reward_rate = read_u64_le(data, offset); offset += 8
      start_time = read_i64_le(data, offset); offset += 8
      end_time = read_i64_le(data, offset); offset += 8
      total_staked = read_u64_le(data, offset); offset += 8
      acc_reward = read_u64_le(data, offset); offset += 8
      last_update = read_i64_le(data, offset); offset += 8

      Farm.new(
        discriminator: disc.dup,
        pool: pool,
        reward_mint: reward_mint,
        reward_rate: reward_rate,
        start_time: start_time,
        end_time: end_time,
        total_staked: total_staked,
        acc_reward: acc_reward,
        last_update: last_update
      )
    end

    # ========================================================================
    # UserFarm Parsing - matches C struct in aex402.c lines 345-354
    # ========================================================================

    def parse_user_farm(data : Bytes) : UserFarm?
      return nil if data.size < 96

      disc = data[0, 8]
      return nil unless disc == AccountDiscriminators::UFARM

      offset = 8

      owner = read_pubkey(data, offset); offset += 32
      farm = read_pubkey(data, offset); offset += 32
      staked = read_u64_le(data, offset); offset += 8
      reward_debt = read_u64_le(data, offset); offset += 8
      lock_end = read_i64_le(data, offset); offset += 8

      UserFarm.new(
        discriminator: disc.dup,
        owner: owner,
        farm: farm,
        staked: staked,
        reward_debt: reward_debt,
        lock_end: lock_end
      )
    end

    # ========================================================================
    # Lottery Parsing - matches C struct in aex402.c lines 307-320
    # ========================================================================

    def parse_lottery(data : Bytes) : Lottery?
      return nil if data.size < 152

      disc = data[0, 8]
      return nil unless disc == AccountDiscriminators::LOTTERY

      offset = 8

      pool = read_pubkey(data, offset); offset += 32
      authority = read_pubkey(data, offset); offset += 32
      lottery_vault = read_pubkey(data, offset); offset += 32
      ticket_price = read_u64_le(data, offset); offset += 8
      total_tickets = read_u64_le(data, offset); offset += 8
      prize_pool = read_u64_le(data, offset); offset += 8
      end_time = read_i64_le(data, offset); offset += 8
      winning_ticket = read_u64_le(data, offset); offset += 8
      drawn = read_u8(data, offset) != 0; offset += 1
      claimed = read_u8(data, offset) != 0; offset += 1

      Lottery.new(
        discriminator: disc.dup,
        pool: pool,
        authority: authority,
        lottery_vault: lottery_vault,
        ticket_price: ticket_price,
        total_tickets: total_tickets,
        prize_pool: prize_pool,
        end_time: end_time,
        winning_ticket: winning_ticket,
        drawn: drawn,
        claimed: claimed
      )
    end

    # ========================================================================
    # LotteryEntry Parsing - matches C struct in aex402.c lines 323-329
    # ========================================================================

    def parse_lottery_entry(data : Bytes) : LotteryEntry?
      return nil if data.size < 88

      disc = data[0, 8]
      return nil unless disc == AccountDiscriminators::LOTENTRY

      offset = 8

      owner = read_pubkey(data, offset); offset += 32
      lottery = read_pubkey(data, offset); offset += 32
      ticket_start = read_u64_le(data, offset); offset += 8
      ticket_count = read_u64_le(data, offset); offset += 8

      LotteryEntry.new(
        discriminator: disc.dup,
        owner: owner,
        lottery: lottery,
        ticket_start: ticket_start,
        ticket_count: ticket_count
      )
    end

    # ========================================================================
    # Discriminator Validation
    # ========================================================================

    def valid_discriminator?(data : Bytes, expected : Bytes) : Bool
      return false if data.size < 8
      data[0, 8] == expected
    end

    def get_account_type(data : Bytes) : Symbol?
      return nil if data.size < 8

      disc = data[0, 8]

      case disc
      when AccountDiscriminators::POOL
        :pool
      when AccountDiscriminators::NPOOL
        :npool
      when AccountDiscriminators::FARM
        :farm
      when AccountDiscriminators::UFARM
        :user_farm
      when AccountDiscriminators::LOTTERY
        :lottery
      when AccountDiscriminators::LOTENTRY
        :lottery_entry
      when AccountDiscriminators::REGISTRY
        :registry
      when AccountDiscriminators::MLBRAIN
        :ml_brain
      when AccountDiscriminators::CLPOOL
        :cl_pool
      when AccountDiscriminators::CLPOS
        :cl_position
      when AccountDiscriminators::BOOK
        :orderbook
      else
        nil
      end
    end
  end
end
