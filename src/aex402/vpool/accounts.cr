module AeX402
  module VPool
    # ==========================================================================
    # Virtual Pool Account Parsing
    # ==========================================================================

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

      private def read_string(data : Bytes, offset : Int32, max_len : Int32) : String
        # Read length-prefixed or null-terminated string
        end_idx = offset
        while end_idx < offset + max_len && data[end_idx] != 0
          end_idx += 1
        end
        String.new(data[offset, end_idx - offset])
      end

      # ========================================================================
      # Global Header Parsing
      # ========================================================================

      def parse_global_header(data : Bytes) : GlobalHeader?
        return nil if data.size < HEADER_SIZE

        disc = data[0, 8]
        return nil unless disc == AccountDiscriminators::GLOBAL_HEADER

        offset = 8

        num_slots = read_u32_le(data, offset); offset += 4
        next_pool_id = read_u32_le(data, offset); offset += 4
        fee_balance = read_u64_le(data, offset); offset += 8
        total_volume = read_u64_le(data, offset); offset += 8
        active_pools = read_u32_le(data, offset); offset += 4
        graduated_count = read_u32_le(data, offset); offset += 4
        flushed_count = read_u32_le(data, offset); offset += 4

        GlobalHeader.new(
          discriminator: disc.dup,
          num_slots: num_slots,
          next_pool_id: next_pool_id,
          fee_balance: fee_balance,
          total_volume: total_volume,
          active_pools: active_pools,
          graduated_count: graduated_count,
          flushed_count: flushed_count
        )
      end

      # ========================================================================
      # VPoolSlot Parsing
      # ========================================================================

      def parse_vpool_slot(data : Bytes, slot_index : UInt32) : VPoolSlot?
        # Calculate offset in global PDA
        slot_offset = HEADER_SIZE + slot_index.to_i32 * SLOT_SIZE
        return nil if data.size < slot_offset + SLOT_SIZE

        slot_data = data[slot_offset, SLOT_SIZE]
        parse_vpool_slot_data(slot_data, slot_index)
      end

      def parse_vpool_slot_data(data : Bytes, slot_index : UInt32 = 0_u32) : VPoolSlot?
        return nil if data.size < SLOT_HEADER_SIZE

        offset = 0

        status_val = read_u8(data, offset); offset += 1
        status = SlotStatus.new(status_val.to_i32)

        pool_id = read_u32_le(data, offset); offset += 4
        creator = read_pubkey(data, offset); offset += 32

        name = read_string(data, offset, 32); offset += 32
        symbol = read_string(data, offset, 8); offset += 8
        uri = read_string(data, offset, 128); offset += 128

        base_price = BigInt.new(read_u64_le(data, offset)); offset += 8
        slope = BigInt.new(read_u64_le(data, offset)); offset += 8
        total_supply = BigInt.new(read_u64_le(data, offset)); offset += 8
        tokens_sold = BigInt.new(read_u64_le(data, offset)); offset += 8
        sol_raised = BigInt.new(read_u64_le(data, offset)); offset += 8
        total_buy_sol = BigInt.new(read_u64_le(data, offset)); offset += 8
        total_sell_sol = BigInt.new(read_u64_le(data, offset)); offset += 8

        created_at = read_i64_le(data, offset); offset += 8
        last_trade_at = read_i64_le(data, offset); offset += 8

        real_pool = read_pubkey(data, offset); offset += 32
        real_mint = read_pubkey(data, offset); offset += 32

        creator_unclaimed = BigInt.new(read_u64_le(data, offset)); offset += 8
        creator_last_claim = read_i64_le(data, offset); offset += 8

        graduation_triggerer = read_pubkey(data, offset); offset += 32

        holder_count = read_u32_le(data, offset); offset += 4
        mint_bump = read_u8(data, offset); offset += 1

        # Hash positions (8 bytes)
        hash_positions = Array(UInt8).new(8) do |i|
          read_u8(data, offset + i)
        end
        offset += 8

        # Padding to align to SLOT_HEADER_SIZE
        offset = SLOT_HEADER_SIZE

        # Parse holders
        holders = Array(VPoolHolder).new
        holder_count.times do |i|
          holder_offset = offset + i.to_i32 * HOLDER_SIZE
          break if holder_offset + HOLDER_SIZE > data.size

          wallet_hash = data[holder_offset, 6].dup
          balance = read_u8(data, holder_offset + 6)

          holders << VPoolHolder.new(wallet_hash, balance)
        end

        VPoolSlot.new(
          slot_index: slot_index,
          status: status,
          pool_id: pool_id,
          creator: creator,
          name: name,
          symbol: symbol,
          uri: uri,
          base_price: base_price,
          slope: slope,
          total_supply: total_supply,
          tokens_sold: tokens_sold,
          sol_raised: sol_raised,
          total_buy_sol: total_buy_sol,
          total_sell_sol: total_sell_sol,
          created_at: created_at,
          last_trade_at: last_trade_at,
          real_pool: real_pool,
          real_mint: real_mint,
          creator_unclaimed: creator_unclaimed,
          creator_last_claim: creator_last_claim,
          graduation_triggerer: graduation_triggerer,
          holder_count: holder_count,
          mint_bump: mint_bump,
          hash_positions: hash_positions,
          holders: holders
        )
      end

      # ========================================================================
      # VPoolClaimPDA Parsing
      # ========================================================================

      def parse_vpool_claim(data : Bytes) : VPoolClaimPDA?
        return nil if data.size < 96

        disc = data[0, 8]
        return nil unless disc == AccountDiscriminators::VPOOL_CLAIM

        offset = 8

        pool_id = read_u32_le(data, offset); offset += 4
        offset += 4 # padding
        wallet = read_pubkey(data, offset); offset += 32
        unclaimed = BigInt.new(read_u64_le(data, offset)); offset += 8
        claimed = BigInt.new(read_u64_le(data, offset)); offset += 8
        last_claim = read_i64_le(data, offset); offset += 8

        VPoolClaimPDA.new(
          discriminator: disc.dup,
          pool_id: pool_id,
          wallet: wallet,
          unclaimed: unclaimed,
          claimed: claimed,
          last_claim: last_claim
        )
      end

      # ========================================================================
      # FarmingState Parsing
      # ========================================================================

      def parse_farming_state(data : Bytes) : FarmingState?
        return nil if data.size < 200

        disc = data[0, 8]
        return nil unless disc == AccountDiscriminators::FARMING_STATE

        offset = 8

        pool = read_pubkey(data, offset); offset += 32
        graduated_mint = read_pubkey(data, offset); offset += 32

        # Top 10 buyer hashes (6 bytes each)
        top_hashes = Array(Bytes).new(10) do |i|
          data[offset + i * 6, 6].dup
        end
        offset += 60

        # Top 10 amounts (8 bytes each)
        top_amounts = Array(BigInt).new(10) do |i|
          BigInt.new(read_u64_le(data, offset + i * 8))
        end
        offset += 80

        commitment = data[offset, 32].dup; offset += 32
        committer = read_pubkey(data, offset); offset += 32
        commit_window = read_u32_le(data, offset); offset += 4
        offset += 4 # padding

        deposit_mint = read_pubkey(data, offset); offset += 32
        deposit_amount = BigInt.new(read_u64_le(data, offset)); offset += 8

        farming_window_start = read_i64_le(data, offset); offset += 8
        farming_end = read_i64_le(data, offset); offset += 8
        farming_rewards_left = BigInt.new(read_u64_le(data, offset)); offset += 8

        hash_positions = Array(UInt8).new(8) do |i|
          read_u8(data, offset + i)
        end
        offset += 8

        # Recent committers (10 x 32 bytes)
        recent_committers = Array(Pubkey).new(10) do |i|
          read_pubkey(data, offset + i * 32)
        end
        offset += 320

        cooldown_head = read_u8(data, offset)

        FarmingState.new(
          discriminator: disc.dup,
          pool: pool,
          graduated_mint: graduated_mint,
          top_hashes: top_hashes,
          top_amounts: top_amounts,
          commitment: commitment,
          committer: committer,
          commit_window: commit_window,
          deposit_mint: deposit_mint,
          deposit_amount: deposit_amount,
          farming_window_start: farming_window_start,
          farming_end: farming_end,
          farming_rewards_left: farming_rewards_left,
          hash_positions: hash_positions,
          recent_committers: recent_committers,
          cooldown_head: cooldown_head
        )
      end

      # ========================================================================
      # PDA Derivation
      # ========================================================================

      def derive_global_pda(program_id : String = PROGRAM_ID) : PDA::DerivedAddress?
        PDA.find_program_address(
          ["global_vpool".to_slice],
          program_id
        )
      end

      def derive_mint_pda(pool_id : UInt32, program_id : String = PROGRAM_ID) : PDA::DerivedAddress?
        pool_id_buf = Bytes.new(4)
        pool_id_buf[0] = (pool_id & 0xFF).to_u8
        pool_id_buf[1] = ((pool_id >> 8) & 0xFF).to_u8
        pool_id_buf[2] = ((pool_id >> 16) & 0xFF).to_u8
        pool_id_buf[3] = ((pool_id >> 24) & 0xFF).to_u8

        PDA.find_program_address(
          ["vpmint".to_slice, pool_id_buf],
          program_id
        )
      end

      def derive_claim_pda(
        pool_id : UInt32,
        wallet : String,
        program_id : String = PROGRAM_ID
      ) : PDA::DerivedAddress?
        derive_claim_pda(pool_id, Pubkey.new(wallet), program_id)
      end

      def derive_claim_pda(
        pool_id : UInt32,
        wallet : Pubkey,
        program_id : String = PROGRAM_ID
      ) : PDA::DerivedAddress?
        pool_id_buf = Bytes.new(4)
        pool_id_buf[0] = (pool_id & 0xFF).to_u8
        pool_id_buf[1] = ((pool_id >> 8) & 0xFF).to_u8
        pool_id_buf[2] = ((pool_id >> 16) & 0xFF).to_u8
        pool_id_buf[3] = ((pool_id >> 24) & 0xFF).to_u8

        PDA.find_program_address(
          ["vpclaim".to_slice, pool_id_buf, wallet.bytes],
          program_id
        )
      end

      def derive_farming_state_pda(
        amm_pool : String,
        program_id : String = PROGRAM_ID
      ) : PDA::DerivedAddress?
        derive_farming_state_pda(Pubkey.new(amm_pool), program_id)
      end

      def derive_farming_state_pda(
        amm_pool : Pubkey,
        program_id : String = PROGRAM_ID
      ) : PDA::DerivedAddress?
        PDA.find_program_address(
          ["farmstate".to_slice, amm_pool.bytes],
          program_id
        )
      end
    end
  end
end
