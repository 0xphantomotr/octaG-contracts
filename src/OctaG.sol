// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "../node_modules/@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./OctagonGeometry.sol";

contract OctaG is VRFConsumerBaseV2, OctagonGeometry {

    // Constructor
    constructor(address _vrfCoordinator, bytes32 _keyHash, uint64 subscriptionId)
        VRFConsumerBaseV2(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        s_subscriptionId = subscriptionId;
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
    uint256 public constant MAX_PARTICIPANTS = 8;

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

    mapping(uint256 => mapping(address => uint256)) public bets; 
    mapping(uint256 => address[]) public bettorAddresses; 
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

    VRFCoordinatorV2Interface COORDINATOR;
    bytes32 keyHash;
    uint64 s_subscriptionId;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 8;
    uint256 private constant MAX_ITERATIONS = 1000;

    int128 private constant TAN_PI_OVER_8 = 414213562373095048;
    int256 private constant scale = 1e18;
    Vertex private octaCenter = Vertex(0, 0);
    mapping(bytes32 => bool) private requestFulfilled;
    uint256 public totalBettingPool;
    mapping(uint256 => ParticipantState) public participantStates;
    mapping(uint256 => bool) private requestStatus;

    // Events
    event NftQueued(address indexed nftOwner, uint256 tokenId, address collectionId);
    event GameRoundReady(Participant[] participants);
    event RandomnessFulfilled(uint200[] randomWords);
    event WinnerDetermined(uint256 tokenId);
    event BetPlaced(address indexed bettor, uint256 amount, uint256 tokenId);
    event BettingPoolReset();
    event StateUpdated(uint256 indexed tokenId, uint256 newValue);

    enum Direction {
        Up,
        Down,
        Left,
        Right,
        UpRight,
        UpLeft,
        DownRight,
        DownLeft,
        None
    }

    function queueNft(address _collectionId, uint256 _tokenId) public {
        require(participants.length < MAX_PARTICIPANTS, "Participant limit reached");
        require(IERC721(_collectionId).ownerOf(_tokenId) == msg.sender, "Caller is not the NFT owner");

        participants.push(Participant(msg.sender, _tokenId, _collectionId));
        emit NftQueued(msg.sender, _tokenId, _collectionId);

        if(participants.length == MAX_PARTICIPANTS) {
            requestRandomness();
        }
    }

    function requestRandomness() internal {
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        requestStatus[requestId] = false;
    }
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        requestStatus[requestId] = true;
        require(participants.length == randomWords.length, "Participant-randomWords length mismatch");

        initializeParticipantPositions();

        uint256 winnerTokenId = 0;
        address winnerCollectionId = address(0);
        bool foundWinner = false;

        for (uint256 i = 0; i < participants.length; i++) {
            uint256 seed = randomWords[i];
            for (uint256 j = 0; j < MAX_ITERATIONS; j++) {
                bool hasReachedTarget = calculateMovement(participants[i].tokenId, seed);
                if (hasReachedTarget) {
                    emit WinnerDetermined(participants[i].tokenId);
                    winnerTokenId = participants[i].tokenId;
                    winnerCollectionId = participants[i].collectionId;
                    foundWinner = true;
                    break;
                }
                seed = uint256(keccak256(abi.encode(seed)));
            }
            if (foundWinner) break;
        }

        if (foundWinner && winnerTokenId != 0 && winnerCollectionId != address(0)) {
            distributeRewards(winnerCollectionId, winnerTokenId);
        }
    }

    function initializeParticipantPositions() internal {
        Vertex[8] memory vertices = generateOctagonVertices();
        require(participants.length <= 8, "More participants than octagon vertices");

        for (uint256 i = 0; i < participants.length; i++) {
            uint256 tokenId = participants[i].tokenId;
            participantStates[tokenId].x = vertices[i].x;
            participantStates[tokenId].y = vertices[i].y;
            participantStates[tokenId].lastValidPosition = vertices[i];
            participantStates[tokenId].collectionId = participants[i].collectionId;
            participantStates[tokenId].hasReachedTarget = false;
            participantStates[tokenId].stepsToTarget = 0;
        }
    }

    function calculateMovement(uint256 tokenId, uint256 seed) internal returns (bool) {
        ParticipantState storage state = participantStates[tokenId];
        (int256 dx, int256 dy) = determineMovementDirectionAndMagnitude(seed);

        int256 newX = state.x + dx;
        int256 newY = state.y + dy;
        Vertex memory newPosition = Vertex(newX, newY);

        if (isWithinWinningCircle(newPosition)) {
            state.hasReachedTarget = true;
            state.x = newX;
            state.y = newY;
            return true;
        }

        if (!isVertexInsideOctagon(generateOctagonVertices(), newPosition)) {
            newPosition = state.lastValidPosition;
        } else {
            state.lastValidPosition = newPosition;
        }

        state.x = newPosition.x;
        state.y = newPosition.y;
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

    function getParticipantPosition(uint256 tokenId) public view returns (int256, int256) {
        ParticipantState storage state = participantStates[tokenId];
        return (state.x, state.y);
    }

    function placeBet(uint256 tokenId) external payable {
        require(msg.value > 0, "Bet amount must be greater than zero");

        uint256 reward = 0;
        address referrer = referrerOf[msg.sender];
        if (referrer != address(0)) {
            reward = calculateReferralReward(referrer, msg.value);
            require(reward <= msg.value, "Reward cannot exceed the bet amount");
            referralBets[referrer] += reward;
        }

        if (bets[tokenId][msg.sender] == 0) {
            bettorAddresses[tokenId].push(msg.sender);
        }
        bets[tokenId][msg.sender] += msg.value;
        totalBettingPool += msg.value;
        bettingPool.totalAmount += msg.value;
        
        emit BetPlaced(msg.sender, msg.value, tokenId);

        if (reward > 0) {
            payable(referrer).transfer(reward);
        }
    }

    function distributeRewards(address collectionId, uint256 winnerTokenId) internal {
        uint256 totalBetsOnWinner = sumBetsForToken(winnerTokenId);
        bettingPool.winningTotalBet = totalBetsOnWinner;

        if (totalBetsOnWinner == 0) return;

        uint256 houseCut = (bettingPool.totalAmount * houseCommission) / 100;
        uint256 rewardPool = bettingPool.totalAmount - houseCut;
        uint256 winnerShare = (rewardPool * nftParticipantShare) / 100;
        uint256 bettersShare = rewardPool - winnerShare;

        distributeToBettors(winnerTokenId, bettersShare);

        address winnerOwner = IERC721(collectionId).ownerOf(winnerTokenId);

        payable(winnerOwner).transfer(winnerShare);
    }

    function distributeToBettors(uint256 tokenId, uint256 share) internal {
        uint256 totalBetsOnWinner = sumBetsForToken(tokenId);
        if (totalBetsOnWinner == 0) return;

        uint256[] memory payouts = new uint256[](bettorAddresses[tokenId].length);

        for (uint256 i = 0; i < bettorAddresses[tokenId].length; i++) {
            address bettor = bettorAddresses[tokenId][i];
            uint256 betAmount = bets[tokenId][bettor];
            if (betAmount > 0) {
                uint256 payout = (betAmount * share) / totalBetsOnWinner;
                payouts[i] = payout;
                bets[tokenId][bettor] = 0;
            }
        }

        for (uint256 i = 0; i < payouts.length; i++) {
            if (payouts[i] > 0) {
                address bettor = bettorAddresses[tokenId][i];
                payable(bettor).transfer(payouts[i]);
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

    function sumBetsForToken(uint256 tokenId) internal view returns (uint256) {
        uint256 totalBets = 0;
        address[] memory addresses = bettorAddresses[tokenId];
        for (uint256 i = 0; i < addresses.length; i++) {
            totalBets += bets[tokenId][addresses[i]];
        }
        return totalBets;
    }

    function getTotalBetsForToken(uint256 tokenId) public view returns (uint256) {
        uint256 totalBets = 0;
        for (uint i = 0; i < bettorAddresses[tokenId].length; i++) {
            totalBets += bets[tokenId][bettorAddresses[tokenId][i]];
        }
        return totalBets;
    }

    function getBettingPoolTotal() public view returns (uint256) {
        return totalBettingPool;
    }

    function getBetAmount(uint256 tokenId, address bettor) public view returns (uint256) {
        return bets[tokenId][bettor];
    }

    function getNumberOfRewardTiers() public view returns (uint) {
        return rewardTiers.length;
    }

    function getRewardTier(uint index) public view returns (Tier memory) {
        require(index < rewardTiers.length, "Tier index out of bounds");
        return rewardTiers[index];
    }

    function addRewardTier(uint256 referralThreshold, uint256 rewardPercentage) external {
        rewardTiers.push(Tier({
            referralThreshold: referralThreshold,
            rewardPercentage: rewardPercentage
        }));
    }

    function getReferralReward(address referrer) public view returns (uint256) {
        uint256 lastBetAmount = referralBets[referrer];
        uint256 reward = 0;

        for (uint i = rewardTiers.length; i > 0; i--) {
            if (referralCounts[referrer] >= rewardTiers[i - 1].referralThreshold) {
                reward = (lastBetAmount * rewardTiers[i - 1].rewardPercentage) / 10000;
                break;
            }
        }

        return reward;
    }

    function checkRequestStatus(uint256 requestId) public view returns (bool) {
        return requestStatus[requestId];
    }
}