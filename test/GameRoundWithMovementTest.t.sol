// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./MockERC721.sol";
import "./OctaGTestHelper.sol";
import "../src/OctaG.sol";

contract GameRoundWithMovementTest is Test {
    OctaGTestHelper octaG;
    MockERC721 mockNFT;
    address dummyVrfCoordinator = address(0x123);
    bytes32 dummyKeyHash = 0x0000000000000000000000000000000000000000000000000000000000000000;
    uint64 dummySubscriptionId = 1;

    function setUp() public {
        mockNFT = new MockERC721();
        octaG = new OctaGTestHelper(dummyVrfCoordinator, dummyKeyHash, dummySubscriptionId);

        for (uint i = 1; i <= 8; i++) {
            address owner = vm.addr(i);
            mockNFT.mint(owner, i);
            vm.deal(owner, 10 ether);
            vm.startPrank(owner);
            mockNFT.approve(address(octaG), i);
            octaG.queueNft(address(mockNFT), i);
            octaG.testInitializeParticipantPositions();
            vm.stopPrank();
        }
    }

    function testGameRound() public {
        uint256 totalBetsPlaced = 0;

        for (uint i = 1; i <= 40; i++) {
            address bettor = vm.addr(i + 10);
            uint256 tokenId = i % 8 + 1; 
            uint256 betAmount = 0.2 ether + (i % 20) * 0.1 ether;
            totalBetsPlaced += betAmount;

            vm.deal(bettor, 20 ether);
            vm.prank(bettor);
            octaG.placeBet{value: betAmount}(tokenId);
        }

        bool winnerFound = false;
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp)));
        uint256 winnerTokenId;
        for (uint i = 1; i <= 8; i++) {
            uint movements = 0;
            while (!winnerFound && movements < 40000) { 
                if (octaG.testCalculateMovement(i, seed)) {
                    console.log("Winner found:", i);
                    winnerTokenId = i;
                    winnerFound = true;
                    break;
                }
                seed = uint256(keccak256(abi.encodePacked(seed)));
                movements++;
            }
            if (winnerFound) break;
        }

        require(winnerFound, "No winner was found, which is unlikely given the number of movements simulated");

        address winnerOwner = vm.addr(winnerTokenId);
        uint256 initialBalance = winnerOwner.balance;
        octaG.testDistributeRewards(address(mockNFT), winnerTokenId);
        uint256 houseCut = totalBetsPlaced * octaG.houseCommission() / 100;
        uint256 rewardPool = totalBetsPlaced - houseCut;
        uint256 winnerShare = rewardPool * octaG.nftParticipantShare() / 100;
        uint256 expectedWinnerBalance = initialBalance + winnerShare;

        assertEq(winnerOwner.balance, expectedWinnerBalance, "Winner's balance should reflect the correct share of the prize pool.");
    }
}
