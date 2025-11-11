// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./OctaGTestHelper.sol";
import "./MockERC721.sol";

contract GetTotalNumberOfBetsTest is Test {
    OctaGTestHelper octaG;
    MockERC721 mockNFT;
    address dummyVrfCoordinator = address(0x123);
    bytes32 dummyKeyHash = 0x0000000000000000000000000000000000000000000000000000000000000000;
    uint64 dummySubscriptionId = 1;

    address[] bettors;
    uint256 tokenId = 1;

    function setUp() public {
        // Initialize mock NFT and OctaG
        mockNFT = new MockERC721();
        octaG = new OctaGTestHelper(dummyVrfCoordinator, dummyKeyHash, dummySubscriptionId, address(this));

        // Mint an NFT and queue it for participants
        for (uint i = 1; i <= 8; i++) {
            address owner = vm.addr(i);
            mockNFT.mint(owner, i);
            vm.deal(owner, 10 ether);
            vm.startPrank(owner);
            mockNFT.approve(address(octaG), i);
            octaG.queueNft(address(mockNFT), i);
            vm.stopPrank();
        }

        // Prepare the participants
        octaG.prepareParticipants();

        // Initialize bettors (multiple bettors for placing bets)
        for (uint i = 0; i < 5; i++) {
            bettors.push(vm.addr(20 + i));
            vm.deal(bettors[i], 10 ether);
        }
    }

    function testSetBetsAndCount() public {
        // Place bets from multiple addresses
        for (uint i = 0; i < 20; i++) {
            address bettor = bettors[i % bettors.length]; // Reuse bettors for multiple bets
            uint participantId = (i % 8) + 1; // Bet on participants (IDs 1 to 8)
            vm.prank(bettor);
            octaG.placeBet{value: 0.01 ether}(address(mockNFT), participantId); // Place a bet of 0.01 ether
        }

        // Get total number of bets
        uint256 totalBets = octaG.totalBets();

        // Assert the total number of bets equals the expected value
        assertEq(totalBets, 20, "Total number of bets should be 20.");
    }

    function testTotalBetsIncrement() public {
        uint256 initialTotalBets = octaG.totalBets();

        // Place a single bet
        address bettor = bettors[0];
        uint256 participantId = 1;
        vm.prank(bettor);
        octaG.placeBet{value: 0.01 ether}(address(mockNFT), participantId);

        uint256 newTotalBets = octaG.totalBets();

        // Assert that totalBets has increased by 1
        assertEq(newTotalBets, initialTotalBets + 1, "Total bets should increment by 1 after placing a bet.");
    }

    function testTotalBetsReset() public {
        // Place some bets
        for (uint i = 0; i < 5; i++) {
            address bettor = bettors[i];
            uint256 participantId = i + 1;
            vm.prank(bettor);
            octaG.placeBet{value: 0.01 ether}(address(mockNFT), participantId);
        }

        // Verify that totalBets is now 5
        assertEq(octaG.totalBets(), 5, "Total bets should be 5 after placing 5 bets.");

        // Simulate end of round and cleanup
        octaG.testCleanupAfterRound();

        // Verify that totalBets has been reset to 0
        assertEq(octaG.totalBets(), 0, "Total bets should be reset to 0 after cleanup.");
    }
}
