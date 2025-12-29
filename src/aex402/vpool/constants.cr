module AeX402
  module VPool
    # ==========================================================================
    # Virtual Pool Constants
    # ==========================================================================

    # Price precision scale (1e9)
    SCALE = BigInt.new("1000000000")

    # Minimum buy amount (0.001 SOL in lamports)
    MIN_BUY = BigInt.new("1000000")

    # Minimum sell amount (1 token)
    MIN_SELL = BigInt.new(1)

    # ==========================================================================
    # Fee Constants
    # ==========================================================================

    # Total fee (1% = 100 bps)
    VPOOL_FEE_BPS = 100

    # Fee split to global balance (0.5%)
    FEE_BALANCE_BPS = 50

    # Fee kept in pool (0.5%)
    FEE_POOL_BPS = 50

    # Graduation reward to triggerer (0.1%)
    GRADUATION_REWARD_BPS = 10

    # Flush reward to flusher (0.1%)
    FLUSH_REWARD_BPS = 10

    # Pool creation fee (0.1 SOL in lamports)
    VPOOL_CREATION_FEE = BigInt.new("100000000")

    # ==========================================================================
    # Graduation Constants
    # ==========================================================================

    # Base graduation target (100 SOL in lamports)
    TARGET_BASE_SOL = BigInt.new("100000000000")

    # Minimum graduation target (10 SOL)
    TARGET_MIN_SOL = BigInt.new("10000000000")

    # Maximum graduation target (200 SOL)
    TARGET_MAX_SOL = BigInt.new("200000000000")

    # Churn penalty per unit (5 SOL)
    CHURN_PENALTY_SOL = BigInt.new("5000000000")

    # ==========================================================================
    # Timing Constants
    # ==========================================================================

    # Time until pool can be flushed (1 hour)
    VPOOL_FLUSH_SECS = 3600

    # Time between vesting claims (1 hour)
    VESTING_HOUR_SECS = 3600

    # Claim all remaining if balance <= this
    VESTING_DUST = 1000

    # ==========================================================================
    # Account Size Constants
    # ==========================================================================

    # Size of one virtual pool slot (10KB)
    SLOT_SIZE = 10240

    # Size of global header
    HEADER_SIZE = 64

    # Size of slot header (before holders array)
    SLOT_HEADER_SIZE = 440

    # Maximum concurrent virtual pools
    MAX_SLOTS = 1024

    # Size of holder entry (packed)
    HOLDER_SIZE = 7

    # Maximum holders per slot
    MAX_HOLDERS_PER_SLOT = (SLOT_SIZE - SLOT_HEADER_SIZE) // HOLDER_SIZE # ~1400

    # Balance quantum (100K tokens per unit)
    TOKEN_QUANTUM = 100000

    # Maximum balance units per holder (2.5% = 250 units)
    MAX_BALANCE_UNITS = 250

    # ==========================================================================
    # Instruction Discriminators
    # ==========================================================================

    module Discriminators
      # Global PDA initialization
      INITGLOBAL = Bytes[0x62, 0x6f, 0x6c, 0x67, 0x74, 0x69, 0x6e, 0x69]

      # Virtual pool operations
      VPCREATE = Bytes[0x65, 0x74, 0x61, 0x65, 0x72, 0x63, 0x70, 0x76]
      VPBUY    = Bytes[0x00, 0x00, 0x00, 0x79, 0x75, 0x62, 0x70, 0x76]
      VPSELL   = Bytes[0x00, 0x00, 0x6c, 0x6c, 0x65, 0x73, 0x70, 0x76]
      VPGRAD   = Bytes[0x00, 0x00, 0x64, 0x61, 0x72, 0x67, 0x70, 0x76]
      VPCLAIM  = Bytes[0x00, 0x6d, 0x69, 0x61, 0x6c, 0x63, 0x70, 0x76]
      CLAIMCRT = Bytes[0x74, 0x72, 0x63, 0x6d, 0x69, 0x61, 0x6c, 0x63]
      VPFLUSH  = Bytes[0x00, 0x68, 0x73, 0x75, 0x6c, 0x66, 0x70, 0x76]

      # Farming operations
      VPFCMT = Bytes[0x00, 0x00, 0x74, 0x63, 0x6d, 0x66, 0x70, 0x76]
      VPFREV = Bytes[0x00, 0x00, 0x76, 0x65, 0x72, 0x66, 0x70, 0x76]
    end

    # ==========================================================================
    # Account Discriminators
    # ==========================================================================

    module AccountDiscriminators
      GLOBAL_HEADER = "GPVOOLS!".to_slice
      VPOOL_CLAIM   = "VPCLAIM!".to_slice
      FARMING_STATE = "FARMSTAT".to_slice
      PCONFIG       = "PCONFIG!".to_slice
    end

    # ==========================================================================
    # Error Codes (reuses AeX402 codes)
    # ==========================================================================

    enum VPoolError
      WalletLimit     = 6020 # 2.5% limit exceeded
      SlotFull        = 6017 # Holder slots full
      NotGraduated    = 6008 # Pool not graduated yet
      AlreadyGraduated = 6009 # Pool already graduated
    end

    VPOOL_ERROR_MESSAGES = {
      VPoolError::WalletLimit     => "Wallet 2.5% limit exceeded",
      VPoolError::SlotFull        => "Holder slots full or no free slot available",
      VPoolError::NotGraduated    => "Virtual pool not yet graduated",
      VPoolError::AlreadyGraduated => "Virtual pool already graduated",
    }
  end
end
