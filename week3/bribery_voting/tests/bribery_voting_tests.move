#[test_only]
module bribery_voting::bribery_voting_tests;

use sui::test_scenario::{Self as ts};
use bribery_voting::ballot::{Self, Ballot};
use bribery_voting::candidate::{Self, Candidate};

#[test]
fun test_bribery_voting() {
    let sender = @0xcafe;
    let mut s = ts::begin(sender);

    s.next_tx(sender);
    ballot::get_ballot(s.ctx());
    candidate::register(s.ctx());

    s.next_tx(sender);
    let mut candidate = s.take_shared<Candidate>();
    let mut ballot = s.take_from_sender<Ballot>();
    let mut request = ballot.request_vote();
    assert!(candidate.total_votes() == 0);
    candidate.vote(&mut request, 10);
    assert!(candidate.total_votes() == 10);
    ballot.finish_voting(request);
    assert!(ballot.voted().get(&sender) == 10);
    ts::return_shared(candidate);
    s.return_to_sender(ballot);

    s.end();
}
