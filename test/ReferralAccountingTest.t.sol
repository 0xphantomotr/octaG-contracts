// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./OctaGTestHelper.sol";
import "./MockERC721.sol";

contract ReferralAccountingTest is Test {
    OctaGTestHelper private octaG;
    MockERC721 private mockNFT;

    address private constant DUMMY_VRF_COORDINATOR = address(0x123);
    bytes32 private constant DUMMY_KEY_HASH = bytes32(0);
    uint64 private constant DUMMY_SUBSCRIPTION_ID = 1;
    address private constant HOUSE_ACCOUNT = address(0xBEEF);

    uint256 private constant PARTICIPANT_COUNT = 8;
    uint256 private constant TARGET_TOKEN_ID = 1;

    address private referrer;
    address private referee;
    address private neutralBettor;

    function setUp() public {
        mockNFT = new MockERC721();
        vm.deal(HOUSE_ACCOUNT, 0);
        octaG = new OctaGTestHelper(
            DUMMY_VRF_COORDINATOR,
            DUMMY_KEY_HASH,
            DUMMY_SUBSCRIPTION_ID,
            HOUSE_ACCOUNT
        );

        referrer = vm.addr(500);
        referee = vm.addr(501);
        neutralBettor = vm.addr(502);

        _seedParticipants();
        octaG.prepareParticipants();
        octaG.initializeRewardTiers();
        octaG.setReferralCount(referrer, 5);
    }

    function testReferralRewardDeductedFromPool() public {
        uint256 betAmount = 1 ether;
        vm.deal(referee, betAmount);
        vm.deal(referrer, 0);

        vm.prank(referee);
        octaG.registerReferral(referrer);

        vm.prank(referee);
        octaG.placeBet{value: betAmount}(address(mockNFT), TARGET_TOKEN_ID);

        uint256 expectedReward = (betAmount * 100) / 10000;
        assertEq(referrer.balance, expectedReward, "Referrer paid immediately");
        assertEq(address(octaG).balance, betAmount - expectedReward, "Contract retains only net amount");
        assertEq(octaG.getBettingPoolTotal(), betAmount - expectedReward, "Pool tracks net contributions");
    }

    function testPayoutsEqualNetDeposits() public {
        uint256 referralBet = 1 ether;
        uint256 neutralBet = 1 ether;

        vm.deal(referee, referralBet);
        vm.deal(referrer, 0);
        vm.deal(neutralBettor, neutralBet);

        vm.prank(referee);
        octaG.registerReferral(referrer);

        vm.prank(referee);
        octaG.placeBet{value: referralBet}(address(mockNFT), TARGET_TOKEN_ID);
        vm.prank(neutralBettor);
        octaG.placeBet{value: neutralBet}(address(mockNFT), TARGET_TOKEN_ID);

        uint256 expectedReferralReward = (referralBet * 100) / 10000;
        uint256 expectedPool = referralBet + neutralBet - expectedReferralReward;
        assertEq(octaG.getBettingPoolTotal(), expectedPool, "Pool matches net deposits");

        address winnerOwner = vm.addr(TARGET_TOKEN_ID);
        vm.deal(winnerOwner, 0);
        vm.deal(HOUSE_ACCOUNT, 0);

        octaG.testDistributeRewards(address(mockNFT), TARGET_TOKEN_ID);

        uint256 houseCut = (expectedPool * octaG.houseCommission()) / 100;
        uint256 rewardPool = expectedPool - houseCut;
        uint256 winnerShare = (rewardPool * octaG.nftParticipantShare()) / 100;
        uint256 bettorsShare = rewardPool - winnerShare;

        uint256 netReferralBet = referralBet - expectedReferralReward;
        uint256 netNeutralBet = neutralBet;
        uint256 totalWinnerBets = netReferralBet + netNeutralBet;
        uint256 refereeShare = (bettorsShare * netReferralBet) / totalWinnerBets;
        uint256 neutralShare = (bettorsShare * netNeutralBet) / totalWinnerBets;
        uint256 distributedBettors = refereeShare + neutralShare;

        assertEq(HOUSE_ACCOUNT.balance, houseCut, "House receives commission");
        assertEq(winnerOwner.balance, winnerShare, "NFT owner receives share");
        assertEq(referee.balance, refereeShare, "Referee receives proportional share only");
        assertEq(referrer.balance, expectedReferralReward, "Referrer receives referral reward");
        assertEq(neutralBettor.balance, neutralShare, "Neutral bettor receives proportional share");

        uint256 remainingBalance = rewardPool - winnerShare - distributedBettors;
        assertEq(address(octaG).balance, remainingBalance, "Contract retains only rounding dust");
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
