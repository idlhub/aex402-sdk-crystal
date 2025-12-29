module AeX402
  module VPool
    # ==========================================================================
    # Virtual Pool Instruction Builders
    # ==========================================================================

    module Instructions
      extend self

      # ========================================================================
      # Buffer Writing Helpers
      # ========================================================================

      private def write_u8(buf : Bytes, value : UInt8, offset : Int32) : Int32
        buf[offset] = value
        offset + 1
      end

      private def write_u32_le(buf : Bytes, value : UInt32, offset : Int32) : Int32
        buf[offset] = (value & 0xFF).to_u8
        buf[offset + 1] = ((value >> 8) & 0xFF).to_u8
        buf[offset + 2] = ((value >> 16) & 0xFF).to_u8
        buf[offset + 3] = ((value >> 24) & 0xFF).to_u8
        offset + 4
      end

      private def write_u64_le(buf : Bytes, value : UInt64, offset : Int32) : Int32
        8.times do |i|
          buf[offset + i] = ((value >> (i * 8)) & 0xFF).to_u8
        end
        offset + 8
      end

      private def write_bigint_le(buf : Bytes, value : BigInt, offset : Int32) : Int32
        write_u64_le(buf, value.to_u64, offset)
      end

      private def write_string(buf : Bytes, value : String, offset : Int32, max_len : Int32) : Int32
        bytes = value.to_slice
        copy_len = {bytes.size, max_len}.min
        bytes[0, copy_len].copy_to(buf[offset, copy_len])
        offset + max_len
      end

      # ========================================================================
      # Initialize Global PDA
      # ========================================================================

      def init_global(
        global_pda : String,
        payer : String
      ) : AeX402::Instructions::Instruction
        accounts = [
          AeX402::Instructions::AccountMeta.new(global_pda, false, true),
          AeX402::Instructions::AccountMeta.new(payer, true, true),
          AeX402::Instructions::AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, Discriminators::INITGLOBAL.dup)
      end

      # ========================================================================
      # Create Virtual Pool
      # ========================================================================

      def vp_create(
        global_pda : String,
        creator : String,
        args : CreateVPoolArgs
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + name(32) + symbol(8) + uri(128) + base_price(8) + slope(8) + total_supply(8)
        data = Bytes.new(8 + 32 + 8 + 128 + 8 + 8 + 8)
        Discriminators::VPCREATE.copy_to(data)

        offset = 8
        offset = write_string(data, args.name, offset, 32)
        offset = write_string(data, args.symbol, offset, 8)
        offset = write_string(data, args.uri, offset, 128)
        offset = write_bigint_le(data, args.base_price, offset)
        offset = write_bigint_le(data, args.slope, offset)
        write_bigint_le(data, args.total_supply, offset)

        accounts = [
          AeX402::Instructions::AccountMeta.new(global_pda, false, true),
          AeX402::Instructions::AccountMeta.new(creator, true, true),
          AeX402::Instructions::AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end

      # ========================================================================
      # Buy Tokens
      # ========================================================================

      def vp_buy(
        global_pda : String,
        buyer : String,
        args : VPoolBuyArgs
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + slot_index(4) + sol_amount(8)
        data = Bytes.new(20)
        Discriminators::VPBUY.copy_to(data)

        offset = 8
        offset = write_u32_le(data, args.slot_index, offset)
        write_bigint_le(data, args.sol_amount, offset)

        accounts = [
          AeX402::Instructions::AccountMeta.new(global_pda, false, true),
          AeX402::Instructions::AccountMeta.new(buyer, true, true),
          AeX402::Instructions::AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end

      # ========================================================================
      # Sell Tokens
      # ========================================================================

      def vp_sell(
        global_pda : String,
        seller : String,
        args : VPoolSellArgs
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + slot_index(4) + token_amount(8)
        data = Bytes.new(20)
        Discriminators::VPSELL.copy_to(data)

        offset = 8
        offset = write_u32_le(data, args.slot_index, offset)
        write_bigint_le(data, args.token_amount, offset)

        accounts = [
          AeX402::Instructions::AccountMeta.new(global_pda, false, true),
          AeX402::Instructions::AccountMeta.new(seller, true, true),
          AeX402::Instructions::AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end

      # ========================================================================
      # Graduate Virtual Pool
      # ========================================================================

      def vp_graduate(
        global_pda : String,
        triggerer : String,
        real_pool : String,
        real_mint : String,
        args : VPoolGraduateArgs
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + slot_index(4)
        data = Bytes.new(12)
        Discriminators::VPGRAD.copy_to(data)
        write_u32_le(data, args.slot_index, 8)

        accounts = [
          AeX402::Instructions::AccountMeta.new(global_pda, false, true),
          AeX402::Instructions::AccountMeta.new(triggerer, true, true),
          AeX402::Instructions::AccountMeta.new(real_pool, false, true),
          AeX402::Instructions::AccountMeta.new(real_mint, false, true),
          AeX402::Instructions::AccountMeta.new(TOKEN_PROGRAM_ID, false, false),
          AeX402::Instructions::AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end

      # ========================================================================
      # Claim Vested Tokens
      # ========================================================================

      def vp_claim(
        global_pda : String,
        claim_pda : String,
        claimer : String,
        token_account : String,
        real_mint : String,
        args : VPoolClaimArgs
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + slot_index(4)
        data = Bytes.new(12)
        Discriminators::VPCLAIM.copy_to(data)
        write_u32_le(data, args.slot_index, 8)

        accounts = [
          AeX402::Instructions::AccountMeta.new(global_pda, false, true),
          AeX402::Instructions::AccountMeta.new(claim_pda, false, true),
          AeX402::Instructions::AccountMeta.new(claimer, true, false),
          AeX402::Instructions::AccountMeta.new(token_account, false, true),
          AeX402::Instructions::AccountMeta.new(real_mint, false, true),
          AeX402::Instructions::AccountMeta.new(TOKEN_PROGRAM_ID, false, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end

      # ========================================================================
      # Creator Claim
      # ========================================================================

      def claim_creator(
        global_pda : String,
        creator : String,
        token_account : String,
        real_mint : String,
        slot_index : UInt32
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + slot_index(4)
        data = Bytes.new(12)
        Discriminators::CLAIMCRT.copy_to(data)
        write_u32_le(data, slot_index, 8)

        accounts = [
          AeX402::Instructions::AccountMeta.new(global_pda, false, true),
          AeX402::Instructions::AccountMeta.new(creator, true, false),
          AeX402::Instructions::AccountMeta.new(token_account, false, true),
          AeX402::Instructions::AccountMeta.new(real_mint, false, true),
          AeX402::Instructions::AccountMeta.new(TOKEN_PROGRAM_ID, false, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end

      # ========================================================================
      # Flush Stale Pool
      # ========================================================================

      def vp_flush(
        global_pda : String,
        flusher : String,
        args : VPoolFlushArgs
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + slot_index(4)
        data = Bytes.new(12)
        Discriminators::VPFLUSH.copy_to(data)
        write_u32_le(data, args.slot_index, 8)

        accounts = [
          AeX402::Instructions::AccountMeta.new(global_pda, false, true),
          AeX402::Instructions::AccountMeta.new(flusher, true, true),
          AeX402::Instructions::AccountMeta.new(SYSTEM_PROGRAM_ID, false, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end

      # ========================================================================
      # Farming Commit
      # ========================================================================

      def vp_farming_commit(
        farming_state : String,
        committer : String,
        commitment : Bytes
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + commitment(32)
        data = Bytes.new(40)
        Discriminators::VPFCMT.copy_to(data)
        commitment.copy_to(data[8, 32])

        accounts = [
          AeX402::Instructions::AccountMeta.new(farming_state, false, true),
          AeX402::Instructions::AccountMeta.new(committer, true, true),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end

      # ========================================================================
      # Farming Reveal
      # ========================================================================

      def vp_farming_reveal(
        farming_state : String,
        revealer : String,
        preimage : Bytes
      ) : AeX402::Instructions::Instruction
        # Data: disc(8) + preimage(32)
        data = Bytes.new(40)
        Discriminators::VPFREV.copy_to(data)
        preimage.copy_to(data[8, 32])

        accounts = [
          AeX402::Instructions::AccountMeta.new(farming_state, false, true),
          AeX402::Instructions::AccountMeta.new(revealer, true, false),
        ]

        AeX402::Instructions::Instruction.new(PROGRAM_ID, accounts, data)
      end
    end
  end
end
