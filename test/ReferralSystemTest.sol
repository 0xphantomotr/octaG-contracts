// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import "forge-std/Test.sol";
// import "./MockERC721.sol";
// import "./OctaGTestHelper.sol";
// import "../src/OctaG.sol";

// contract ReferralSystemTest is Test {
//     OctaGTestHelper octaG;
//     MockERC721 mockNFT;
//     address dummyVrfCoordinator = address(0x123);
//     bytes32 dummyKeyHash = 0x0000000000000000000000000000000000000000000000000000000000000000;
//     uint64 dummySubscriptionId = 1;

//     function setUp() public {
//         mockNFT = new MockERC721();
//         octaG = new OctaGTestHelper(dummyVrfCoordinator, dummyKeyHash, dummySubscriptionId);

//         vm.deal(address(octaG), 50 ether); // Simulate sending ether to the contract's balance for rewards

//         for (uint i = 1; i <= 8; i++) {
//             address owner = vm.addr(i);
//             mockNFT.mint(owner, i);
//             vm.deal(owner, 10 ether);
//             vm.startPrank(owner);
//             mockNFT.approve(address(octaG), i);
//             octaG.queueNft(address(mockNFT), i);
//             octaG.testInitializeParticipantPositions();
//             vm.stopPrank();
//         }

//         initializeRewardTiers(); // Proper initialization of reward tiers
//     }

//     function initializeRewardTiers() internal {
//         octaG.addRewardTier(1, 100); // Reward for even one referral, 0.1%
//     }

//     // function testReferralRewards() public {
//     //     address referrer = vm.addr(1);
//     //     address referee = vm.addr(2);

//     //     vm.deal(referrer, 10 ether);
//     //     vm.deal(referee, 10 ether);

//     //     vm.startPrank(referee);
//     //     octaG.registerReferral(referrer);
//     //     vm.stopPrank();

//     //     uint256 tokenId = 1;
//     //     uint256 betAmount = 1 ether;
//     //     vm.startPrank(referee);
//     //     octaG.placeBet{value: betAmount}(tokenId);
//     //     vm.stopPrank();

//     //     uint256 actualReward = octaG.getReferralReward(referrer);
//     //     uint256 expectedReward = calculateExpectedReferralReward(referrer, betAmount);

//     //     console.log("Expected Reward:", expectedReward);
//     //     console.log("Actual Reward:", actualReward);

//     //     assertEq(actualReward, expectedReward, "Referrer should receive the correct referral reward");
//     // }

//     // function calculateExpectedReferralReward(address referrer, uint256 betAmount) internal view returns (uint256) {
//     //     OctaG.Tier memory applicableTier = octaG.getRewardTier(0); // Assuming only one tier for simplicity
//     //     return (betAmount * applicableTier.rewardPercentage) / 10000;
//     // }

//     // function testReferralRegistrationLimits() public {
//     //     address referrer = vm.addr(1);
//     //     address referee = vm.addr(2);

//     //     vm.prank(referee);
//     //     octaG.registerReferral(referrer);

//     //     vm.prank(referee);
//     //     vm.expectRevert("Referrer already set");
//     //     octaG.registerReferral(referrer);

//     //     vm.prank(referrer);
//     //     vm.expectRevert("Invalid referrer");
//     //     octaG.registerReferral(referrer);
//     // }

//     // function testReferralRewardCalculation() public {
//     //     address referrer = vm.addr(1);
//     //     uint256 betAmount = 1 ether;
        
//     //     // Set up referral counts to hit different reward tiers
//     //     vm.prank(referrer);
//     //     octaG.setReferralCount(referrer, 15); // Assume `setReferralCount` method is available for testing

//     //     // Add multiple tiers to test correct reward calculation
//     //     octaG.addRewardTier(5, 150);  // 1.5% for 5+ referrals
//     //     octaG.addRewardTier(10, 250); // 2.5% for 10+ referrals
//     //     octaG.addRewardTier(20, 500); // This tier won't trigger as count is 15

//     //     // Expected reward for tier 2 (10+ referrals, 2.5% of 1 ether)
//     //     uint256 expectedReward = (betAmount * 250) / 10000;

//     //     // Calculate actual reward
//     //     uint256 actualReward = octaG.testCalculateReferralReward(referrer, betAmount);

//     //     assertEq(actualReward, expectedReward, "Calculated referral reward should match expected for given tier");
//     // }

//     // function testReferralRewardDistribution() public {
//     //     address referrer = vm.addr(1);
//     //     address referee = vm.addr(2);
//     //     uint256 tokenId = 1; // Assuming tokenId is valid and registered

//     //     vm.deal(referrer, 10 ether);
//     //     vm.deal(referee, 10 ether);

//     //     // Set up referral
//     //     vm.startPrank(referee);
//     //     octaG.registerReferral(referrer);
//     //     vm.stopPrank();

//     //     // Add a tier for testing
//     //     octaG.addRewardTier(1, 200); // 2.0% for 1+ referrals

//     //     // Place a bet and trigger reward distribution
//     //     uint256 betAmount = 2 ether;
//     //     vm.startPrank(referee);
//     //     octaG.placeBet{value: betAmount}(tokenId);
//     //     vm.stopPrank();

//     //     // Expected and actual reward verification
//     //     uint256 expectedReward = (betAmount * 200) / 10000;
//     //     uint256 actualReward = octaG.getReferralReward(referrer);

//     //     assertEq(address(referrer).balance, 10 ether + expectedReward, "Referrer should have received the correct reward");
//     // }


//     // function testNoRewardForUnregisteredReferrers() public {
//     //     address bettor = vm.addr(1);
//     //     uint256 tokenId = 1; // Valid token assumed

//     //     vm.deal(bettor, 10 ether);

//     //     // Place a bet without a referrer
//     //     vm.prank(bettor);
//     //     octaG.placeBet{value: 1 ether}(tokenId);

//     //     // Ensure no referral reward is recorded
//     //     uint256 actualReward = octaG.getReferralReward(bettor);
//     //     assertEq(actualReward, 0, "No referral reward should be recorded for unregistered referees");
//     // }



// }
