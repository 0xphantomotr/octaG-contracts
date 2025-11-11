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

contract OctaGEndToEndTest is Test {
    MockVRFCoordinator private coordinator;
    OctaGTestHelper private octaG;
    MockERC721 private mockNFT;

    address payable private constant HOUSE_ACCOUNT = payable(address(0xBEEF));
    uint64 private constant SUBSCRIPTION_ID = 1;
    bytes32 private constant KEY_HASH = bytes32(uint256(0x1234));

    uint256 private constant PARTICIPANT_COUNT = 8;
    uint256 private constant WINNER_TOKEN_ID = 1;
    uint256 private constant BET_SIZE = 0.1 ether;

    address[] private players;
    address private bettorA;
    address private bettorB;
    address private bettorC;
    address private bettorD;
    address private bettorE;

    function setUp() public {
        coordinator = new MockVRFCoordinator();
        octaG = new OctaGTestHelper(
            address(coordinator),
            KEY_HASH,
            SUBSCRIPTION_ID,
            HOUSE_ACCOUNT
        );
        mockNFT = new MockERC721();

        bettorA = vm.addr(2000);
        bettorB = vm.addr(2001);
        bettorC = vm.addr(2002);
        bettorD = vm.addr(2003);
        bettorE = vm.addr(2004);

        _mintAndQueueParticipants();
    }

    function testFullAutomationAndVRFWorkflow() public {
        octaG.performUpkeep("");
        assertEq(uint8(octaG.currentState()), uint8(OctaG.GameState.Betting), "Game should move into betting");
        assertTrue(octaG.bettingActive(), "Betting flag should be enabled");

        vm.deal(bettorA, 1 ether);
        vm.deal(bettorB, 1 ether);
        vm.deal(bettorC, 1 ether);
        vm.deal(bettorD, 1 ether);
        vm.deal(bettorE, 1 ether);

        _placeBet(bettorA, WINNER_TOKEN_ID, BET_SIZE);
        _placeBet(bettorA, WINNER_TOKEN_ID, BET_SIZE);
        _placeBet(bettorB, WINNER_TOKEN_ID, BET_SIZE);
        _placeBet(bettorB, WINNER_TOKEN_ID, BET_SIZE);

        _placeBet(bettorC, 2, BET_SIZE);
        _placeBet(bettorC, 3, BET_SIZE);
        _placeBet(bettorD, 4, BET_SIZE);
        _placeBet(bettorD, 5, BET_SIZE);
        _placeBet(bettorE, 6, BET_SIZE);
        _placeBet(bettorE, 7, BET_SIZE);

        assertEq(octaG.totalBets(), 10, "Total bets threshold should be reached");
        assertEq(octaG.getBettingPoolTotal(), 1 ether, "Total betting pool should match deposited value");

        octaG.performUpkeep("");
        assertEq(uint8(octaG.currentState()), uint8(OctaG.GameState.Round), "Game should move into round");
        assertTrue(octaG.roundInProgress(), "Round should be marked in progress");

        uint256 requestId = octaG.lastRequestId();
        assertGt(requestId, 0, "VRF request id should be recorded");

        octaG.setParticipantPosition(address(mockNFT), WINNER_TOKEN_ID, -2_000_000_000_000_000_000, 0);

        uint256[] memory randomWords = new uint256[](PARTICIPANT_COUNT);
        randomWords[0] = 3;
        for (uint256 i = 1; i < PARTICIPANT_COUNT; i++) {
            randomWords[i] = i;
        }

        vm.prank(address(coordinator));
        octaG.rawFulfillRandomWords(requestId, randomWords);
        assertTrue(octaG.checkRequestStatus(requestId), "Random words should be stored");

        uint256 houseBefore = HOUSE_ACCOUNT.balance;
        uint256 winnerOwnerBefore = players[WINNER_TOKEN_ID - 1].balance;
        uint256 bettorABefore = bettorA.balance;
        uint256 bettorBBefore = bettorB.balance;

        vm.warp(octaG.roundEndTime());
        octaG.performUpkeep("");

        _assertPostRoundState();
        _assertPayouts(houseBefore, winnerOwnerBefore, bettorABefore, bettorBBefore);
    }

    function _placeBet(address bettor, uint256 tokenId, uint256 amount) private {
        vm.prank(bettor);
        octaG.placeBet{value: amount}(address(mockNFT), tokenId);
    }

    function _mintAndQueueParticipants() private {
        for (uint256 i = 0; i < PARTICIPANT_COUNT; i++) {
            uint256 tokenId = i + 1;
            address owner = vm.addr(100 + tokenId);
            players.push(owner);
            mockNFT.mint(owner, tokenId);

            vm.startPrank(owner);
            mockNFT.approve(address(octaG), tokenId);
            octaG.queueNft(address(mockNFT), tokenId);
            vm.stopPrank();
        }
    }

    function _assertPostRoundState() private view {
        assertTrue(octaG.lastWinnerFound(), "Winner flag should be recorded");
        assertEq(octaG.lastWinnerTokenId(), WINNER_TOKEN_ID, "Winner token id should be tracked");
        assertEq(uint8(octaG.currentState()), uint8(OctaG.GameState.Cooldown), "Game should enter cooldown");
        assertFalse(octaG.roundInProgress(), "Round should no longer be active");
        assertEq(octaG.getNumberOfParticipants(), 0, "Participants should be cleaned up");
        assertEq(octaG.getBettingPoolTotal(), 0, "Betting pool should reset");
    }

    function _assertPayouts(
        uint256 houseBefore,
        uint256 winnerOwnerBefore,
        uint256 bettorABefore,
        uint256 bettorBBefore
    ) private view {
        address winnerOwner = players[WINNER_TOKEN_ID - 1];
        uint256 totalPool = 1 ether;
        uint256 expectedHouseCut = (totalPool * octaG.houseCommission()) / 100;
        assertEq(HOUSE_ACCOUNT.balance, houseBefore + expectedHouseCut, "House commission should be paid out");

        uint256 rewardPool = totalPool - expectedHouseCut;
        uint256 expectedWinnerShare = (rewardPool * octaG.nftParticipantShare()) / 100;
        assertEq(winnerOwner.balance, winnerOwnerBefore + expectedWinnerShare, "Winning NFT owner should be rewarded");

        uint256 bettersShare = rewardPool - expectedWinnerShare;
        uint256 totalBetsOnWinner = 4 * BET_SIZE;
        uint256 expectedBettorPayout = (2 * BET_SIZE * bettersShare) / totalBetsOnWinner;

        assertEq(bettorA.balance, bettorABefore + expectedBettorPayout, "Bettor A should receive proportional payout");
        assertEq(bettorB.balance, bettorBBefore + expectedBettorPayout, "Bettor B should receive proportional payout");
    }
}
