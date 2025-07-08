module bribery_voting::briber;

use std::string::{String};
use sui::table::{Self, Table};
use bribery_voting::ballot::{Ballot};
use bribery_voting::flag;

/// Briber will give you the Flag
/// if you vote enough for Bad Candidate
/// and non for Good Candidate

const REQUIRED_CANDIDATE: address = @0xbad;
const REQUIRED_VOTES: u64 = 21;

public struct Briber has key {
    id: UID,
    given_list: Table<ID, bool>,
}

fun init(ctx: &mut TxContext) {
    let briber = Briber {
        id: object::new(ctx),
        given_list: table::new(ctx),
    };
    transfer::share_object(briber);
}

public fun get_flag(
    briber: &mut Briber,
    ballot: &Ballot,
    github_id: String,
    ctx: &TxContext,
) {
    let ballot_id = ballot.id();
    assert!(!briber.given_list.contains(ballot_id));
    let votes = ballot.voted().try_get(&required_candidate());
    assert!(votes.is_some());
    assert!(votes.destroy_some() >= required_votes());
    flag::emit_flag(ctx.sender(), ballot.id().to_address().to_string(), github_id);
    briber.given_list.add(ballot_id, true);
}


public fun required_candidate(): address {
    REQUIRED_CANDIDATE
}


public fun required_votes(): u64 {
    REQUIRED_VOTES
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
