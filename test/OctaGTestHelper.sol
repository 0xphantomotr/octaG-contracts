// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../src/OctaG.sol";

contract OctaGTestHelper is OctaG {
    
    constructor(address _vrfCoordinator, bytes32 _keyHash, uint64 subscriptionId) 
        OctaG(_vrfCoordinator, _keyHash, subscriptionId) {}

    function testInitializeParticipantPositions() public {
        return initializeParticipantPositions();
    }

    function testCalculateMovement(uint256 tokenId, uint256 seed) public returns (bool ) {
        return calculateMovement(tokenId, seed);
    }

    function getParticipantStateForTest(uint256 tokenId) public view returns (ParticipantState memory) {
        return participantStates[tokenId];
    }

    function initializePositionsForTesting() public {
        initializeParticipantPositions();
    }

    function testDetermineMovementDirectionAndMagnitude(uint256 randomSeed) 
        public 
        pure 
        returns (int256 dx, int256 dy) 
    {
        return determineMovementDirectionAndMagnitude(randomSeed);
    }

    function testFindValidDirection(Vertex memory currentPosition, Vertex[8] memory octagonVertices) public view returns (int256 dx, int256 dy) {
        return findValidDirection(currentPosition, octagonVertices);
    }

    function testIsWithinWinningCircle(Vertex memory point) public view returns (bool) {
        return isWithinWinningCircle(point);
    }   

    function testDistributeRewards(address collectionId, uint256 winnerTokenId) public {
        distributeRewards(collectionId, winnerTokenId);
    }

    // function testCalculateReferralReward(address referrer, uint256 betAmount) public view returns (uint256) {
    //     return calculateReferralReward(referrer, betAmount);
    // }

}