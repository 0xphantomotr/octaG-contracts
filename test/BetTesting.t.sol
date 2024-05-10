// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./OctaGTestHelper.sol"; // Ensure this path is correct and points to your test helper
import "./MockERC721.sol";  // Ensure this path is correct and points to your mock contract

contract BetTesting is Test {
    OctaGTestHelper octaG;
    MockERC721 mockNFT;
    address dummyVrfCoordinator = address(0x123);
    bytes32 dummyKeyHash = 0x0000000000000000000000000000000000000000000000000000000000000000;
    uint64 dummySubscriptionId = 1;

    address alice = address(0x1);
    address bob = address(0x2);
    uint256 tokenId = 1;

    function setUp() public {
        mockNFT = new MockERC721();
        octaG = new OctaGTestHelper(dummyVrfCoordinator, dummyKeyHash, dummySubscriptionId);
        
        // Ensure Alice has the NFT minted to her, if not already done
        if (!mockNFT.exists(tokenId)) {
            mockNFT.mint(alice, tokenId);
        }

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        // Approve OctaG to manage Alice's NFT
        vm.prank(alice);
        mockNFT.approve(address(octaG), tokenId);
        
        // Queue the NFT into OctaG
        vm.prank(alice);
        octaG.queueNft(address(mockNFT), tokenId);
    }

    // function testPlaceBetValid() public {
    //     vm.deal(alice, 10 ether);
    //     vm.startPrank(alice);
    //     uint256 betAmount = 1 ether;
    //     octaG.placeBet{value: betAmount}(tokenId);
    //     vm.stopPrank();

    //     assertEq(octaG.getBetAmount(tokenId, alice), betAmount, "Bet amount should be recorded correctly.");
    //     assertEq(octaG.getBettingPoolTotal(), betAmount, "Total betting pool should be updated correctly.");
    // }

    // function testPlaceBetByAnyUser() public {
    //     vm.deal(bob, 10 ether);
    //     vm.prank(bob);
    //     uint256 betAmount = 1 ether;
    //     octaG.placeBet{value: betAmount}(tokenId);

    //     assertEq(octaG.getBetAmount(tokenId, bob), betAmount, "Bet amount should be recorded correctly for any user.");
    //     assertEq(octaG.getBettingPoolTotal(), betAmount, "Total betting pool should include Bob's bet.");
    // }

    // function testPlaceMultipleBets() public {
    //     vm.startPrank(alice);
    //     vm.deal(alice, 10 ether);
    //     uint256 firstBet = 1 ether;
    //     octaG.placeBet{value: firstBet}(tokenId);
    //     uint256 secondBet = 2 ether;
    //     octaG.placeBet{value: secondBet}(tokenId);
    //     vm.stopPrank();

    //     assertEq(octaG.getBetAmount(tokenId, alice), firstBet + secondBet, "Total bet for Alice should accumulate correctly.");
    //     assertEq(octaG.getBettingPoolTotal(), firstBet + secondBet, "Total betting pool should accumulate correctly.");
    // }

    // function testRewardDistribution() public {
    //     uint256 betAmount = 1 ether;
    //     uint256 numBettors = 30;
    //     address[] memory bettors = new address[](numBettors);

    //     // Use a unique token ID for the winner to prevent minting conflicts.
    //     address winner = vm.addr(1);
    //     uint256 winnerTokenId = 100; 
    //     if (!mockNFT.exists(winnerTokenId)) {
    //         mockNFT.mint(winner, winnerTokenId);
    //     }
    //     uint256 initialWinnerBalance = 10 ether;
    //     vm.deal(winner, initialWinnerBalance);

    //     vm.startPrank(winner);
    //     mockNFT.approve(address(octaG), winnerTokenId);
    //     octaG.queueNft(address(mockNFT), winnerTokenId);
    //     vm.stopPrank();

    //     // Each bettor gets a unique tokenId to avoid minting issues.
    //     for (uint i = 0; i < numBettors; i++) {
    //         address bettor = vm.addr(i + 2);
    //         uint256 tokenId = i + 101; // Ensuring unique token IDs for each bettor
    //         if (!mockNFT.exists(tokenId)) {
    //             mockNFT.mint(bettor, tokenId);
    //         }
    //         vm.deal(bettor, 10 ether);
    //         vm.prank(bettor);
    //         octaG.placeBet{value: betAmount}(tokenId);
    //     }

    //     uint256 totalPool = numBettors * betAmount;
    //     uint256 houseCut = totalPool * octaG.houseCommission() / 100;
    //     uint256 rewardPool = totalPool - houseCut;
    //     uint256 winnerShare = rewardPool * octaG.nftParticipantShare() / 100;
    //     uint256 bettersShare = rewardPool - winnerShare;

    //     vm.startPrank(winner);
    //     octaG.testDistributeRewards(address(mockNFT), winnerTokenId);
    //     vm.stopPrank();

    //     // Calculate the expected final balance of the winner
    //     uint256 expectedFinalWinnerBalance = initialWinnerBalance + winnerShare;

    //     // Debugging output for clarity
    //     console.log("House Cut:", houseCut);
    //     console.log("Reward Pool:", rewardPool);
    //     console.log("Winner Share:", winnerShare);
    //     console.log("Betters Share:", bettersShare);
    //     console.log("Total Pool:", totalPool);
    //     console.log("Winner's Initial Balance:", initialWinnerBalance);
    //     console.log("Winner's Expected Final Balance:", expectedFinalWinnerBalance);
    //     console.log("Winner's Actual Final Balance:", address(winner).balance);

    //     // Assert that the winner's final balance is as expected
    //     assertEq(address(winner).balance, expectedFinalWinnerBalance, "Winner should receive the correct share.");
    // }


}