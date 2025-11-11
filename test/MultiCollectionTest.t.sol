// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./OctaGTestHelper.sol";
import "./MockERC721.sol";

contract MultiCollectionTest is Test {
    OctaGTestHelper private octaG;
    MockERC721 private collectionA;
    MockERC721 private collectionB;

    address private constant DUMMY_VRF_COORDINATOR = address(0x123);
    bytes32 private constant DUMMY_KEY_HASH = bytes32(0);
    uint64 private constant DUMMY_SUBSCRIPTION_ID = 1;
    address private constant HOUSE_ACCOUNT = address(0xBEEF);

    function setUp() public {
        collectionA = new MockERC721();
        collectionB = new MockERC721();
        vm.deal(HOUSE_ACCOUNT, 0);
        octaG = new OctaGTestHelper(
            DUMMY_VRF_COORDINATOR,
            DUMMY_KEY_HASH,
            DUMMY_SUBSCRIPTION_ID,
            HOUSE_ACCOUNT
        );

        _queueParticipants(collectionA, 1);
        _queueParticipants(collectionB, 1);
        octaG.prepareParticipants();
    }

    function testPlaceBetWithoutCollectionRevertsWhenDuplicateTokenIds() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert("Token ID ambiguous across collections");
        octaG.placeBet{value: 0.1 ether}(1);
    }

    function testBetsAreIsolatedPerCollection() public {
        address bettorA = vm.addr(101);
        address bettorB = vm.addr(102);
        vm.deal(bettorA, 1 ether);
        vm.deal(bettorB, 1 ether);

        vm.prank(bettorA);
        octaG.placeBet{value: 0.2 ether}(address(collectionA), 1);

        vm.prank(bettorB);
        octaG.placeBet{value: 0.3 ether}(address(collectionB), 1);

        assertEq(octaG.getBetAmount(address(collectionA), 1, bettorA), 0.2 ether, "Collection A bet tracked");
        assertEq(octaG.getBetAmount(address(collectionB), 1, bettorB), 0.3 ether, "Collection B bet tracked");
        assertEq(octaG.getBetAmount(address(collectionA), 1, bettorB), 0, "Cross-collection leakage prevented");
        assertEq(octaG.getTotalBetsForToken(address(collectionA), 1), 0.2 ether, "Totals isolated");
        assertEq(octaG.getTotalBetsForToken(address(collectionB), 1), 0.3 ether, "Totals isolated");
    }

    function testCleanupClearsCollectionSpecificState() public {
        address bettor = vm.addr(111);
        vm.deal(bettor, 1 ether);

        vm.prank(bettor);
        octaG.placeBet{value: 0.2 ether}(address(collectionA), 1);

        octaG.testCleanupAfterRound();

        assertEq(octaG.totalBets(), 0, "Total bets reset");
        assertEq(octaG.getTotalBetsForToken(address(collectionA), 1), 0, "Collection A totals reset");
        assertFalse(octaG.nftQueued(address(collectionA), 1), "Queue flag cleared for collection A");
        assertFalse(octaG.nftQueued(address(collectionB), 1), "Queue flag cleared for collection B");
        vm.expectRevert("Participant inactive");
        octaG.placeBet{value: 0.1 ether}(address(collectionA), 1);
    }

    function _queueParticipants(MockERC721 collection, uint256 startTokenId) private {
        for (uint256 i = 0; i < 4; i++) {
            uint256 tokenId = startTokenId + i;
            address owner = vm.addr(1000 + tokenId + uint160(address(collection)));
            collection.mint(owner, tokenId);

            vm.startPrank(owner);
            collection.approve(address(octaG), tokenId);
            octaG.queueNft(address(collection), tokenId);
            vm.stopPrank();
        }
    }
}
