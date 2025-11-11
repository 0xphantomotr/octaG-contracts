// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./OctaGTestHelper.sol";
import "./MockERC721.sol";

contract ReferralSystemTest is Test {
    OctaGTestHelper private octaG;
    MockERC721 private mockNFT;

    address private constant DUMMY_VRF_COORDINATOR = address(0x123);
    bytes32 private constant DUMMY_KEY_HASH = bytes32(0);
    uint64 private constant DUMMY_SUBSCRIPTION_ID = 1;
    address private constant HOUSE_ACCOUNT = address(0xBEEF);

    uint256 private constant PARTICIPANT_COUNT = 8;
    uint256 private constant TARGET_TOKEN_ID = 1;

    function setUp() public {
        mockNFT = new MockERC721();
        octaG = new OctaGTestHelper(
            DUMMY_VRF_COORDINATOR,
            DUMMY_KEY_HASH,
            DUMMY_SUBSCRIPTION_ID,
            HOUSE_ACCOUNT
        );

        _seedParticipants();
        octaG.prepareParticipants();
        octaG.initializeRewardTiers();
    }

    function testRegisterReferralOnlyOnce() public {
        address referrer = vm.addr(200);
        address referee = vm.addr(201);

        vm.prank(referee);
        octaG.registerReferral(referrer);

        assertEq(octaG.referrerOf(referee), referrer, "Referrer should be recorded");
        assertEq(octaG.referralCounts(referrer), 1, "Referral count should increase");

        vm.prank(referee);
        vm.expectRevert("Referrer already set");
        octaG.registerReferral(referrer);
    }

    function testReferralRewardPaidWhenThresholdMet() public {
        address referrer = vm.addr(210);
        address referee = vm.addr(211);
        uint256 betAmount = 1 ether;

        octaG.setReferralCount(referrer, 5);

        vm.prank(referee);
        octaG.registerReferral(referrer);

        vm.deal(referee, betAmount);
        vm.deal(referrer, 0);

        vm.prank(referee);
        octaG.placeBet{value: betAmount}(address(mockNFT), TARGET_TOKEN_ID);

        uint256 expectedReward = (betAmount * 100) / 10000; // 1% threshold reward
        assertEq(address(referrer).balance, expectedReward, "Referrer should receive reward");
        assertEq(octaG.referralBets(referrer), expectedReward, "Referral tracking should capture reward");
    }

    function testNoRewardForUnregisteredReferrer() public {
        address bettor = vm.addr(220);
        uint256 betAmount = 0.5 ether;

        vm.deal(bettor, betAmount);

        vm.prank(bettor);
        octaG.placeBet{value: betAmount}(address(mockNFT), TARGET_TOKEN_ID);

        assertEq(octaG.referralBets(bettor), 0, "No referral rewards should accrue");
        assertEq(octaG.referrerOf(bettor), address(0), "No referrer should be registered");
    }

    function _seedParticipants() private {
        for (uint256 i = 0; i < PARTICIPANT_COUNT; i++) {
            uint256 tokenId = i + 1;
            address owner = vm.addr(tokenId);
            mockNFT.mint(owner, tokenId);

            vm.startPrank(owner);
            mockNFT.approve(address(octaG), tokenId);
            octaG.queueNft(address(mockNFT), tokenId);
            vm.stopPrank();
        }
    }
}
