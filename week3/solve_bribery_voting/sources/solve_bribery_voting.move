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