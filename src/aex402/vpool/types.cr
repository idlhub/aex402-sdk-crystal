module AeX402
  module VPool
    # ==========================================================================
    # Slot Status
    # ==========================================================================

    enum SlotStatus
      Free      = 0
      Active    = 1
      Graduated = 2
      Flushed   = 3
    end

    # ==========================================================================
    # Global Header (64 bytes)
    # ==========================================================================

    class GlobalHeader
      property discriminator : Bytes    # 8 bytes "GPVOOLS!"
      property num_slots : UInt32       # Currently allocated slots
      property next_pool_id : UInt32    # Incrementing unique ID counter
      property fee_balance : UInt64     # SOL collected for realloc (lamports)
      property total_volume : UInt64    # Lifetime trading volume (lamports)
      property active_pools : UInt32    # Count of ACTIVE status pools
      property graduated_count : UInt32 # Lifetime graduated pools
      property flushed_count : UInt32   # Lifetime flushed pools

      def initialize(
        @discriminator = Bytes.new(8),
        @num_slots = 0_u32,
        @next_pool_id = 0_u32,
        @fee_balance = 0_u64,
        @total_volume = 0_u64,
        @active_pools = 0_u32,
        @graduated_count = 0_u32,
        @flushed_count = 0_u32
      )
      end
    end

    # ==========================================================================
    # VPoolSlot (10KB)
    # ==========================================================================

    class VPoolSlot
      property slot_index : UInt32          # Slot index in global PDA
      property status : SlotStatus          # 0=FREE, 1=ACTIVE, 2=GRADUATED, 3=FLUSHED
      property pool_id : UInt32             # Unique pool ID (survives slot reuse)
      property creator : Pubkey             # Pool creator
      property name : String                # Token name (max 32 chars)
      property symbol : String              # Token symbol (max 8 chars)
      property uri : String                 # Metadata URI (max 128 chars)
      property base_price : BigInt          # Starting price (lamports/token)
      property slope : BigInt               # Price slope for bonding curve
      property total_supply : BigInt        # Fixed total supply
      property tokens_sold : BigInt         # Cumulative tokens sold
      property sol_raised : BigInt          # Current SOL in slot (lamports)
      property total_buy_sol : BigInt       # Gross buy volume (lamports)
      property total_sell_sol : BigInt      # Gross sell volume (lamports)
      property created_at : Int64           # Creation timestamp
      property last_trade_at : Int64        # Last trade timestamp
      property real_pool : Pubkey           # AMM pool address (post-graduation)
      property real_mint : Pubkey           # Token mint address (post-graduation)
      property creator_unclaimed : BigInt   # Creator vesting balance
      property creator_last_claim : Int64   # Creator last claim time
      property graduation_triggerer : Pubkey # Address to receive graduation reward
      property holder_count : UInt32        # Number of holders
      property mint_bump : UInt8            # Mint PDA bump
      property hash_positions : Array(UInt8) # Caesar rotation positions for hash
      property holders : Array(VPoolHolder) # Holder entries

      def initialize(
        @slot_index = 0_u32,
        @status = SlotStatus::Free,
        @pool_id = 0_u32,
        @creator = Pubkey.default,
        @name = "",
        @symbol = "",
        @uri = "",
        @base_price = BigInt.new(0),
        @slope = BigInt.new(0),
        @total_supply = BigInt.new(0),
        @tokens_sold = BigInt.new(0),
        @sol_raised = BigInt.new(0),
        @total_buy_sol = BigInt.new(0),
        @total_sell_sol = BigInt.new(0),
        @created_at = 0_i64,
        @last_trade_at = 0_i64,
        @real_pool = Pubkey.default,
        @real_mint = Pubkey.default,
        @creator_unclaimed = BigInt.new(0),
        @creator_last_claim = 0_i64,
        @graduation_triggerer = Pubkey.default,
        @holder_count = 0_u32,
        @mint_bump = 0_u8,
        @hash_positions = Array(UInt8).new(8, 0_u8),
        @holders = Array(VPoolHolder).new
      )
      end
    end

    # ==========================================================================
    # VPoolHolder (7 bytes, packed)
    # ==========================================================================

    struct VPoolHolder
      property wallet_hash : Bytes  # Caesar-rotated wallet hash (6 bytes)
      property balance : UInt8      # Balance in TOKEN_QUANTUM units (max 250 = 2.5%)

      def initialize(@wallet_hash = Bytes.new(6), @balance = 0_u8)
      end

      # Get actual token balance
      def token_balance : BigInt
        BigInt.new(@balance) * TOKEN_QUANTUM
      end
    end

    # ==========================================================================
    # VPoolClaimPDA (96 bytes)
    # ==========================================================================

    class VPoolClaimPDA
      property discriminator : Bytes  # 8 bytes "VPCLAIM!"
      property pool_id : UInt32       # Pool ID (not slot_index)
      property wallet : Pubkey        # Holder wallet
      property unclaimed : BigInt     # Tokens still vesting
      property claimed : BigInt       # Tokens already claimed
      property last_claim : Int64     # Last claim timestamp

      def initialize(
        @discriminator = Bytes.new(8),
        @pool_id = 0_u32,
        @wallet = Pubkey.default,
        @unclaimed = BigInt.new(0),
        @claimed = BigInt.new(0),
        @last_claim = 0_i64
      )
      end
    end

    # ==========================================================================
    # FarmingState (664 bytes)
    # ==========================================================================

    class FarmingState
      property discriminator : Bytes          # 8 bytes "FARMSTAT"
      property pool : Pubkey                  # AMM pool this belongs to
      property graduated_mint : Pubkey        # Token mint from graduation
      property top_hashes : Array(Bytes)      # Top 10 buyer hashes
      property top_amounts : Array(BigInt)    # SOL spent per buyer
      property commitment : Bytes             # Commitment hash
      property committer : Pubkey             # Current committer pubkey
      property commit_window : UInt32         # Which window was committed
      property deposit_mint : Pubkey          # Which IDL mint deposited
      property deposit_amount : BigInt        # 1M IDL deposit amount
      property farming_window_start : Int64   # Current window start
      property farming_end : Int64            # Graduation time + 90 days
      property farming_rewards_left : BigInt  # Tokens remaining for rewards
      property hash_positions : Array(UInt8)  # Hash positions copied from vpool
      property recent_committers : Array(Pubkey) # Last 10 committers
      property cooldown_head : UInt8          # Circular buffer index

      def initialize(
        @discriminator = Bytes.new(8),
        @pool = Pubkey.default,
        @graduated_mint = Pubkey.default,
        @top_hashes = Array(Bytes).new(10) { Bytes.new(6) },
        @top_amounts = Array(BigInt).new(10) { BigInt.new(0) },
        @commitment = Bytes.new(32),
        @committer = Pubkey.default,
        @commit_window = 0_u32,
        @deposit_mint = Pubkey.default,
        @deposit_amount = BigInt.new(0),
        @farming_window_start = 0_i64,
        @farming_end = 0_i64,
        @farming_rewards_left = BigInt.new(0),
        @hash_positions = Array(UInt8).new(8, 0_u8),
        @recent_committers = Array(Pubkey).new(10) { Pubkey.default },
        @cooldown_head = 0_u8
      )
      end
    end

    # ==========================================================================
    # Instruction Args
    # ==========================================================================

    struct CreateVPoolArgs
      property name : String
      property symbol : String
      property uri : String
      property base_price : BigInt
      property slope : BigInt
      property total_supply : BigInt

      def initialize(@name, @symbol, @uri, @base_price, @slope, @total_supply)
      end
    end

    struct VPoolBuyArgs
      property slot_index : UInt32
      property sol_amount : BigInt

      def initialize(@slot_index, @sol_amount)
      end
    end

    struct VPoolSellArgs
      property slot_index : UInt32
      property token_amount : BigInt

      def initialize(@slot_index, @token_amount)
      end
    end

    struct VPoolGraduateArgs
      property slot_index : UInt32

      def initialize(@slot_index)
      end
    end

    struct VPoolClaimArgs
      property slot_index : UInt32

      def initialize(@slot_index)
      end
    end

    struct VPoolFlushArgs
      property slot_index : UInt32

      def initialize(@slot_index)
      end
    end

    # ==========================================================================
    # Computed Types
    # ==========================================================================

    struct VPoolStats
      property current_price : BigInt
      property market_cap_sol : BigInt
      property graduation_progress : Float64
      property can_graduate : Bool
      property graduation_target : BigInt
      property churn_ratio : Float64
      property age_seconds : Int64
      property is_stale : Bool

      def initialize(
        @current_price,
        @market_cap_sol,
        @graduation_progress,
        @can_graduate,
        @graduation_target,
        @churn_ratio,
        @age_seconds,
        @is_stale
      )
      end
    end

    struct BuySimulation
      property tokens_out : BigInt
      property new_price : BigInt
      property price_impact : Float64
      property fee : BigInt

      def initialize(@tokens_out, @new_price, @price_impact, @fee)
      end
    end

    struct SellSimulation
      property sol_out : BigInt
      property new_price : BigInt
      property price_impact : Float64
      property fee : BigInt

      def initialize(@sol_out, @new_price, @price_impact, @fee)
      end
    end
  end
end
