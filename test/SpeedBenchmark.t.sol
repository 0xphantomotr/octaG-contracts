// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./MockERC721.sol";
import "./OctaGTestHelper.sol";
import "../src/OctaG.sol";
import "../node_modules/@chainlink/contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract MockVRFCoordinator {
    uint256 public lastRequestId;

    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata
    ) external returns (uint256 requestId) {
        lastRequestId += 1;
        return lastRequestId;
    }
}

contract SpeedBenchmarkTest is Test {
    MockVRFCoordinator private coordinator;
    OctaGTestHelper private octaG;
    MockERC721 private mockNFT;

    address payable private constant HOUSE_ACCOUNT = payable(address(0xBEEF));
    uint64 private constant SUBSCRIPTION_ID = 1;
    bytes32 private constant KEY_HASH = bytes32(uint256(0x1234));
    uint256 private constant PARTICIPANT_COUNT = 8;
    
    event BenchmarkResult(string label, uint256 value);
    event BenchmarkComplete(uint256 totalRounds, uint256 totalTimeSeconds, uint256 avgPerRoundSeconds);

    function setUp() public {
        coordinator = new MockVRFCoordinator();
        octaG = new OctaGTestHelper(
            address(coordinator),
            KEY_HASH,
            SUBSCRIPTION_ID,
            HOUSE_ACCOUNT
        );
        mockNFT = new MockERC721();
        _setupParticipantsAndBets();
    }

    function testGameSpeedBenchmark() public {
        console.log("\n========================================");
        console.log("        GAME SPEED BENCHMARK");
        console.log("========================================");
        
        uint256 startTime = block.timestamp;
        uint256 roundCount = 0;
        uint256 maxRounds = 50; // Safety limit
        
        // Start game
        octaG.performUpkeep("");
        console.log("Game state: Betting");
        
        // Place bets now that betting is active
        for (uint256 i = 0; i < 10; i++) {
            address bettor = vm.addr(2000 + i);
            vm.deal(bettor, 1 ether);
            vm.prank(bettor);
            octaG.placeBet{value: 0.1 ether}(address(mockNFT), (i % PARTICIPANT_COUNT) + 1);
        }
        
        // Move to round phase
        octaG.performUpkeep("");
        console.log("Game state: Round");
        console.log("");
        
        // Keep processing rounds until winner found
        while (roundCount < maxRounds) {
            roundCount++;
            uint256 requestId = octaG.lastRequestId();
            uint256 roundStartTime = block.timestamp;
            
            // After 8 rounds, position token 1 close to center for guaranteed win
            if (roundCount == 8) {
                octaG.setParticipantPosition(address(mockNFT), 1, -2_000_000_000_000_000_000, 0);
            }
            
            // Fulfill VRF request
            uint256[] memory randomWords = new uint256[](PARTICIPANT_COUNT);
            randomWords[0] = 3; // Good random for token 1
            for (uint256 i = 1; i < PARTICIPANT_COUNT; i++) {
                randomWords[i] = i * 1000;
            }
            
            vm.prank(address(coordinator));
            octaG.rawFulfillRandomWords(requestId, randomWords);
            
            // Warp to round end time
            uint256 roundEnd = octaG.roundEndTime();
            uint256 roundDuration = roundEnd - roundStartTime;
            vm.warp(roundEnd);
            
            console.log("Round completed:", roundCount);
            console.log("Duration (seconds):", roundDuration);
            
            // Process round
            octaG.performUpkeep("");
            
            // Check if winner found
            if (octaG.lastWinnerFound()) {
                console.log("WINNER FOUND! Token ID:", octaG.lastWinnerTokenId());
                break;
            }
        }
        
        uint256 endTime = block.timestamp;
        uint256 totalDuration = endTime - startTime;
        uint256 avgPerRound = roundCount > 0 ? totalDuration / roundCount : 0;
        
        console.log("========================================");
        console.log("           RESULTS");
        console.log("========================================");
        emit BenchmarkResult("Total Rounds", roundCount);
        emit BenchmarkResult("Total Time (seconds)", totalDuration);
        emit BenchmarkResult("Avg per Round (seconds)", avgPerRound);
        emit BenchmarkComplete(roundCount, totalDuration, avgPerRound);
        console.log("========================================");
        
        assertTrue(octaG.lastWinnerFound(), "Winner should be found");
        assertLt(roundCount, maxRounds, "Should find winner before max rounds");
    }

    function _setupParticipantsAndBets() private {
        // Queue participants
        for (uint256 i = 0; i < PARTICIPANT_COUNT; i++) {
            uint256 tokenId = i + 1;
            address owner = vm.addr(100 + tokenId);
            mockNFT.mint(owner, tokenId);

            vm.startPrank(owner);
            mockNFT.approve(address(octaG), tokenId);
            octaG.queueNft(address(mockNFT), tokenId);
            vm.stopPrank();
        }
    }
}

