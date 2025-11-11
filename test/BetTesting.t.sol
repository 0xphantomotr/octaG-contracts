// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./OctaGTestHelper.sol";
import "./MockERC721.sol";

contract BetTesting is Test {
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
        vm.deal(HOUSE_ACCOUNT, 0);
        octaG = new OctaGTestHelper(
            DUMMY_VRF_COORDINATOR,
            DUMMY_KEY_HASH,
            DUMMY_SUBSCRIPTION_ID,
            HOUSE_ACCOUNT
        );

        _seedParticipants();
        octaG.prepareParticipants();
    }

    function testPlaceBetRecordsAmount() public {
        address bettor = vm.addr(100);
        vm.deal(bettor, 5 ether);

        vm.prank(bettor);
        octaG.placeBet{value: 1 ether}(address(mockNFT), TARGET_TOKEN_ID);

        assertEq(octaG.getBetAmount(address(mockNFT), TARGET_TOKEN_ID, bettor), 1 ether, "Bet amount should be recorded");
        assertEq(octaG.getBettingPoolTotal(), 1 ether, "Pool should reflect the bet");
        assertEq(octaG.totalBets(), 1, "Total bets should increment");
    }

    function testPlaceBetAccumulatesForSameBettor() public {
        address bettor = vm.addr(101);
        vm.deal(bettor, 5 ether);

        vm.startPrank(bettor);
        octaG.placeBet{value: 0.25 ether}(address(mockNFT), TARGET_TOKEN_ID);
        octaG.placeBet{value: 0.75 ether}(address(mockNFT), TARGET_TOKEN_ID);
        vm.stopPrank();

        assertEq(octaG.getBetAmount(address(mockNFT), TARGET_TOKEN_ID, bettor), 1 ether, "Bets should accumulate");
        assertEq(octaG.getBettingPoolTotal(), 1 ether, "Pool should track cumulative amount");
        assertEq(octaG.totalBets(), 2, "Total bet counter should reflect both wagers");
    }

    function testDifferentBettorsAccumulatePool() public {
        address bettorOne = vm.addr(102);
        address bettorTwo = vm.addr(103);
        vm.deal(bettorOne, 2 ether);
        vm.deal(bettorTwo, 2 ether);

        vm.prank(bettorOne);
        octaG.placeBet{value: 0.5 ether}(address(mockNFT), TARGET_TOKEN_ID);

        vm.prank(bettorTwo);
        octaG.placeBet{value: 0.5 ether}(address(mockNFT), TARGET_TOKEN_ID);

        assertEq(octaG.getBetAmount(address(mockNFT), TARGET_TOKEN_ID, bettorOne), 0.5 ether, "First bettor amount tracked");
        assertEq(octaG.getBetAmount(address(mockNFT), TARGET_TOKEN_ID, bettorTwo), 0.5 ether, "Second bettor amount tracked");
        assertEq(octaG.getBettingPoolTotal(), 1 ether, "Pool should equal sum of bets");
        assertEq(octaG.totalBets(), 2, "Two bets placed overall");
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
