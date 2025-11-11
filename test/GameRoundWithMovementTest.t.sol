// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./MockERC721.sol";
import "./OctaGTestHelper.sol";
import "../src/OctaG.sol";

contract GameRoundWithMovementTest is Test {
    OctaGTestHelper private octaG;
    MockERC721 private mockNFT;

    address private constant DUMMY_VRF_COORDINATOR = address(0x123);
    bytes32 private constant DUMMY_KEY_HASH = bytes32(0);
    uint64 private constant DUMMY_SUBSCRIPTION_ID = 1;
    address private constant HOUSE_ACCOUNT = address(0xBEEF);

    uint256 private constant PARTICIPANT_COUNT = 8;
    uint256 private constant TARGET_TOKEN_ID = 1;
    uint256 private constant REQUEST_ID = 1;

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
        octaG.setGameState(OctaG.GameState.Round);
    }

    function testProcessRandomWordsFindsWinnerAndCleansState() public {
        int256 startingX = -2000000000000000000; // -2 * 1e18 so one move reaches the center
        octaG.setParticipantPosition(address(mockNFT), TARGET_TOKEN_ID, startingX, 0);

        uint256[] memory randomWords = new uint256[](PARTICIPANT_COUNT);
        randomWords[0] = 3; // direction -> move towards center
        for (uint256 i = 1; i < PARTICIPANT_COUNT; i++) {
            randomWords[i] = i;
        }
        octaG.storeRandomWords(REQUEST_ID, randomWords);

        (bool winnerFound, uint256 winnerTokenId) = octaG.testProcessRandomWords(REQUEST_ID);

        assertTrue(winnerFound, "Winner should be found");
        assertEq(winnerTokenId, TARGET_TOKEN_ID, "Expected participant should win");
        assertEq(octaG.lastWinnerTokenId(), TARGET_TOKEN_ID, "Last winner tracking should match");
        assertEq(uint8(octaG.currentState()), uint8(OctaG.GameState.Cooldown), "Game should enter cooldown");
        assertFalse(octaG.roundInProgress(), "Round should be marked complete");
        assertEq(octaG.getNumberOfParticipants(), 0, "Participants should be cleared after cleanup");
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
