// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;

contract VotingSystemAttempt{

    enum ElectionType {PRESIDENTIAL, GUBERNATORIAL, SENATE, HOUSE_OF_REPS}
    enum ElectionStage {START_REGISTRATION, START_ELECTION, END_ELECTION}
    enum Party {APV,PVP,LV,PDAPC,NONE}

    address chairPerson;


    constructor(){
        chairPerson = msg.sender;
    }

    struct Candidate{
        string name;
        address addr;
        Party party;
    }

    struct Voter{
        string name;
        address addr;
    }

    struct Election{
        uint electionID;
        ElectionType electionType;
        ElectionStage electionStage;
        address[] candidateAddress;
        uint[] candidateVotes;
        address winner;
        Party winnerParty;
        uint totalVotes;
        uint numOfWinningVotes;
        uint256 startTime;
        uint256 endTime;
    }

    
    mapping(uint => bool) private usedIDs;
    mapping (address=>Voter) voterDetails;
    mapping (address=>Candidate) candidateDetails;
    mapping (uint=>Election) electionDetails;
    mapping(uint => mapping(address => bool)) isEligibleVoter; 
    mapping(uint => mapping(address => bool)) isEligibleCandidate;
    mapping(uint => mapping (address=>bool)) hasVoted;

    modifier chairpersonOnly(){
        require(msg.sender==chairPerson,"ACCESS DENIED: Only the ChairPerson can call this fuction");
        _;
    }

    modifier eligibleVoter(uint id,address addr){
        require(isEligibleVoter[id][addr],"ACTION DENIED: Only eligible voters are permitted ");
        _;
    }
    
    modifier eligibleCandidate(uint id,address addr){
        require(isEligibleCandidate[id][addr],"ACTION DENIED: Only eligible candidates are permitted ");
        _;
    }

    modifier startedElection(uint _electionID){
        require(electionDetails[_electionID].electionStage == ElectionStage.START_ELECTION, "ERROR: Election has not started" );
        require(electionDetails[_electionID].startTime>0,"ERROR: Election has not started");
        _;
    }

    modifier  beforeDeadline(uint _electionID){
        require(block.timestamp < electionDetails[_electionID].endTime, "Election Has Ended");
        _;
    }

    event RegistrationOpen(uint _electionID);
    event VoterRegistered(string _name,address _addr);
    event CandidateRegistered(string _name, address _addr, Party _party);
    event RegistrationClosed(uint _electionID, ElectionType _electionType);
    event StartElection(uint _electionID, ElectionType _electionType);
    event EndElection(uint _electionID, ElectionType _electionType);

    function registerVoter(
        uint _electionID,
        string memory name,
        address addr
    )
    public chairpersonOnly {
        require(usedIDs[_electionID], "ERROR: Election ID does not exist");
        require(electionDetails[_electionID].electionStage==ElectionStage.START_REGISTRATION,"ERROR: Registration is not Open");
        require(isEligibleVoter[_electionID][addr]==false,"ERROR: Voter has already been registered");
        
        voterDetails[addr] = Voter(name,addr);
        isEligibleVoter[_electionID][addr] = true;

        emit VoterRegistered(name, addr);
    }

    function registerCandidate(
        uint _electionID,
        string memory _name,
        address addr,
        Party _party
    )
    public chairpersonOnly{
        require(usedIDs[_electionID], "ERROR: Election ID does not exist");
        require(electionDetails[_electionID].electionStage==ElectionStage.START_REGISTRATION,"ERROR: Registration is not Open");
        require(isEligibleCandidate[_electionID][addr]==false,"ERROR: Candidate has already been registered");

        candidateDetails[addr]= Candidate(_name,addr,_party);
        electionDetails[_electionID].candidateAddress.push(addr);
        electionDetails[_electionID].candidateVotes.push(0);

        isEligibleCandidate[_electionID][addr]=true;

        emit CandidateRegistered(_name, addr, _party);
    }

    function allowElectionRegistration(
        uint _electionID
    )
    public chairpersonOnly{
         require(!usedIDs[_electionID], "ERROR: Election ID already exist");
         require(!(electionDetails[_electionID].startTime>0), "ERROR: Election has started already");
         usedIDs[_electionID]=true;
         electionDetails[_electionID].electionStage = ElectionStage.START_REGISTRATION;

        emit RegistrationOpen(_electionID);
    }

    function initiateElectionData(
        uint _electionID,
        ElectionType _electionType,
        uint _duration 
    )
    public chairpersonOnly{
        require(usedIDs[_electionID], "ERROR: Election ID does not exist");
        require(electionDetails[_electionID].electionStage==ElectionStage.START_REGISTRATION,"ERROR: Initiated already");
        require(electionDetails[_electionID].candidateAddress.length > 1,"ERROR: At least 2 candidates are needed");
        
        
        usedIDs[_electionID]=true;

        electionDetails[_electionID].electionID=_electionID;
        electionDetails[_electionID].electionType=_electionType;
        electionDetails[_electionID].winner= address(0);
        electionDetails[_electionID].winnerParty= Party.NONE;
        electionDetails[_electionID].totalVotes=0;
        electionDetails[_electionID].numOfWinningVotes=0;
        electionDetails[_electionID].startTime=block.timestamp;
        electionDetails[_electionID].endTime=electionDetails[_electionID].startTime+_duration;
        electionDetails[_electionID].electionStage=ElectionStage.START_ELECTION;

    }

    function getElectionDetails(uint _Id)
        public view chairpersonOnly returns(Election memory){
        return(electionDetails[_Id]);
    }

    function vote(
        uint _electionID,
        address candidateAddr
    )
    public
    startedElection(_electionID) beforeDeadline(_electionID)
    eligibleVoter(_electionID,msg.sender) eligibleCandidate(_electionID,candidateAddr)
    {
        require(!hasVoted[_electionID][msg.sender],"ERROR: You have voted already!");
        (bool candidateFound, int candidateIndex) = findCandidateIndex(electionDetails[_electionID], candidateAddr);
        require(candidateFound, "ERROR: Candidate not found in election");

        electionDetails[_electionID].candidateVotes[uint(candidateIndex)]++;
        electionDetails[_electionID].totalVotes++;
        hasVoted[_electionID][msg.sender]=true;
    }

    function findCandidateIndex(
        Election storage election, 
        address candidateAddr
        ) private view returns (bool, int) {
        for (uint i = 0; i < election.candidateAddress.length; i++) {
            if (election.candidateAddress[i] == candidateAddr) {
                return (true, int(i));
            }
        }
        return (false, -1);
    }

    function endElection(uint _electionID)
    public chairpersonOnly{
        require(usedIDs[_electionID], "ERROR: Election ID does not exist");
        require(block.timestamp >= electionDetails[_electionID].endTime,"ERROR: Election Deadline has not been met!");
        electionDetails[_electionID].electionStage = ElectionStage.END_ELECTION;
    }

    function declareWinner(uint _electionID)
    public chairpersonOnly returns(string memory, address, Party,uint){
        require(electionDetails[_electionID].endTime <= block.timestamp,"ERROR: Election is still on");
        require(electionDetails[_electionID].electionStage == ElectionStage.END_ELECTION,"ERROR: Election has not been Officially declared as over");

        uint256 highestVotes = 0;
        uint256 numWinners = 0;
        address winner = address(0);
        Party winnerParty = Party.NONE;

        Election storage election = electionDetails[_electionID];

        for (uint i = 0; i < election.candidateAddress.length; i++) {
            if (election.candidateVotes[i] > highestVotes) {
                highestVotes = election.candidateVotes[i];
                numWinners = 1;
                winner = election.candidateAddress[i];
                winnerParty = candidateDetails[winner].party;
            } else if (election.candidateVotes[i] == highestVotes) {
                numWinners++;
            }
        }

        require(numWinners == 1, "ERROR: Election resulted in a tie");

        election.winner = winner;
        election.winnerParty = winnerParty;
        election.numOfWinningVotes = highestVotes;
        candidateDetails[winner].name;

        return(candidateDetails[winner].name,election.winner, election.winnerParty, election.numOfWinningVotes);
    }


    function transferChairperson(address newChairperson) public  {
        require(msg.sender == chairPerson, "ERROR: Only the current ChairPerson can transfer the role");
        require(newChairperson != address(0), "ERROR: Invalid address specified");
        chairPerson = newChairperson;
    }

}
