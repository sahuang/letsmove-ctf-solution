module bribery_voting::ballot;

use sui::vec_map::{Self, VecMap};

/// Object

public struct Ballot has key {
    id: UID,
    voted: VecMap<address, u64>,
    has_voted: bool,
}

/// Hot Potato

public struct VoteRequest {
    voting_power: u64,
    voted: VecMap<address, u64>,
}

/// Public Funs

public fun get_ballot(ctx: &mut TxContext): ID {
    let ballot = Ballot {
        id: object::new(ctx),
        voted: vec_map::empty(),
        has_voted: false,
    };
    let ballot_id = ballot.id();
    transfer::transfer(ballot, ctx.sender());
    ballot_id
}

public fun request_vote(ballot: &mut Ballot): VoteRequest {
    assert!(ballot.voted.is_empty());
    assert!(!ballot.has_voted);
    ballot.has_voted = true;
    VoteRequest {
        voting_power: default_voting_power(),
        voted: vec_map::empty(),
    }
}

public fun finish_voting(ballot: &mut Ballot, request: VoteRequest) {
    let VoteRequest {
        voting_power: _,
        voted,
    } = request;
    let (candidates, votes) = voted.into_keys_values();
    candidates.zip_do!(votes, |c, v| {
        let ballot_voted = &mut ballot.voted;
        let already_voted = ballot_voted.try_get(&c);
        if (already_voted.is_some()) {
            *ballot_voted.get_mut(&c) = already_voted.destroy_some() + v;
        } else {
            ballot_voted.insert(c, v);
        }
    });
}

/// Package Funs

public(package) fun deduct_voting_power(
    request: &mut VoteRequest,
    candidate: address,
    amount: u64,
): u64 {
    let change = request.voting_power.min(amount);
    request.voting_power = request.voting_power - change;
    if (request.voted.contains(&candidate)) {
        let v = request.voted.get_mut(&candidate);
        *v = *v + change;
    } else {
        request.voted.insert(candidate, change);
    };
    change
}

/// Getter Funs

public fun id(ballot: &Ballot): ID {
    object::id(ballot)
}

public fun default_voting_power(): u64 { 10 }

public fun voted(ballot: &Ballot): &VecMap<address, u64> {
    &ballot.voted
}
