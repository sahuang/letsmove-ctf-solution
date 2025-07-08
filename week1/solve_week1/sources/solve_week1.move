module solve_week1::solve{
    use week1::challenge::{get_flag, Challenge};
    use std::string;
    use std::bcs;
    use std::hash::sha3_256;
    use sui::random::Random;

    #[allow(lint(public_random))]
    public entry fun solve_get_flag(
        challenge: &mut Challenge, // 0x73399bba017233dae87f2a47c99d8b3fd93136dcef8b475149e85a9a9a994cfd
        rand: &Random, // 0x0000000000000000000000000000000000000000000000000000000000000008
        ctx: &mut TxContext) {
        // Check 1: Score
        let secret = b"Letsmovectf_week1";
        let secret_hash = sha3_256(secret);
        let expected_score = (((*vector::borrow(&secret_hash, 0) as u64) << 24) |
                             ((*vector::borrow(&secret_hash, 1) as u64) << 16) |
                             ((*vector::borrow(&secret_hash, 2) as u64) << 8) |
                             (*vector::borrow(&secret_hash, 3) as u64));
        // Check 2: compare_hash_prefix
        let guess = b"G16";
        let mut guess_data = guess;
        vector::append(&mut guess_data, secret);
        // Check 3
        let mut bcs_input = bcs::to_bytes(&string::utf8(b"Letsmovectf_week1"));
        let github_id = string::utf8(b"5a0ae6ad-1d31-4ebb-b67e-29552b0ab341");
        vector::append(&mut bcs_input, *string::as_bytes(&github_id));
        let expected_hash = sha3_256(bcs_input);
        // Check 4&5
        let seed = vector::length(&secret) * 2;
        let expected_magic = expected_score % 1000 + seed;

        get_flag(expected_score, guess, expected_hash, github_id, expected_magic, seed, challenge, rand, ctx);
    }
}