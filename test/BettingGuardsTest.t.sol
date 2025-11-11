// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./OctaGTestHelper.sol";
import "./MockERC721.sol";
import "./helpers/ReentrancyAttacker.sol";

contract BettingGuardsTest is Test {
    OctaGTestHelper private octaG;
    MockERC721 private mockNFT;
    ReentrancyAttacker private attacker;

    address private constant DUMMY_VRF_COORDINATOR = address(0x123);
    bytes32 private constant DUMMY_KEY_HASH = bytes32(0);
    uint64 private constant DUMMY_SUBSCRIPTION_ID = 1;
    address private constant HOUSE_ACCOUNT = address(0xBEEF);

    uint256 private constant PARTICIPANT_COUNT = 8;
    uint256 private constant TARGET_TOKEN_ID = 1;

    function setUp() public {
        mockNFT = new MockERC721();
        attacker = new ReentrancyAttacker();
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

    function testPlaceBetRevertsOutsideBettingState() public {
        octaG.setGameState(OctaG.GameState.Round);
        vm.deal(address(this), 0.1 ether);
        vm.expectRevert("Betting is not active");
        octaG.placeBet{value: 0.1 ether}(address(mockNFT), TARGET_TOKEN_ID);
    }

    function testPlaceBetRevertsForUnknownParticipant() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert("Participant inactive");
        octaG.placeBet{value: 0.1 ether}(address(mockNFT), 999);
    }

    function testReentrantBetDuringPayoutFails() public {
        address bettor = vm.addr(901);
        vm.deal(bettor, 1 ether);
        vm.prank(bettor);
        octaG.placeBet{value: 1 ether}(address(mockNFT), TARGET_TOKEN_ID);

        // transfer winning NFT to attacker so payout targets the malicious contract
        address originalOwner = vm.addr(TARGET_TOKEN_ID);
        vm.prank(originalOwner);
        mockNFT.transferFrom(originalOwner, address(attacker), TARGET_TOKEN_ID);

        attacker.configure(IOctaG(address(octaG)), address(mockNFT), TARGET_TOKEN_ID, ReentrancyAttacker.AttackMode.PlaceBet);

        octaG.testDistributeRewards(address(mockNFT), TARGET_TOKEN_ID);

        assertEq(attacker.triggerCount(), 1, "Fallback triggered once");
        assertFalse(attacker.lastSuccess(), "Reentrant bet attempt should fail");
        assertEq(octaG.getBetAmount(address(mockNFT), TARGET_TOKEN_ID, bettor), 0, "Bettor entry cleared post payout");
        assertEq(address(octaG).balance, 0, "Contract balance fully distributed");
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
