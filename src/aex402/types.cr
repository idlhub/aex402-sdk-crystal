module AeX402
  # ============================================================================
  # Pubkey - 32-byte public key
  # ============================================================================

  struct Pubkey
    SIZE = 32

    getter bytes : Bytes

    def initialize(@bytes : Bytes)
      raise ArgumentError.new("Pubkey must be 32 bytes, got #{@bytes.size}") unless @bytes.size == SIZE
    end

    def initialize(base58_string : String)
      @bytes = Base58.decode(base58_string)
      raise ArgumentError.new("Invalid pubkey: #{base58_string}") unless @bytes.size == SIZE
    end

    def to_s : String
      Base58.encode(@bytes)
    end

    def ==(other : Pubkey) : Bool
      @bytes == other.bytes
    end

    def self.default : Pubkey
      new(Bytes.new(SIZE, 0_u8))
    end

    def zero? : Bool
      @bytes.all? { |b| b == 0 }
    end
  end

  # ============================================================================
  # Candle (12 bytes, delta-encoded OHLCV)
  # ============================================================================

  struct Candle
    property open : UInt32      # Base price (scaled 1e6)
    property high_d : UInt16    # High delta (high = open + high_d)
    property low_d : UInt16     # Low delta (low = open - low_d)
    property close_d : Int16    # Close delta signed (close = open + close_d)
    property volume : UInt16    # Volume in 1e9 units

    def initialize(@open = 0_u32, @high_d = 0_u16, @low_d = 0_u16, @close_d = 0_i16, @volume = 0_u16)
    end

    # Decode candle to actual OHLCV values
    def decode : DecodedCandle
      DecodedCandle.new(
        open: @open,
        high: @open + @high_d,
        low: @open - @low_d,
        close: @open.to_i64 + @close_d,
        volume: @volume
      )
    end
  end

  struct DecodedCandle
    property open : UInt32
    property high : UInt32
    property low : UInt32
    property close : Int64
    property volume : UInt16

    def initialize(@open, @high, @low, @close, @volume)
    end

    # Convert to float prices (scaled by 1e6)
    def open_f : Float64
      @open.to_f64 / 1_000_000.0
    end

    def high_f : Float64
      @high.to_f64 / 1_000_000.0
    end

    def low_f : Float64
      @low.to_f64 / 1_000_000.0
    end

    def close_f : Float64
      @close.to_f64 / 1_000_000.0
    end
  end

  # ============================================================================
  # Pool (2-token) - matches C struct in aex402.c
  # Size: 1024 bytes
  # ============================================================================

  class Pool
    property discriminator : Bytes   # 8 bytes "POOLSWAP"
    property authority : Pubkey      # 32 bytes
    property mint0 : Pubkey          # 32 bytes (t0_mint)
    property mint1 : Pubkey          # 32 bytes (t1_mint)
    property vault0 : Pubkey         # 32 bytes (t0_vault)
    property vault1 : Pubkey         # 32 bytes (t1_vault)
    property lp_mint : Pubkey        # 32 bytes
    property amp : UInt64            # 8 bytes - current amp
    property init_amp : UInt64       # 8 bytes - initial amp for ramping
    property target_amp : UInt64     # 8 bytes (tgt_amp)
    property ramp_start : Int64      # 8 bytes
    property ramp_stop : Int64       # 8 bytes
    property fee_bps : UInt64        # 8 bytes
    property admin_fee_pct : UInt64  # 8 bytes (admin_pct)
    property bal0 : UInt64           # 8 bytes
    property bal1 : UInt64           # 8 bytes
    property lp_supply : UInt64      # 8 bytes
    property admin_fee0 : UInt64     # 8 bytes (admin0)
    property admin_fee1 : UInt64     # 8 bytes (admin1)
    property vol0 : UInt64           # 8 bytes - volume token0
    property vol1 : UInt64           # 8 bytes - volume token1
    property paused : Bool           # 1 byte
    property bump : UInt8            # 1 byte
    property vault0_bump : UInt8     # 1 byte (v0_bump)
    property vault1_bump : UInt8     # 1 byte (v1_bump)
    property lp_mint_bump : UInt8    # 1 byte (lp_bump)
    property pending_auth : Pubkey   # 32 bytes
    property auth_time : Int64       # 8 bytes
    property pending_amp : UInt64    # 8 bytes
    property amp_time : Int64        # 8 bytes
    property trade_count : UInt64    # 8 bytes (trade_cnt)
    property trade_sum : UInt64      # 8 bytes (sum_trade)
    property max_price : UInt32      # 4 bytes
    property min_price : UInt32      # 4 bytes
    property hour_slot : UInt32      # 4 bytes
    property day_slot : UInt32       # 4 bytes
    property hour_idx : UInt8        # 1 byte
    property day_idx : UInt8         # 1 byte
    property bloom : Bytes           # 128 bytes
    property hourly_candles : Array(Candle)  # 24 * 12 = 288 bytes
    property daily_candles : Array(Candle)   # 7 * 12 = 84 bytes

    def initialize(
      @discriminator = Bytes.new(8),
      @authority = Pubkey.default,
      @mint0 = Pubkey.default,
      @mint1 = Pubkey.default,
      @vault0 = Pubkey.default,
      @vault1 = Pubkey.default,
      @lp_mint = Pubkey.default,
      @amp = 0_u64,
      @init_amp = 0_u64,
      @target_amp = 0_u64,
      @ramp_start = 0_i64,
      @ramp_stop = 0_i64,
      @fee_bps = 0_u64,
      @admin_fee_pct = 0_u64,
      @bal0 = 0_u64,
      @bal1 = 0_u64,
      @lp_supply = 0_u64,
      @admin_fee0 = 0_u64,
      @admin_fee1 = 0_u64,
      @vol0 = 0_u64,
      @vol1 = 0_u64,
      @paused = false,
      @bump = 0_u8,
      @vault0_bump = 0_u8,
      @vault1_bump = 0_u8,
      @lp_mint_bump = 0_u8,
      @pending_auth = Pubkey.default,
      @auth_time = 0_i64,
      @pending_amp = 0_u64,
      @amp_time = 0_i64,
      @trade_count = 0_u64,
      @trade_sum = 0_u64,
      @max_price = 0_u32,
      @min_price = 0_u32,
      @hour_slot = 0_u32,
      @day_slot = 0_u32,
      @hour_idx = 0_u8,
      @day_idx = 0_u8,
      @bloom = Bytes.new(BLOOM_SIZE),
      @hourly_candles = Array(Candle).new(OHLCV_24H) { Candle.new },
      @daily_candles = Array(Candle).new(OHLCV_7D) { Candle.new }
    )
    end
  end

  # ============================================================================
  # NPool (N-token, 2-8 tokens) - matches C struct in aex402.c
  # Size: 2048 bytes
  # ============================================================================

  class NPool
    property discriminator : Bytes     # 8 bytes "NPOOLSWA"
    property authority : Pubkey        # 32 bytes
    property n_tokens : UInt8          # 1 byte
    property paused : Bool             # 1 byte
    property bump : UInt8              # 1 byte
    property amp : UInt64              # 8 bytes
    property fee_bps : UInt64          # 8 bytes
    property admin_fee_pct : UInt64    # 8 bytes
    property lp_supply : UInt64        # 8 bytes
    property mints : Array(Pubkey)     # 8 * 32 = 256 bytes
    property vaults : Array(Pubkey)    # 8 * 32 = 256 bytes
    property lp_mint : Pubkey          # 32 bytes
    property balances : Array(UInt64)  # 8 * 8 = 64 bytes
    property admin_fees : Array(UInt64) # 8 * 8 = 64 bytes
    property total_volume : UInt64     # 8 bytes
    property trade_count : UInt64      # 8 bytes
    property last_trade_slot : UInt64  # 8 bytes

    def initialize(
      @discriminator = Bytes.new(8),
      @authority = Pubkey.default,
      @n_tokens = 0_u8,
      @paused = false,
      @bump = 0_u8,
      @amp = 0_u64,
      @fee_bps = 0_u64,
      @admin_fee_pct = 0_u64,
      @lp_supply = 0_u64,
      @mints = Array(Pubkey).new(MAX_TOKENS) { Pubkey.default },
      @vaults = Array(Pubkey).new(MAX_TOKENS) { Pubkey.default },
      @lp_mint = Pubkey.default,
      @balances = Array(UInt64).new(MAX_TOKENS, 0_u64),
      @admin_fees = Array(UInt64).new(MAX_TOKENS, 0_u64),
      @total_volume = 0_u64,
      @trade_count = 0_u64,
      @last_trade_slot = 0_u64
    )
    end
  end

  # ============================================================================
  # Lottery - matches C struct in aex402.c
  # ============================================================================

  class Lottery
    property discriminator : Bytes    # 8 bytes "LOTTERY!"
    property pool : Pubkey            # 32 bytes
    property authority : Pubkey       # 32 bytes
    property lottery_vault : Pubkey   # 32 bytes
    property ticket_price : UInt64    # 8 bytes
    property total_tickets : UInt64   # 8 bytes
    property prize_pool : UInt64      # 8 bytes
    property end_time : Int64         # 8 bytes
    property winning_ticket : UInt64  # 8 bytes
    property drawn : Bool             # 1 byte
    property claimed : Bool           # 1 byte

    def initialize(
      @discriminator = Bytes.new(8),
      @pool = Pubkey.default,
      @authority = Pubkey.default,
      @lottery_vault = Pubkey.default,
      @ticket_price = 0_u64,
      @total_tickets = 0_u64,
      @prize_pool = 0_u64,
      @end_time = 0_i64,
      @winning_ticket = 0_u64,
      @drawn = false,
      @claimed = false
    )
    end
  end

  # ============================================================================
  # LotteryEntry - matches C struct in aex402.c
  # ============================================================================

  class LotteryEntry
    property discriminator : Bytes   # 8 bytes "LOTENTRY"
    property owner : Pubkey          # 32 bytes
    property lottery : Pubkey        # 32 bytes
    property ticket_start : UInt64   # 8 bytes
    property ticket_count : UInt64   # 8 bytes

    def initialize(
      @discriminator = Bytes.new(8),
      @owner = Pubkey.default,
      @lottery = Pubkey.default,
      @ticket_start = 0_u64,
      @ticket_count = 0_u64
    )
    end
  end

  # ============================================================================
  # Farm - matches C struct in aex402.c
  # ============================================================================

  class Farm
    property discriminator : Bytes   # 8 bytes "FARMSWAP"
    property pool : Pubkey           # 32 bytes
    property reward_mint : Pubkey    # 32 bytes
    property reward_rate : UInt64    # 8 bytes
    property start_time : Int64      # 8 bytes
    property end_time : Int64        # 8 bytes
    property total_staked : UInt64   # 8 bytes
    property acc_reward : UInt64     # 8 bytes
    property last_update : Int64     # 8 bytes

    def initialize(
      @discriminator = Bytes.new(8),
      @pool = Pubkey.default,
      @reward_mint = Pubkey.default,
      @reward_rate = 0_u64,
      @start_time = 0_i64,
      @end_time = 0_i64,
      @total_staked = 0_u64,
      @acc_reward = 0_u64,
      @last_update = 0_i64
    )
    end
  end

  # ============================================================================
  # UserFarm - matches C struct in aex402.c
  # ============================================================================

  class UserFarm
    property discriminator : Bytes   # 8 bytes "UFARMSWA"
    property owner : Pubkey          # 32 bytes
    property farm : Pubkey           # 32 bytes
    property staked : UInt64         # 8 bytes
    property reward_debt : UInt64    # 8 bytes
    property lock_end : Int64        # 8 bytes - lock expiration timestamp

    def initialize(
      @discriminator = Bytes.new(8),
      @owner = Pubkey.default,
      @farm = Pubkey.default,
      @staked = 0_u64,
      @reward_debt = 0_u64,
      @lock_end = 0_i64
    )
    end
  end

  # ============================================================================
  # Registry - for pool enumeration
  # ============================================================================

  class Registry
    property discriminator : Bytes
    property authority : Pubkey
    property pending_auth : Pubkey
    property auth_time : Int64
    property count : UInt32
    property pools : Array(Pubkey)

    def initialize(
      @discriminator = Bytes.new(8),
      @authority = Pubkey.default,
      @pending_auth = Pubkey.default,
      @auth_time = 0_i64,
      @count = 0_u32,
      @pools = Array(Pubkey).new
    )
    end
  end

  # ============================================================================
  # TWAP Result
  # ============================================================================

  struct TwapResult
    property price : UInt32      # Scaled 1e6
    property samples : UInt16    # Number of candles used
    property confidence : UInt16 # 0-10000 (0-100%)

    def initialize(@price = 0_u32, @samples = 0_u16, @confidence = 0_u16)
    end

    def price_f : Float64
      @price.to_f64 / 1_000_000.0
    end

    def confidence_pct : Float64
      @confidence.to_f64 / 100.0
    end

    # Decode from u64 return value
    def self.decode(encoded : UInt64) : TwapResult
      price = (encoded & 0xFFFFFFFF).to_u32
      samples = ((encoded >> 32) & 0xFFFF).to_u16
      confidence = ((encoded >> 48) & 0xFFFF).to_u16
      TwapResult.new(price, samples, confidence)
    end
  end

  # ============================================================================
  # Instruction Args
  # ============================================================================

  struct CreatePoolArgs
    property amp : UInt64
    property bump : UInt8

    def initialize(@amp, @bump)
    end
  end

  struct CreateNPoolArgs
    property amp : UInt64
    property n_tokens : UInt8
    property bump : UInt8

    def initialize(@amp, @n_tokens, @bump)
    end
  end

  struct SwapArgs
    property from : UInt8
    property to : UInt8
    property amount_in : UInt64
    property min_out : UInt64
    property deadline : Int64

    def initialize(@from, @to, @amount_in, @min_out, @deadline)
    end
  end

  struct SwapSimpleArgs
    property amount_in : UInt64
    property min_out : UInt64

    def initialize(@amount_in, @min_out)
    end
  end

  struct SwapNArgs
    property from_idx : UInt8
    property to_idx : UInt8
    property amount_in : UInt64
    property min_out : UInt64

    def initialize(@from_idx, @to_idx, @amount_in, @min_out)
    end
  end

  struct AddLiqArgs
    property amount0 : UInt64
    property amount1 : UInt64
    property min_lp : UInt64

    def initialize(@amount0, @amount1, @min_lp)
    end
  end

  struct AddLiq1Args
    property amount_in : UInt64
    property min_lp : UInt64

    def initialize(@amount_in, @min_lp)
    end
  end

  struct RemLiqArgs
    property lp_amount : UInt64
    property min0 : UInt64
    property min1 : UInt64

    def initialize(@lp_amount, @min0, @min1)
    end
  end

  struct UpdateFeeArgs
    property fee_bps : UInt64

    def initialize(@fee_bps)
    end
  end

  struct CommitAmpArgs
    property target_amp : UInt64

    def initialize(@target_amp)
    end
  end

  struct RampAmpArgs
    property target_amp : UInt64
    property duration : Int64

    def initialize(@target_amp, @duration)
    end
  end

  struct CreateFarmArgs
    property reward_rate : UInt64
    property start_time : Int64
    property end_time : Int64

    def initialize(@reward_rate, @start_time, @end_time)
    end
  end

  struct StakeArgs
    property amount : UInt64

    def initialize(@amount)
    end
  end

  struct LockLpArgs
    property amount : UInt64
    property duration : Int64

    def initialize(@amount, @duration)
    end
  end

  struct CreateLotteryArgs
    property ticket_price : UInt64
    property end_time : Int64

    def initialize(@ticket_price, @end_time)
    end
  end

  struct EnterLotteryArgs
    property ticket_count : UInt64

    def initialize(@ticket_count)
    end
  end

  struct DrawLotteryArgs
    property random_seed : UInt64

    def initialize(@random_seed)
    end
  end
end

# Base58 encoding/decoding (simple implementation)
module Base58
  ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

  def self.encode(bytes : Bytes) : String
    return "" if bytes.empty?

    # Count leading zeros
    zeros = 0
    bytes.each do |b|
      break if b != 0
      zeros += 1
    end

    # Convert to base58
    size = bytes.size * 138 // 100 + 1
    buf = Array(UInt8).new(size, 0_u8)

    bytes.each do |b|
      carry = b.to_i32
      i = size - 1
      while i >= 0
        carry += 256 * buf[i]
        buf[i] = (carry % 58).to_u8
        carry //= 58
        i -= 1
      end
    end

    # Skip leading zeros in buffer
    i = 0
    while i < size && buf[i] == 0
      i += 1
    end

    String.build do |str|
      zeros.times { str << '1' }
      while i < size
        str << ALPHABET[buf[i]]
        i += 1
      end
    end
  end

  def self.decode(str : String) : Bytes
    return Bytes.empty if str.empty?

    # Count leading '1's (zeros)
    zeros = 0
    str.each_char do |c|
      break if c != '1'
      zeros += 1
    end

    # Convert from base58
    size = str.size * 733 // 1000 + 1
    buf = Array(UInt8).new(size, 0_u8)

    str.each_char do |c|
      idx = ALPHABET.index(c)
      raise ArgumentError.new("Invalid base58 character: #{c}") unless idx

      carry = idx
      i = size - 1
      while i >= 0
        carry += 58 * buf[i]
        buf[i] = (carry % 256).to_u8
        carry //= 256
        i -= 1
      end
    end

    # Skip leading zeros in buffer
    i = 0
    while i < size && buf[i] == 0
      i += 1
    end

    # Build result
    result = Bytes.new(zeros + size - i)
    (i...size).each_with_index do |j, idx|
      result[zeros + idx] = buf[j]
    end

    result
  end
end
