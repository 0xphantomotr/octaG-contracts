// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "../node_modules/@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./OctagonGeometry.sol";
import "forge-std/console.sol";

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

    VRFCoordinatorV2Interface COORDINATOR;
    bytes32 keyHash;
    uint64 s_subscriptionId;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 8;
    uint256 private constant MAX_ITERATIONS = 1000;

    int128 private constant TAN_PI_OVER_8 = 414213562373095048;
    int256 private constant scale = 1e18;
    Vertex private center = Vertex(0, 0);
    mapping(bytes32 => bool) private requestFulfilled;
    uint256 public totalBettingPool;
    mapping(uint256 => ParticipantState) public participantStates;

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
            // requestRandomness();
        }
    }

    function requestRandomness() internal {
        COORDINATOR.requestRandomWords(
            keyHash, 
            s_subscriptionId, 
            requestConfirmations, 
            callbackGasLimit, 
            numWords
        );
    }
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(participants.length == randomWords.length, "Participant-randomWords length mismatch");

        initializeParticipantPositions();

        uint256 winnerTokenId;
        bool foundWinner = false;
        address winnerCollectionId; // Declare variable to store the collectionId of the winner

        for (uint256 i = 0; i < participants.length; i++) {
            uint256 seed = randomWords[i];
            for (uint256 j = 0; j < MAX_ITERATIONS; j++) {
                bool hasReachedTarget = calculateMovement(participants[i].tokenId, seed);
                if (hasReachedTarget) {
                    emit WinnerDetermined(participants[i].tokenId);
                    winnerTokenId = participants[i].tokenId;
                    winnerCollectionId = participants[i].collectionId; // Store the collectionId when a winner is found
                    bettingPool.winningTotalBet += sumBetsForToken(winnerTokenId);
                    foundWinner = true;
                    break;
                }
                // Update the seed with the new hash
                seed = uint256(keccak256(abi.encode(seed)));
            }
            if (foundWinner) break;
        }

        if (foundWinner) {
            distributeRewards(winnerCollectionId, winnerTokenId);  // Now use the stored winnerCollectionId
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

        int256 distance = sqrt(abs(point.x - center.x) ** 2 + abs(point.y - center.y) ** 2);

        return distance <= radius;
    }


    function findValidDirection(Vertex memory currentPosition, Vertex[8] memory octagonVertices) internal pure returns (int256 dx, int256 dy) {
        for (uint256 i = 0; i < 8; i++) { 
            (int256 testDx, int256 testDy) = mapDirectionToVector(i);
            Vertex memory testPosition = Vertex(currentPosition.x + testDx, currentPosition.y + testDy);
            if (isVertexInsideOctagon(octagonVertices, testPosition)) {
                return (testDx, testDy); 
            }
        }
        revert("No valid move found");
    }

    function mapDirectionToVector(uint256 directionIndex) internal pure returns (int256 dx, int256 dy) {
        if (directionIndex == 0) return (1, 0);
        if (directionIndex == 1) return (-1, 0);
        if (directionIndex == 2) return (0, 1);
        if (directionIndex == 3) return (0, -1);
        if (directionIndex == 4) return (1, 1);
        if (directionIndex == 5) return (-1, 1);
        if (directionIndex == 6) return (1, -1);
        if (directionIndex == 7) return (-1, -1); 
        return (0, 0);
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

    function normalize(int256 x, int256 y) internal pure returns (int256, int256) {
        int256 magnitude = sqrt(x * x + y * y);
        return (x * 1e18 / magnitude, y * 1e18 / magnitude);
    }

    function dotProduct(int256 ax, int256 ay, int256 bx, int256 by) internal pure returns (int256) {
        return (ax * bx + ay * by) / 1e18;
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

        if (bets[tokenId][msg.sender] == 0) {
            bettorAddresses[tokenId].push(msg.sender);
        }
        bets[tokenId][msg.sender] += msg.value;
        totalBettingPool += msg.value;  
        bettingPool.totalAmount += msg.value;

        emit BetPlaced(msg.sender, msg.value, tokenId);
    }

    function distributeRewards(address collectionId, uint256 winnerTokenId) internal {
        uint256 totalBetsOnWinner = sumBetsForToken(winnerTokenId);
        bettingPool.winningTotalBet = totalBetsOnWinner;  // Update the pool with the correct amount

        if (totalBetsOnWinner == 0) {
            console.log("No valid bets for the winner, no payouts to bettors.");
            return;  
        }

        uint256 houseCut = bettingPool.totalAmount * houseCommission / 100;
        uint256 rewardPool = bettingPool.totalAmount - houseCut;
        uint256 winnerShare = rewardPool * nftParticipantShare / 100;
        uint256 bettersShare = rewardPool - winnerShare;

        console.log("House Cut:", houseCut);
        console.log("Reward Pool:", rewardPool);
        console.log("Winner Share:", winnerShare);
        console.log("Betters Share:", bettersShare);

        address winnerOwner = IERC721(collectionId).ownerOf(winnerTokenId);
        (bool winnerPaid, ) = payable(winnerOwner).call{value: winnerShare}("");
        require(winnerPaid, "Failed to send Ether to winner");

        distributeToBettors(winnerTokenId, bettersShare);
    }


    function distributeToBettors(uint256 tokenId, uint256 share) internal {
        uint256 totalBetsOnWinner = sumBetsForToken(tokenId);

        if (totalBetsOnWinner == 0) {
            console.log("No bets were placed on the winning token.");
            return;
        }

        for (uint256 i = 0; i < bettorAddresses[tokenId].length; i++) {
            address bettor = bettorAddresses[tokenId][i];
            uint256 betAmount = bets[tokenId][bettor];
        
        if (betAmount > 0) {
            uint256 payout = (betAmount * share) / totalBetsOnWinner;
            console.log("Paying out", payout, "to bettor", bettor);
            (bool bettorPaid, ) = payable(bettor).call{value: payout}("");
            require(bettorPaid, "Failed to send Ether to bettor");
            bets[tokenId][bettor] = 0; 
        }
        }
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
}
