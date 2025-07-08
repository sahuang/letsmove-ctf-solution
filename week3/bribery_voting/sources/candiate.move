
module bribery_voting::candidate;

use bribery_voting::ballot::{VoteRequest};

public struct Candidate has key {
    id: UID,
	account: address,
	total_votes: u64,
}

public fun register(
    ctx: &mut TxContext,
) {
    let candidate = Candidate {
        id: object::new(ctx),
        account: ctx.sender(),
        total_votes: 0,
    };
    transfer::share_object(candidate);
}

public fun amend_account(
    candiate: &mut Candidate,
    account: address,
) {
    candiate.account = account;
}

public fun vote(
    candiate: &mut Candidate,
    request: &mut VoteRequest,
    amount: u64,
) {
    let gain_votes = request.deduct_voting_power(candiate.account, amount);
    candiate.total_votes = candiate.total_votes + gain_votes;
}

/// Getter Funs

public fun account(candiate: &Candidate): address {
    candiate.account
}

public fun total_votes(candiate: &Candidate): u64 {
    candiate.total_votes
}
