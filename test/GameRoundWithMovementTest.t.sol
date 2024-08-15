// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "./MockERC721.sol";
// import "./OctaGTestHelper.sol";
// import "../src/OctaG.sol";

// contract GameRoundWithMovementTest is Test {
//     OctaGTestHelper octaG;
//     MockERC721 mockNFT;
//     address dummyVrfCoordinator = address(0x123);
//     bytes32 dummyKeyHash = 0x0000000000000000000000000000000000000000000000000000000000000000;
//     uint64 dummySubscriptionId = 1;

    // function setUp() public {
    //     mockNFT = new MockERC721();
    //     octaG = new OctaGTestHelper(dummyVrfCoordinator, dummyKeyHash, dummySubscriptionId, msg.sender);

    //     for (uint i = 1; i <= 8; i++) {
    //         address owner = vm.addr(i);
    //         mockNFT.mint(owner, i);
    //         vm.deal(owner, 10 ether);
    //         vm.startPrank(owner);
    //         mockNFT.approve(address(octaG), i);
    //         octaG.queueNft(address(mockNFT), i);
    //         vm.stopPrank();
    //     }

    //     // Prepare participants once
    //     uint256 requestId = 1;
    //     uint256[] memory randomWords = new uint256[](8);
    //     uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp)));

    //     for (uint i = 0; i < 8; i++) {
    //         randomWords[i] = seed;
    //         seed = uint256(keccak256(abi.encodePacked(seed)));
    //     }

    //     octaG.storeRandomWords(requestId, randomWords);
    //     octaG.testPrepareParticipants(requestId);
    // }

    // function testProcessRandomWords() public {
    //     // Process one round of random words
    //     uint256 requestId = 1;
    //     bool winnerFound;
    //     uint256 winnerTokenId;

    //     // Process the random words and capture the result
    //     (winnerFound, winnerTokenId) = octaG.testProcessRandomWords(requestId);

    //     // Log the result
    //     if (winnerFound) {
    //         console.log("Winner found with token ID:", winnerTokenId);
    //     } else {
    //         console.log("No winner found in this round.");
    //     }

    //     // Ensure the test behaves as expected
    //     require(winnerFound, "No winner was found after processing one round of random words");
    // }
// }
