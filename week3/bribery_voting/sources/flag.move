module bribery_voting::flag;

use std::string::{String};
use sui::event;

public struct FlagEvent has copy, drop {
    voter: address,
    flag: String,
    github_id: String,
}

public(package) fun emit_flag(
    voter: address,
    flag: String,
    github_id: String,
) {
    event::emit(FlagEvent {
        voter, flag, github_id,
    });
}
