// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@chainlink/contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "../node_modules/@chainlink/contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import "../node_modules/@chainlink/contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "../node_modules/@chainlink/contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "./OctagonGeometry.sol";

contract OctaG is VRFConsumerBaseV2Plus, AutomationCompatibleInterface, OctagonGeometry {

    // Constructor
    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        address _houseAccount
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        COORDINATOR = IVRFCoordinatorV2Plus(_vrfCoordinator);
        keyHash = _keyHash;
        s_subscriptionId = _subscriptionId;
        houseAccount = _houseAccount;
    }

    // Participants
    struct Participant {
        address nftOwner;
        uint256 tokenId;
        address collectionId;
    }

    struct ParticipantState {
        int256 x;
        int256 y;
        Vertex lastValidPosition;
        bool hasReachedTarget;
        uint256 stepsToTarget;
        address collectionId;
    }

    Participant[] public participants;
    Participant[] public queue;
    mapping(address => uint256) public lastQueueTime;
    mapping(address => mapping(uint256 => bool)) public nftQueued;

    uint256 public constant MAX_PARTICIPANTS = 8;
    address public houseAccount;

    // Bettors
    struct Bet {
        address bettor;
        uint256 amount;
        uint256 tokenId;
    }

    struct BettingPool {
        uint256 totalAmount;
        uint256 winningTotalBet;
    }

    mapping(bytes32 => mapping(address => uint256)) private bets;
    mapping(bytes32 => address[]) private bettorAddresses;
    BettingPool public bettingPool;

    uint256 public houseCommission = 8;
    uint256 public nftParticipantShare = 30;

    // Referral
    struct Tier {
        uint256 referralThreshold;
        uint256 rewardPercentage;
    }

    Tier[] public rewardTiers;

    mapping(address => address) public referrerOf;
    mapping(address => uint256) public referralCounts;
    mapping(address => uint256) public referralBets;

    IVRFCoordinatorV2Plus public COORDINATOR;
    bytes32 keyHash;
    uint256 public s_subscriptionId;
    uint16 requestConfirmations = 3;
    uint32 numWords = 8;
    uint256 public lastRequestId;
    uint256 roundStopDuration = 15 seconds; // Balanced rounds!

    bool public bettingActive;
    bool public roundInProgress;

    uint256 public roundStartTime;
    uint256 public roundEndTime;
    uint256 public cooldownEndTime;

    int128 private constant TAN_PI_OVER_8 = 414213562373095048;
    int256 private constant scale = 1e18;
    Vertex private octaCenter = Vertex(0, 0);
    uint256 public totalBettingPool;
    mapping(bytes32 => ParticipantState) internal participantStates;
    mapping(uint256 => bool) private requestStatus;
    mapping(uint256 => uint256[]) public storedRandomWords;

    // Events
    event NftQueued(address indexed nftOwner, uint256 tokenId, address collectionId);
    event WinnerDetermined(uint256 tokenId);
    event BetPlaced(address indexed bettor, uint256 amount, uint256 tokenId);
    event RandomWordsStored(uint256 requestId, uint256[] randomWords);
    event GameStarted();
    event BettingStarted();
    event BettingEnded(uint256 roundStartTime);
    event RoundStarted(uint256 roundStartTime);
    event RoundEnded(uint256 roundEndTime);
    event RoundTransition(uint256 roundStartTime, bool roundInProgress);
    event RoundEndCheck(uint256 currentTime, uint256 roundEndTime, bool roundInProgress);
    event RewardsDistributed(uint256 totalBetsOnWinner, uint256 houseCut, uint256 winnerShare, uint256 bettersShare, address winnerOwner);
    event BettorPaid(address bettor, uint256 amount);
    event GameStateChanged(GameState newState);
    event ParticipantMoved(uint256 tokenId, int256 x, int256 y);
    event RoundNumberChanged(uint256 roundNumber);

    enum GameState { Idle, Betting, Round, Cooldown }
    GameState public currentState = GameState.Idle;

    uint256 public totalBets;
    bool public lastWinnerFound;
    uint256 public lastWinnerTokenId;
    uint256 public currentRoundNumber;

    function _participantKey(address collectionId, uint256 tokenId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(collectionId, tokenId));
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        if (currentState == GameState.Idle && queue.length >= MAX_PARTICIPANTS) {
            upkeepNeeded = true;
        } else if (currentState == GameState.Betting && checkBettingRequirements()) {
            upkeepNeeded = true;
        } else if (currentState == GameState.Round && block.timestamp >= roundEndTime) {
            upkeepNeeded = true;
        } else if (currentState == GameState.Cooldown && block.timestamp >= cooldownEndTime) {
            upkeepNeeded = true;
        }
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        if (currentState == GameState.Idle && queue.length >= MAX_PARTICIPANTS) {
            prepareParticipants();
        } 
        else if (currentState == GameState.Betting && checkBettingRequirements()) {
            endBettingAndStartRound();
        } 
        else if (currentState == GameState.Round && block.timestamp >= roundEndTime) {
            emit RoundEndCheck(block.timestamp, roundEndTime, roundInProgress);
            processRandomWords(lastRequestId);
        } 
        else if (currentState == GameState.Cooldown && block.timestamp >= cooldownEndTime) {
            currentState = GameState.Idle;
            emit GameStateChanged(currentState);
        }
    }

    function checkBettingRequirements() public view returns (bool) {
        return (totalBets >= 10 && totalBettingPool >= 0.001 ether * 10);
    }

    function endBettingAndStartRound() internal {
        require(currentState == GameState.Betting, "Not in betting state");
        bettingActive = false;
        requestRandomWords();
        roundStartTime = block.timestamp;
        roundEndTime = roundStartTime + roundStopDuration;
        roundInProgress = true;
        currentState = GameState.Round;
        emit GameStateChanged(currentState);
        emit BettingEnded(roundStartTime);
        emit RoundStarted(roundStartTime);
    }

    function cleanupAfterRound() internal {
        for (uint256 i = 0; i < participants.length; i++) {
            Participant memory participant = participants[i];
            bytes32 key = _participantKey(participant.collectionId, participant.tokenId);

            address[] storage bettorsList = bettorAddresses[key];
            for (uint256 j = 0; j < bettorsList.length; j++) {
                delete bets[key][bettorsList[j]];
            }
            delete bettorAddresses[key];
            delete participantStates[key];
            nftQueued[participant.collectionId][participant.tokenId] = false;
        }

        delete participants;

        bettingPool.totalAmount = 0;
        bettingPool.winningTotalBet = 0;
        totalBettingPool = 0;

        roundInProgress = false;
        bettingActive = false;
        cooldownEndTime = block.timestamp + 1 minutes;
        totalBets = 0;
    }

    function queueNft(address _collectionId, uint256 _tokenId) public {
        require(IERC721(_collectionId).ownerOf(_tokenId) == msg.sender, "Caller is not the NFT owner");
        // require(block.timestamp >= lastQueueTime[msg.sender] + 1 days, "You can only queue one NFT per day");
        // require(!nftQueued[_collectionId][_tokenId], "NFT already queued");

        queue.push(Participant(msg.sender, _tokenId, _collectionId));
        lastQueueTime[msg.sender] = block.timestamp;
        nftQueued[_collectionId][_tokenId] = true;

        emit NftQueued(msg.sender, _tokenId, _collectionId);
    }

    function requestRandomWords() internal returns (uint256 requestId) {
        requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: 3,
                callbackGasLimit: 500000,
                numWords: 8,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
            })
        );
        lastRequestId = requestId;
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        require(randomWords.length == numWords, "Received incorrect number of random words");
        requestStatus[requestId] = true;
        storedRandomWords[requestId] = randomWords; 
        emit RandomWordsStored(requestId, randomWords);
    }

    function prepareParticipants() public {
        require(currentState == GameState.Idle, "Game is not in Idle state");
        require(participants.length == 0, "Participants already prepared");
        require(queue.length >= MAX_PARTICIPANTS, "Not enough participants in the queue");

        for (uint256 i = 0; i < MAX_PARTICIPANTS; i++) {
            participants.push(queue[i]);
        }

        for (uint256 i = MAX_PARTICIPANTS; i < queue.length; i++) {
            queue[i - MAX_PARTICIPANTS] = queue[i];
        }

        for (uint256 i = 0; i < MAX_PARTICIPANTS; i++) {
            queue.pop();
        }
        initializeParticipantPositions();

        bettingActive = true;
        currentState = GameState.Betting;
        emit GameStateChanged(currentState);
        emit GameStarted();
        emit BettingStarted();
    }

    function processRandomWords(uint256 requestId) internal {
        uint256 participantCount = participants.length;
        uint256[] storage randomWords = storedRandomWords[requestId];
        require(randomWords.length > 0, "Random words not generated yet");
        require(participants.length == randomWords.length, "Participant-randomWords length mismatch");

        uint256 iterationsPerRound = 5;
        bool winnerFound = false;
        uint256 winnerTokenId = 0;
        address winnerCollectionId = address(0);
        lastWinnerFound = false;
        lastWinnerTokenId = 0;

        // Increment round number
        currentRoundNumber++;
        emit RoundNumberChanged(currentRoundNumber);

        for (uint256 i = 0; i < participantCount; i++) {
            Participant memory participant = participants[i];
            uint256 tokenId = participant.tokenId;
            uint256 seed = randomWords[i];

            for (uint256 j = 0; j < iterationsPerRound; j++) {
                if (calculateMovement(tokenId, seed, participant.collectionId)) {
                    winnerTokenId = tokenId;
                    winnerFound = true;
                    winnerCollectionId = participant.collectionId;
                    break;
                }
                seed = uint256(keccak256(abi.encode(seed)));
            }

            if (winnerFound) break;
        }

        if (winnerFound) {
            emit WinnerDetermined(winnerTokenId);
            distributeRewards(winnerCollectionId, winnerTokenId);
            currentState = GameState.Cooldown;
            emit GameStateChanged(currentState);
            lastWinnerFound = true;
            lastWinnerTokenId = winnerTokenId;
            currentRoundNumber = 0; // Reset round counter
            cleanupAfterRound();
        } else {
            requestRandomWords();
            roundStartTime = block.timestamp;
            roundEndTime = roundStartTime + roundStopDuration;
        }

        delete storedRandomWords[requestId];
    }

    function initializeParticipantPositions() internal {
        Vertex[8] memory vertices = generateOctagonVertices();
        require(participants.length <= 8, "More participants than octagon vertices");

        for (uint256 i = 0; i < participants.length; i++) {
            Participant memory participant = participants[i];
            bytes32 key = _participantKey(participant.collectionId, participant.tokenId);
            ParticipantState storage state = participantStates[key];
            Vertex memory vertex = vertices[i];
            state.x = vertex.x;
            state.y = vertex.y;
            state.lastValidPosition = vertex;
            state.collectionId = participant.collectionId;
            state.hasReachedTarget = false;
            state.stepsToTarget = 0;
        }
    }

    function calculateMovement(uint256 tokenId, uint256 seed, address collectionId) internal returns (bool) {
        bytes32 key = _participantKey(collectionId, tokenId);
        ParticipantState storage state = participantStates[key];
        (int256 dx, int256 dy) = determineMovementDirectionAndMagnitude(seed);

        int256 newX = state.x + 2 * dx;
        int256 newY = state.y + 2 * dy;
        Vertex memory newPosition = Vertex(newX, newY);

        if (isWithinWinningCircle(newPosition)) {
            state.hasReachedTarget = true;
            state.x = newX;
            state.y = newY;
            emit ParticipantMoved(tokenId, state.x, state.y);
            return true;
        }

        Vertex[8] memory vertices = generateOctagonVertices();
        if (!isVertexInsideOctagon(vertices, newPosition)) {
            newPosition = state.lastValidPosition;
        } else {
            state.lastValidPosition = newPosition;
        }

        state.x = newPosition.x;
        state.y = newPosition.y;
        emit ParticipantMoved(tokenId, state.x, state.y);
        return false;
    }



    // d = sqr of ( (pow of pointx - centerx) + (pow of pointy - centery) )
    // Inside d <= r
    function isWithinWinningCircle(Vertex memory point) internal view returns (bool) {
        int256 radius = 1e18;
        // Use the new variable name here
        int256 distance = sqrt(abs(point.x - octaCenter.x) ** 2 + abs(point.y - octaCenter.y) ** 2);
        return distance <= radius;
    }
    
    function determineMovementDirectionAndMagnitude(uint256 randomSeed) internal pure returns (int256 dx, int256 dy) {
        uint256 direction = randomSeed % 8;

        if (direction == 0) {
            dx = 0; dy = scale;
        } else if (direction == 1) {
            dx = 0; dy = -scale;
        } else if (direction == 2) {
            dx = -scale; dy = 0;
        } else if (direction == 3) {
            dx = scale; dy = 0;
        } else if (direction == 4) {
            dx = scale; dy = scale;
        } else if (direction == 5) {
            dx = -scale; dy = scale;
        } else if (direction == 6) {
            dx = scale; dy = -scale;
        } else if (direction == 7) {
            dx = -scale; dy = -scale;
        }

        return (dx, dy);
    }

    function isVertexInsideOctagon(Vertex[8] memory polygon, Vertex memory testVertex) public pure returns (bool inside) {
        uint256 intersections = 0;

        for (uint256 i = 0; i < polygon.length; i++) {
            Vertex memory v1 = polygon[i];
            Vertex memory v2 = polygon[(i + 1) % polygon.length];

            if ((testVertex.y < v1.y && testVertex.y >= v2.y) || (testVertex.y < v2.y && testVertex.y >= v1.y)) {
                int256 intersectX = ((testVertex.y - v1.y) * (v2.x - v1.x)) / (v2.y - v1.y) + v1.x;
                if (testVertex.x < intersectX) {
                    intersections++;
                }
            }
        }
        return intersections % 2 != 0;
    }

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    function sqrt(int256 x) internal pure returns (int256 y) {
        int256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    function getNumberOfParticipants() public view returns (uint256) {
        return participants.length;
    }

    function getParticipantPosition(address collectionId, uint256 tokenId) public view returns (int256, int256) {
        ParticipantState storage state = participantStates[_participantKey(collectionId, tokenId)];
        return (state.x, state.y);
    }

    function getParticipantPosition(uint256 tokenId) public view returns (int256, int256) {
        (address collectionId, ) = getParticipantDetailsByTokenId(tokenId);
        return getParticipantPosition(collectionId, tokenId);
    }

    function placeBet(uint256 tokenId) external payable {
        (address collectionId, ) = getParticipantDetailsByTokenId(tokenId);
        _placeBet(collectionId, tokenId);
    }

    function placeBet(address collectionId, uint256 tokenId) external payable {
        _placeBet(collectionId, tokenId);
    }

    function _placeBet(address collectionId, uint256 tokenId) internal {
        require(currentState == GameState.Betting, "Betting is not active");
        require(msg.value > 0, "Bet amount must be greater than zero");

        bytes32 key = _participantKey(collectionId, tokenId);
        ParticipantState storage state = participantStates[key];
        require(state.collectionId == collectionId && collectionId != address(0), "Participant inactive");

        uint256 reward = 0;
        address referrer = referrerOf[msg.sender];
        if (referrer != address(0)) {
            reward = calculateReferralReward(referrer, msg.value);
            require(reward <= msg.value, "Reward cannot exceed the bet amount");
            referralBets[referrer] += reward;
        }

        uint256 netAmount = msg.value - reward;
        require(netAmount > 0, "Net bet amount must be greater than zero");

        if (bets[key][msg.sender] == 0) {
            bettorAddresses[key].push(msg.sender);
        }
        bets[key][msg.sender] += netAmount;
        totalBettingPool += netAmount;
        bettingPool.totalAmount += netAmount;
        totalBets += 1;
        
        emit BetPlaced(msg.sender, netAmount, tokenId);

        if (reward > 0) {
            (bool success, ) = payable(referrer).call{value: reward}("");
            require(success, "Referral reward transfer failed");
        }
    }

    function distributeRewards(address collectionId, uint256 winnerTokenId) internal {
        uint256 totalBetsOnWinner = sumBetsForToken(collectionId, winnerTokenId);
        bettingPool.winningTotalBet = totalBetsOnWinner;

        if (totalBetsOnWinner == 0) return;

        uint256 houseCut = (bettingPool.totalAmount * houseCommission) / 100;
        uint256 rewardPool = bettingPool.totalAmount - houseCut;
        uint256 winnerShare = (rewardPool * nftParticipantShare) / 100;
        uint256 bettersShare = rewardPool - winnerShare;

        distributeToBettors(collectionId, winnerTokenId, bettersShare);

        (bool sentHouse, ) = payable(houseAccount).call{value: houseCut}("");
        require(sentHouse, "House commission transfer failed");

        address winnerOwner = IERC721(collectionId).ownerOf(winnerTokenId);
        (bool sentWinner, ) = payable(winnerOwner).call{value: winnerShare}("");
        require(sentWinner, "Winner transfer failed");

        emit RewardsDistributed(totalBetsOnWinner, houseCut, winnerShare, bettersShare, winnerOwner);
    }

    function distributeToBettors(address collectionId, uint256 tokenId, uint256 share) internal {
        uint256 totalBetsOnWinner = sumBetsForToken(collectionId, tokenId);
        if (totalBetsOnWinner == 0) return;

        bytes32 key = _participantKey(collectionId, tokenId);
        address[] storage bettorsList = bettorAddresses[key];
        uint256[] memory payouts = new uint256[](bettorsList.length);

        for (uint256 i = 0; i < bettorsList.length; i++) {
            address bettor = bettorsList[i];
            uint256 betAmount = bets[key][bettor];
            if (betAmount > 0) {
                uint256 payout = (betAmount * share) / totalBetsOnWinner;
                payouts[i] = payout;
                bets[key][bettor] = 0;
                emit BettorPaid(bettor, payout);
            }
        }

        for (uint256 i = 0; i < payouts.length; i++) {
            if (payouts[i] > 0) {
                address bettor = bettorsList[i];
                (bool sent, ) = payable(bettor).call{value: payouts[i]}("");
                require(sent, "Bettor transfer failed");
            }
        }
    }

    function initializeRewardTiers() public {
        if (rewardTiers.length == 0) {
            rewardTiers.push(Tier(5, 100));  // 1% reward for 5 referrals
            rewardTiers.push(Tier(10, 150)); // 1.5% reward for 10 referrals
            rewardTiers.push(Tier(20, 250)); // 2.5% reward for 20 referrals
        }
    }

    function registerReferral(address referrer) external {
        require(referrer != address(0) && referrer != msg.sender, "Invalid referrer");
        require(referrerOf[msg.sender] == address(0), "Referrer already set");
        referrerOf[msg.sender] = referrer;
        referralCounts[referrer]++;
    }

    function calculateReferralReward(address referrer, uint256 betAmount) internal view returns (uint256) {
        uint256 totalReward = 0;
        for (uint i = 0; i < rewardTiers.length; i++) {
            if (referralCounts[referrer] >= rewardTiers[i].referralThreshold) {
                uint256 reward = betAmount * rewardTiers[i].rewardPercentage / 10000;
                if (reward > totalReward) {
                    totalReward = reward;
                }
            }
        }
        return totalReward;
    }

    function sumBetsForToken(address collectionId, uint256 tokenId) internal view returns (uint256) {
        bytes32 key = _participantKey(collectionId, tokenId);
        uint256 totalBetsForToken = 0;
        address[] storage addresses = bettorAddresses[key];
        for (uint256 i = 0; i < addresses.length; i++) {
            totalBetsForToken += bets[key][addresses[i]];
        }
        return totalBetsForToken;
    }

    function getTotalBetsForToken(address collectionId, uint256 tokenId) public view returns (uint256) {
        bytes32 key = _participantKey(collectionId, tokenId);
        uint256 totalBetsForToken = 0;
        address[] storage addresses = bettorAddresses[key];
        for (uint i = 0; i < addresses.length; i++) {
            totalBetsForToken += bets[key][addresses[i]];
        }
        return totalBetsForToken;
    }

    function getTotalBetsForToken(uint256 tokenId) public view returns (uint256) {
        (address collectionId, ) = getParticipantDetailsByTokenId(tokenId);
        return getTotalBetsForToken(collectionId, tokenId);
    }

    function getBettingPoolTotal() public view returns (uint256) {
        return totalBettingPool;
    }

    function getBetAmount(address collectionId, uint256 tokenId, address bettor) public view returns (uint256) {
        return bets[_participantKey(collectionId, tokenId)][bettor];
    }

    function getBetAmount(uint256 tokenId, address bettor) public view returns (uint256) {
        (address collectionId, ) = getParticipantDetailsByTokenId(tokenId);
        return getBetAmount(collectionId, tokenId, bettor);
    }

    function addRewardTier(uint256 referralThreshold, uint256 rewardPercentage) external {
        rewardTiers.push(Tier({
            referralThreshold: referralThreshold,
            rewardPercentage: rewardPercentage
        }));
    }

    function checkRequestStatus(uint256 requestId) public view returns (bool) {
        return requestStatus[requestId];
    }

    function getStoredRandomWords(uint256 requestId) external view returns (uint256[] memory) {
        return storedRandomWords[requestId];
    }

    function getParticipantDetailsByTokenId(uint256 tokenId) public view returns (address collectionId, address nftOwner) {
        bool found = false;
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i].tokenId == tokenId) {
                if (found && participants[i].collectionId != collectionId) {
                    revert("Token ID ambiguous across collections");
                }
                collectionId = participants[i].collectionId;
                nftOwner = participants[i].nftOwner;
                found = true;
            }
        }
        require(found, "Token ID not found");
    }

    function getParticipantDetails(address collectionId, uint256 tokenId) public view returns (address nftOwner) {
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i].tokenId == tokenId && participants[i].collectionId == collectionId) {
                return participants[i].nftOwner;
            }
        }
        revert("Participant not found");
    }

    function getQueueLength() public view returns (uint256) {
        return queue.length;
    }

    // Add this function to allow manual state transitions (for testing or emergency use)
    function setGameState(GameState _state) external onlyOwner {
        currentState = _state;
    }
}
