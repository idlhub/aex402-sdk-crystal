module AeX402
  # ============================================================================
  # Instruction Builders Module
  # ============================================================================

  module Instructions
    extend self

    # ========================================================================
    # Buffer Writing Helpers
    # ========================================================================

    private def write_u8(buf : Bytes, value : UInt8, offset : Int32) : Int32
      buf[offset] = value
      offset + 1
    end

    private def write_u64_le(buf : Bytes, value : UInt64, offset : Int32) : Int32
      8.times do |i|
        buf[offset + i] = ((value >> (i * 8)) & 0xFF).to_u8
      end
      offset + 8
    end

    private def write_i64_le(buf : Bytes, value : Int64, offset : Int32) : Int32
      write_u64_le(buf, value.to_u64!, offset)
    end

    # ========================================================================
    # Account Meta - represents a Solana account in an instruction
    # ========================================================================

    struct AccountMeta
      property pubkey : String
      property is_signer : Bool
      property is_writable : Bool

      def initialize(@pubkey : String, @is_signer : Bool, @is_writable : Bool)
      end
    end

    # ========================================================================
    # Instruction - represents a Solana instruction
    # ========================================================================

    struct Instruction
      property program_id : String
      property accounts : Array(AccountMeta)
      property data : Bytes

      def initialize(@program_id : String, @accounts : Array(AccountMeta), @data : Bytes)
      end
    end

    # ========================================================================
    # Pool Creation Instructions
    # ========================================================================

    # Create a new 2-token pool
    def create_pool(
      pool : String,
      mint0 : String,
      mint1 : String,
      authority : String,
      args : CreatePoolArgs
    ) : Instruction
      data = Bytes.new(17)
      Discriminators::CREATEPOOL.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.amp, offset)
      write_u8(data, args.bump, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(mint0, false, false),
        AccountMeta.new(mint1, false, false),
        AccountMeta.new(authority, true, true),
        AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Initialize token 0 vault
    def init_t0_vault(
      pool : String,
      vault : String,
      authority : String
    ) : Instruction
      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault, false, false),
        AccountMeta.new(authority, true, false),
        AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::INITT0V.dup)
    end

    # Initialize token 1 vault
    def init_t1_vault(
      pool : String,
      vault : String,
      authority : String
    ) : Instruction
      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault, false, false),
        AccountMeta.new(authority, true, false),
        AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::INITT1V.dup)
    end

    # Initialize LP mint
    def init_lp_mint(
      pool : String,
      lp_mint : String,
      authority : String
    ) : Instruction
      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(lp_mint, false, false),
        AccountMeta.new(authority, true, false),
        AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::INITLPM.dup)
    end

    # ========================================================================
    # Swap Instructions
    # ========================================================================

    # Generic swap with from/to indices
    def swap(
      pool : String,
      vault0 : String,
      vault1 : String,
      user_token0 : String,
      user_token1 : String,
      user : String,
      args : SwapArgs,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(34)
      Discriminators::SWAP.copy_to(data)
      offset = 8
      offset = write_u8(data, args.from, offset)
      offset = write_u8(data, args.to, offset)
      offset = write_u64_le(data, args.amount_in, offset)
      offset = write_u64_le(data, args.min_out, offset)
      write_i64_le(data, args.deadline, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault0, false, true),
        AccountMeta.new(vault1, false, true),
        AccountMeta.new(user_token0, false, true),
        AccountMeta.new(user_token1, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Swap token 0 to token 1
    def swap_t0_t1(
      pool : String,
      vault0 : String,
      vault1 : String,
      user_token0 : String,
      user_token1 : String,
      user : String,
      args : SwapSimpleArgs,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(24)
      Discriminators::SWAPT0T1.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.amount_in, offset)
      write_u64_le(data, args.min_out, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault0, false, true),
        AccountMeta.new(vault1, false, true),
        AccountMeta.new(user_token0, false, true),
        AccountMeta.new(user_token1, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Swap token 1 to token 0
    def swap_t1_t0(
      pool : String,
      vault0 : String,
      vault1 : String,
      user_token0 : String,
      user_token1 : String,
      user : String,
      args : SwapSimpleArgs,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(24)
      Discriminators::SWAPT1T0.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.amount_in, offset)
      write_u64_le(data, args.min_out, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault0, false, true),
        AccountMeta.new(vault1, false, true),
        AccountMeta.new(user_token0, false, true),
        AccountMeta.new(user_token1, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # N-token pool swap
    def swap_n(
      pool : String,
      vault_in : String,
      vault_out : String,
      user_token_in : String,
      user_token_out : String,
      user : String,
      args : SwapNArgs,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(26)
      Discriminators::SWAPN.copy_to(data)
      offset = 8
      offset = write_u8(data, args.from_idx, offset)
      offset = write_u8(data, args.to_idx, offset)
      offset = write_u64_le(data, args.amount_in, offset)
      write_u64_le(data, args.min_out, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault_in, false, true),
        AccountMeta.new(vault_out, false, true),
        AccountMeta.new(user_token_in, false, true),
        AccountMeta.new(user_token_out, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # ========================================================================
    # Liquidity Instructions
    # ========================================================================

    # Add liquidity to 2-token pool
    def add_liquidity(
      pool : String,
      vault0 : String,
      vault1 : String,
      lp_mint : String,
      user_token0 : String,
      user_token1 : String,
      user_lp : String,
      user : String,
      args : AddLiqArgs,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(32)
      Discriminators::ADDLIQ.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.amount0, offset)
      offset = write_u64_le(data, args.amount1, offset)
      write_u64_le(data, args.min_lp, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault0, false, true),
        AccountMeta.new(vault1, false, true),
        AccountMeta.new(lp_mint, false, true),
        AccountMeta.new(user_token0, false, true),
        AccountMeta.new(user_token1, false, true),
        AccountMeta.new(user_lp, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Single-sided add liquidity
    def add_liquidity_1(
      pool : String,
      vault_in : String,
      lp_mint : String,
      user_token_in : String,
      user_lp : String,
      user : String,
      args : AddLiq1Args,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(24)
      Discriminators::ADDLIQ1.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.amount_in, offset)
      write_u64_le(data, args.min_lp, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault_in, false, true),
        AccountMeta.new(lp_mint, false, true),
        AccountMeta.new(user_token_in, false, true),
        AccountMeta.new(user_lp, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Remove liquidity from 2-token pool
    def remove_liquidity(
      pool : String,
      vault0 : String,
      vault1 : String,
      lp_mint : String,
      user_token0 : String,
      user_token1 : String,
      user_lp : String,
      user : String,
      args : RemLiqArgs,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(32)
      Discriminators::REMLIQ.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.lp_amount, offset)
      offset = write_u64_le(data, args.min0, offset)
      write_u64_le(data, args.min1, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault0, false, true),
        AccountMeta.new(vault1, false, true),
        AccountMeta.new(lp_mint, false, true),
        AccountMeta.new(user_token0, false, true),
        AccountMeta.new(user_token1, false, true),
        AccountMeta.new(user_lp, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # ========================================================================
    # Admin Instructions
    # ========================================================================

    # Set pool pause state
    def set_pause(
      pool : String,
      authority : String,
      paused : Bool
    ) : Instruction
      data = Bytes.new(9)
      Discriminators::SETPAUSE.copy_to(data)
      data[8] = paused ? 1_u8 : 0_u8

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(authority, true, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Update swap fee
    def update_fee(
      pool : String,
      authority : String,
      args : UpdateFeeArgs
    ) : Instruction
      data = Bytes.new(16)
      Discriminators::UPDFEE.copy_to(data)
      write_u64_le(data, args.fee_bps, 8)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(authority, true, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Withdraw admin fees
    def withdraw_fee(
      pool : String,
      vault0 : String,
      vault1 : String,
      dest0 : String,
      dest1 : String,
      authority : String,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(vault0, false, true),
        AccountMeta.new(vault1, false, true),
        AccountMeta.new(dest0, false, true),
        AccountMeta.new(dest1, false, true),
        AccountMeta.new(authority, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::WDRAWFEE.dup)
    end

    # Commit amp change (starts timelock)
    def commit_amp(
      pool : String,
      authority : String,
      args : CommitAmpArgs
    ) : Instruction
      data = Bytes.new(16)
      Discriminators::COMMITAMP.copy_to(data)
      write_u64_le(data, args.target_amp, 8)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(authority, true, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Ramp amp over duration
    def ramp_amp(
      pool : String,
      authority : String,
      args : RampAmpArgs
    ) : Instruction
      data = Bytes.new(24)
      Discriminators::RAMPAMP.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.target_amp, offset)
      write_i64_le(data, args.duration, offset)

      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(authority, true, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Stop amp ramping
    def stop_ramp(
      pool : String,
      authority : String
    ) : Instruction
      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(authority, true, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::STOPRAMP.dup)
    end

    # Initiate authority transfer
    def init_auth_transfer(
      pool : String,
      authority : String,
      new_authority : String
    ) : Instruction
      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(authority, true, false),
        AccountMeta.new(new_authority, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::INITAUTH.dup)
    end

    # Complete authority transfer
    def complete_auth_transfer(
      pool : String,
      new_authority : String
    ) : Instruction
      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(new_authority, true, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::COMPLAUTH.dup)
    end

    # Cancel authority transfer
    def cancel_auth_transfer(
      pool : String,
      authority : String
    ) : Instruction
      accounts = [
        AccountMeta.new(pool, false, true),
        AccountMeta.new(authority, true, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::CANCELAUTH.dup)
    end

    # ========================================================================
    # Farming Instructions
    # ========================================================================

    # Create farming period
    def create_farm(
      farm : String,
      pool : String,
      reward_mint : String,
      authority : String,
      args : CreateFarmArgs
    ) : Instruction
      data = Bytes.new(32)
      Discriminators::CREATEFARM.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.reward_rate, offset)
      offset = write_i64_le(data, args.start_time, offset)
      write_i64_le(data, args.end_time, offset)

      accounts = [
        AccountMeta.new(farm, false, true),
        AccountMeta.new(pool, false, false),
        AccountMeta.new(reward_mint, false, false),
        AccountMeta.new(authority, true, true),
        AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Stake LP tokens
    def stake_lp(
      user_position : String,
      farm : String,
      user_lp : String,
      lp_vault : String,
      user : String,
      args : StakeArgs,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(16)
      Discriminators::STAKELP.copy_to(data)
      write_u64_le(data, args.amount, 8)

      accounts = [
        AccountMeta.new(user_position, false, true),
        AccountMeta.new(farm, false, true),
        AccountMeta.new(user_lp, false, true),
        AccountMeta.new(lp_vault, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Unstake LP tokens
    def unstake_lp(
      user_position : String,
      farm : String,
      user_lp : String,
      lp_vault : String,
      user : String,
      args : StakeArgs,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      data = Bytes.new(16)
      Discriminators::UNSTAKELP.copy_to(data)
      write_u64_le(data, args.amount, 8)

      accounts = [
        AccountMeta.new(user_position, false, true),
        AccountMeta.new(farm, false, true),
        AccountMeta.new(user_lp, false, true),
        AccountMeta.new(lp_vault, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Claim farming rewards
    def claim_farm(
      user_position : String,
      farm : String,
      pool : String,
      reward_vault : String,
      user_reward : String,
      user : String,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      accounts = [
        AccountMeta.new(user_position, false, true),
        AccountMeta.new(farm, false, true),
        AccountMeta.new(pool, false, false),
        AccountMeta.new(reward_vault, false, true),
        AccountMeta.new(user_reward, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::CLAIMFARM.dup)
    end

    # ========================================================================
    # Lottery Instructions
    # ========================================================================

    # Create lottery for pool
    def create_lottery(
      lottery : String,
      pool : String,
      lottery_vault : String,
      authority : String,
      args : CreateLotteryArgs
    ) : Instruction
      data = Bytes.new(24)
      Discriminators::CREATELOT.copy_to(data)
      offset = 8
      offset = write_u64_le(data, args.ticket_price, offset)
      write_i64_le(data, args.end_time, offset)

      accounts = [
        AccountMeta.new(lottery, false, true),
        AccountMeta.new(pool, false, false),
        AccountMeta.new(lottery_vault, false, false),
        AccountMeta.new(authority, true, false),
        AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Enter lottery
    def enter_lottery(
      lottery : String,
      user_entry : String,
      user : String,
      user_lp : String,
      lottery_vault : String,
      token_program : String = TOKEN_PROGRAM_ID,
      args : EnterLotteryArgs? = nil
    ) : Instruction
      data = Bytes.new(16)
      Discriminators::ENTERLOT.copy_to(data)
      if args
        write_u64_le(data, args.ticket_count, 8)
      end

      accounts = [
        AccountMeta.new(lottery, false, true),
        AccountMeta.new(user_entry, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(user_lp, false, true),
        AccountMeta.new(lottery_vault, false, true),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Draw lottery winner
    def draw_lottery(
      lottery : String,
      authority : String,
      recent_slothashes : String,
      args : DrawLotteryArgs
    ) : Instruction
      data = Bytes.new(16)
      Discriminators::DRAWLOT.copy_to(data)
      write_u64_le(data, args.random_seed, 8)

      accounts = [
        AccountMeta.new(lottery, false, true),
        AccountMeta.new(authority, true, false),
        AccountMeta.new(recent_slothashes, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end

    # Claim lottery prize
    def claim_lottery(
      lottery : String,
      user_entry : String,
      user : String,
      user_lp : String,
      lottery_vault : String,
      pool : String,
      token_program : String = TOKEN_PROGRAM_ID
    ) : Instruction
      accounts = [
        AccountMeta.new(lottery, false, true),
        AccountMeta.new(user_entry, false, true),
        AccountMeta.new(user, true, false),
        AccountMeta.new(user_lp, false, true),
        AccountMeta.new(lottery_vault, false, true),
        AccountMeta.new(pool, false, false),
        AccountMeta.new(token_program, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, Discriminators::CLAIMLOT.dup)
    end

    # ========================================================================
    # TWAP Oracle Instruction
    # ========================================================================

    # Get TWAP price
    def get_twap(
      pool : String,
      window : TwapWindow
    ) : Instruction
      data = Bytes.new(9)
      Discriminators::GETTWAP.copy_to(data)
      data[8] = window.value.to_u8

      accounts = [
        AccountMeta.new(pool, false, false),
      ]

      Instruction.new(PROGRAM_ID, accounts, data)
    end
  end
end
