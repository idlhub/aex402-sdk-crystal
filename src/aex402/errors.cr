module AeX402
  # ============================================================================
  # Error Codes - matches C error definitions in aex402.c
  # ============================================================================

  enum ErrorCode
    Paused               = 6000
    InvalidAmp           = 6001
    MathOverflow         = 6002
    ZeroAmount           = 6003
    SlippageExceeded     = 6004
    InvalidInvariant     = 6005
    InsufficientLiquidity = 6006
    VaultMismatch        = 6007
    Expired              = 6008
    AlreadyInitialized   = 6009
    Unauthorized         = 6010
    RampConstraint       = 6011
    Locked               = 6012
    FarmingError         = 6013
    InvalidOwner         = 6014
    InvalidDiscriminator = 6015
    CpiFailed            = 6016
    Full                 = 6017
    CircuitBreaker       = 6018
    OracleError          = 6019
    RateLimit            = 6020
    GovernanceError      = 6021
    OrderError           = 6022
    TickError            = 6023
    RangeError           = 6024
    FlashError           = 6025
    Cooldown             = 6026
    MevProtection        = 6027
    StaleData            = 6028
    BiasError            = 6029
    DurationError        = 6030
  end

  # Error messages for each error code
  ERROR_MESSAGES = {
    ErrorCode::Paused               => "Pool is paused",
    ErrorCode::InvalidAmp           => "Invalid amplification coefficient",
    ErrorCode::MathOverflow         => "Math overflow",
    ErrorCode::ZeroAmount           => "Zero amount",
    ErrorCode::SlippageExceeded     => "Slippage exceeded",
    ErrorCode::InvalidInvariant     => "Invalid invariant or PDA mismatch",
    ErrorCode::InsufficientLiquidity => "Insufficient liquidity",
    ErrorCode::VaultMismatch        => "Vault mismatch",
    ErrorCode::Expired              => "Expired or ended",
    ErrorCode::AlreadyInitialized   => "Already initialized",
    ErrorCode::Unauthorized         => "Unauthorized",
    ErrorCode::RampConstraint       => "Ramp constraint violated",
    ErrorCode::Locked               => "Tokens are locked",
    ErrorCode::FarmingError         => "Farming error",
    ErrorCode::InvalidOwner         => "Invalid account owner",
    ErrorCode::InvalidDiscriminator => "Invalid account discriminator",
    ErrorCode::CpiFailed            => "CPI call failed",
    ErrorCode::Full                 => "Orderbook/registry is full",
    ErrorCode::CircuitBreaker       => "Circuit breaker triggered",
    ErrorCode::OracleError          => "Oracle price validation failed",
    ErrorCode::RateLimit            => "Rate limit exceeded",
    ErrorCode::GovernanceError      => "Governance error",
    ErrorCode::OrderError           => "Orderbook error",
    ErrorCode::TickError            => "Invalid tick",
    ErrorCode::RangeError           => "Invalid price range",
    ErrorCode::FlashError           => "Flash loan error",
    ErrorCode::Cooldown             => "Cooldown period not elapsed",
    ErrorCode::MevProtection        => "MEV protection triggered",
    ErrorCode::StaleData            => "Stale data",
    ErrorCode::BiasError            => "ML bias error",
    ErrorCode::DurationError        => "Invalid duration",
  }

  # Get error message for a given error code
  def self.error_message(code : ErrorCode) : String
    ERROR_MESSAGES[code]? || "Unknown error"
  end

  # Custom exception for AeX402 errors
  class AeX402Error < Exception
    getter code : ErrorCode

    def initialize(@code : ErrorCode)
      super(AeX402.error_message(@code))
    end

    def initialize(@code : ErrorCode, message : String)
      super("#{AeX402.error_message(@code)}: #{message}")
    end
  end

  # Parse error exception
  class ParseError < Exception
  end

  # Math computation error
  class MathError < Exception
  end
end
