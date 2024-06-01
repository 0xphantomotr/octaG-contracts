
// SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import "forge-std/Test.sol";
// import "./OctaGTestHelper.sol";
// import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "../node_modules/@openzeppelin/contracts/utils/Strings.sol";

// contract OctaGTests is Test {
//     OctaGTestHelper octaGTestHelper;
//     address dummyVrfCoordinator = address(1); // Dummy address for testing
//     bytes32 dummyKeyHash = 0x0;
//     uint64 dummySubscriptionId = 0;
//     address nftCollectionAddress;
//     address vrfCoordinatorMock = address(0x123);
//     MockERC721 public mockNFT;
//     int256 public constant RADIUS = 17e18;

//     function setUp() public {
//         octaGTestHelper = new OctaGTestHelper(dummyVrfCoordinator, dummyKeyHash, dummySubscriptionId);
//         Initialize a test participant at position (0, 0)
//         octaGTestHelper.initializeParticipantForTest(1, 0, 0);
//         nftCollectionAddress = address(new MockERC721());
//         vm.label(nftCollectionAddress, "MockERC721Collection");
//         mockNFT = MockERC721(nftCollectionAddress);

//     }

//     // Queuing and postiioning NFTs

//     function testQueueNftSuccess() public {
//         address nftOwner = address(this);
//         vm.prank(nftOwner);
//         mockNFT.mint(nftOwner, 1);

//         vm.prank(nftOwner);
//         octaGTestHelper.queueNft(nftCollectionAddress, 1);

//         (address owner, uint256 tokenId, address collectionId) = octaGTestHelper.participants(0);
//         assertEq(owner, nftOwner);
//         assertEq(tokenId, 1);
//         assertEq(collectionId, nftCollectionAddress);
//         emit log("testQueueNftSuccess passed");
//     }

//     function testInitializeNFTPositions() public {
//             uint256 maxParticipants = 8;
//             address nftOwner = address(this);
//             // Queue NFTs and assign positions
//             for (uint256 i = 1; i <= maxParticipants; i++) {
//                 mockNFT.mint(nftOwner, i);
//                 vm.prank(nftOwner);
//                 octaGTestHelper.queueNft(nftCollectionAddress, i);
//             }

//             octaGTestHelper.initializePositionsForTesting();

//             // Fetch the expected vertices for an octagon
//             OctagonGeometry.Vertex[8] memory expectedVertices = octaGTestHelper.generateOctagonVertices();

//             // Assert each participant's position matches one of the expected octagon vertices
//             for (uint256 i = 1; i <= maxParticipants; i++) {
//                 (int256 x, int256 y) = octaGTestHelper.getParticipantPosition(i);
//                 bool positionMatchesExpected = false;

//                 for (uint256 j = 0; j < 8; j++) {
//                     if (x == expectedVertices[j].x && y == expectedVertices[j].y) {
//                         positionMatchesExpected = true;
//                         break;
//                     }
//                 }

//                 assertTrue(positionMatchesExpected, string(abi.encodePacked("Participant ", Strings.toString(i), " positioned incorrectly.")));
//             }
//     }



//     // Direcetions testing

//     function testDirectionAndMovement() public {
//         // Direction 0: Up
//         (int256 dx, int256 dy) = octaGTestHelper.testDetermineMovementDirectionAndMagnitude(349857349872);
//         assertEq(dx, 0, "Direction 0: dx should be 0");
//         assertEq(dy, 1, "Direction 0: dy should be 1");

//         // Direction 1: Down
//         (dx, dy) = octaGTestHelper.testDetermineMovementDirectionAndMagnitude(349857349873);
//         assertEq(dx, 0, "Direction 1: dx should be 0");
//         assertEq(dy, -1, "Direction 1: dy should be -1");

//         // Direction 2: Left
//         (dx, dy) = octaGTestHelper.testDetermineMovementDirectionAndMagnitude(349857349874);
//         assertEq(dx, -1, "Direction 2: dx should be -1");
//         assertEq(dy, 0, "Direction 2: dy should be 0");

//         // Direction 3: Right
//         (dx, dy) = octaGTestHelper.testDetermineMovementDirectionAndMagnitude(1234234235);
//         assertEq(dx, 1, "Direction 3: dx should be 1");
//         assertEq(dy, 0, "Direction 3: dy should be 0");

//         // Direction 4: UpRight
//         (dx, dy) = octaGTestHelper.testDetermineMovementDirectionAndMagnitude(349857349876);
//         assertEq(dx, 1, "Direction 4: dx should be 1");
//         assertEq(dy, 1, "Direction 4: dy should be 1");

//         // Direction 5: UpLeft
//         (dx, dy) = octaGTestHelper.testDetermineMovementDirectionAndMagnitude(349857349885);
//         assertEq(dx, -1, "Direction 5: dx should be -1");
//         assertEq(dy, 1, "Direction 5: dy should be 1");

//         // Direction 6: DownRight
//         (dx, dy) = octaGTestHelper.testDetermineMovementDirectionAndMagnitude(349857349878);
//         assertEq(dx, 1, "Direction 6: dx should be 1");
//         assertEq(dy, -1, "Direction 6: dy should be -1");

//         // Direction 7: DownLeft
//         (dx, dy) = octaGTestHelper.testDetermineMovementDirectionAndMagnitude(349857349871);
//         assertEq(dx, -1, "Direction 7: dx should be -1");
//         assertEq(dy, -1, "Direction 7: dy should be -1");
//     }



//     // Test Vertex positions

//     function testPointInsideOctagon() public {
//         OctagonGeometry.Vertex[8] memory octagonVertices = octaGTestHelper.generateOctagonVertices();
//         OctagonGeometry.Vertex memory testVertex = OctagonGeometry.Vertex(0, 0);

//         bool isInside = octaGTestHelper.isVertexInsideOctagon(octagonVertices, testVertex);
//         assertTrue(isInside, "Center point should be inside the octagon.");
//     }

//     function testPointOutsideOctagon() public {
//         OctagonGeometry.Vertex[8] memory octagonVertices = octaGTestHelper.generateOctagonVertices();
//         OctagonGeometry.Vertex memory testVertex = OctagonGeometry.Vertex(2 * RADIUS, 2 * RADIUS);

//         bool isInside = octaGTestHelper.isVertexInsideOctagon(octagonVertices, testVertex);
//         assertFalse(isInside, "Point far outside should be outside the octagon.");
//     }

//     function testPointOnEdgeOfOctagon() public {
//         OctagonGeometry.Vertex[8] memory octagonVertices = octaGTestHelper.generateOctagonVertices();
//         OctagonGeometry.Vertex memory testVertex = OctagonGeometry.Vertex(RADIUS / 2, 0);

//         bool isInside = octaGTestHelper.isVertexInsideOctagon(octagonVertices, testVertex);
//         assertTrue(isInside, "Point on edge should be considered inside the octagon.");
//     }

//     function testPointNearEdgeInside() public {
//         OctagonGeometry.Vertex[8] memory octagonVertices = octaGTestHelper.generateOctagonVertices();
//         OctagonGeometry.Vertex memory testVertex = OctagonGeometry.Vertex(RADIUS - 1e17, 1e17);

//         bool isInside = octaGTestHelper.isVertexInsideOctagon(octagonVertices, testVertex);
//         assertTrue(isInside, "Point near edge inside should be considered inside the octagon.");
//     }

//     function testPointOnVertexOfOctagon() public {
//         OctagonGeometry.Vertex[8] memory octagonVertices = octaGTestHelper.generateOctagonVertices();
//         OctagonGeometry.Vertex memory testVertex = octagonVertices[0];

//         // Introduce a tolerance level for comparison, ensure it's int256
//         int256 tolerance = 1e14; // Adjust based on your contract's decimal precision

//         bool isApproxInside = false;
//         for (uint i = 0; i < octagonVertices.length; i++) {
//             if (
//                 abs(testVertex.x - octagonVertices[i].x) <= tolerance &&
//                 abs(testVertex.y - octagonVertices[i].y) <= tolerance
//             ) {
//                 isApproxInside = true;
//                 break;
//             }
//         }

//         assertTrue(isApproxInside, "Point on vertex should be considered inside the octagon with a tolerance.");
//     }

//     function testFuzzIsVertexInsideOctagon(int256 x, int256 y) public {
//         vm.assume(x >= -20e18 && x <= 20e18 && y >= -20e18 && y <= 20e18);

//         OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();
//         OctagonGeometry.Vertex memory testVertex = OctagonGeometry.Vertex(x, y);

//         bool isInside = octaGTestHelper.isVertexInsideOctagon(vertices, testVertex);

//         emit log_named_int("Tested X coordinate", x);
//         emit log_named_int("Tested Y coordinate", y);
//         emit log(string(abi.encodePacked("Is inside octagon: ", isInside ? "true" : "false")));
//     }

//     function testFuzzPointsNearVertices() public {
//         OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();
//         int256 tolerance = 1e16; // Adjust tolerance based on desired precision

//         for (uint256 i = 0; i < vertices.length; i++) {
//             for (int256 dx = -tolerance; dx <= tolerance; dx += tolerance) {
//                 for (int256 dy = -tolerance; dy <= tolerance; dy += tolerance) {
//                     if (dx == 0 && dy == 0) continue; // Skip the vertex itself

//                     OctagonGeometry.Vertex memory testVertex = OctagonGeometry.Vertex(vertices[i].x + dx, vertices[i].y + dy);
//                     bool isInside = octaGTestHelper.isVertexInsideOctagon(vertices, testVertex);

//                     emit log(string(abi.encodePacked("Testing near vertex ", Strings.toString(i), ": ", isInside ? "Inside" : "Outside")));
//                 }
//             }
//         }
//     }

//     function testFuzzCrossingEdges() public {
//         OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();
//         int256 moveDistance = 2e17;

//         for (uint256 i = 0; i < vertices.length; i++) {
//             OctagonGeometry.Vertex memory nextVertex = vertices[(i + 1) % vertices.length];
//             int256 edgeDirX = nextVertex.x - vertices[i].x;
//             int256 edgeDirY = nextVertex.y - vertices[i].y;
//             uint256 normFactor = sqrt(uint256(edgeDirX * edgeDirX + edgeDirY * edgeDirY));
//             edgeDirX = edgeDirX * int256(moveDistance) / int256(normFactor);
//             edgeDirY = edgeDirY * int256(moveDistance) / int256(normFactor);

//             OctagonGeometry.Vertex memory startInside = OctagonGeometry.Vertex((vertices[i].x + nextVertex.x) / 2, (vertices[i].y + nextVertex.y) / 2);
//             OctagonGeometry.Vertex memory endOutside = OctagonGeometry.Vertex(startInside.x + edgeDirX, startInside.y + edgeDirY);

//             bool startStatus = octaGTestHelper.isVertexInsideOctagon(vertices, startInside);
//             bool endStatus = octaGTestHelper.isVertexInsideOctagon(vertices, endOutside);

//             emit log(string(abi.encodePacked("Crossing edge ", Strings.toString(i), ": Start ", startStatus ? "Inside" : "Outside", ", End ", endStatus ? "Inside" : "Outside")));
//         }
//     }

//     function testFuzzRandomMovements() public {
//             OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();

//             for (uint256 i = 0; i < 70; i++) {
//                 int256 startX = int256(uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 40e18) - 20e18; // Random X within [-20, 20]
//                 int256 startY = int256(uint256(keccak256(abi.encodePacked(block.difficulty, i))) % 40e18) - 20e18; // Random Y within [-20, 20]
//                 int256 moveX = int256(uint256(keccak256(abi.encodePacked(block.number, i))) % 5e18) - 2.5e18; // Random move X within [-2.5, 2.5]
//                 int256 moveY = int256(uint256(keccak256(abi.encodePacked(block.timestamp + block.number, i))) % 5e18) - 2.5e18; // Random move Y within [-2.5, 2.5]


//                 OctagonGeometry.Vertex memory startPoint = OctagonGeometry.Vertex(startX, startY);
//                 OctagonGeometry.Vertex memory endPoint = OctagonGeometry.Vertex(startX + moveX, startY + moveY);

//                 bool startInside = octaGTestHelper.isVertexInsideOctagon(vertices, startPoint);
//                 bool endInside = octaGTestHelper.isVertexInsideOctagon(vertices, endPoint);

//                 // Adjusted logging using Strings.toString for uint256 conversion
//                 emit log(string(abi.encodePacked(
//                     "Movement ", Strings.toString(i),
//                     ": Start ", startInside ? "Inside" : "Outside",
//                     ", End ", endInside ? "Inside" : "Outside"
//                 )));
//             }
//     }

//     Ricochet Test

//     doesIntersect

//      // Test when lines should intersect
//     function testLinesShouldIntersect() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex(0, 0);
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex(10e18, 10e18);
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines(
//             OctagonGeometry.Vertex(0, 10e18),
//             OctagonGeometry.Vertex(10e18, 0)
//         );

//         (bool intersects, int256 ix, int256 iy) = octaGTestHelper.testDoesIntersect(P, V, S);
//         assertTrue(intersects, "Lines should intersect");
//         assertEq(ix, 5e18, "Intersection X coordinate is incorrect");
//         assertEq(iy, 5e18, "Intersection Y coordinate is incorrect");
//     }

//     // Test when lines are parallel and should not intersect
//     function testLinesShouldNotIntersect() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex(0, 0);
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex(10e18, 0);
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines(
//             OctagonGeometry.Vertex(0, 1e18),
//             OctagonGeometry.Vertex(10e18, 1e18)
//         );

//         (bool intersects,,) = octaGTestHelper.testDoesIntersect(P, V, S);
//         assertFalse(intersects, "Lines should not intersect");
//     }

//     // Test edge case where line segment endpoints touch but do not cross
//     function testTouchingLinesShouldIntersect() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex(0, 0);
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex(5e18, 5e18);
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines(
//             OctagonGeometry.Vertex(5e18, 5e18),
//             OctagonGeometry.Vertex(10e18, 10e18)
//         );

//         (bool intersects, int256 ix, int256 iy) = octaGTestHelper.testDoesIntersect(P, V, S);
//         assertTrue(intersects, "Touching lines should be considered intersecting");
//         assertEq(ix, 5e18, "Intersection X coordinate should be at the touching point");
//         assertEq(iy, 5e18, "Intersection Y coordinate should be at the touching point");
//     }

//     // Test with completely non-intersecting and non-parallel lines
//     function testCompletelyNonIntersectingLines() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex(0, 0);
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex(5e18, 5e18);
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines(
//             OctagonGeometry.Vertex(6e18, 6e18),
//             OctagonGeometry.Vertex(10e18, 10e18)
//         );

//         (bool intersects,,) = octaGTestHelper.testDoesIntersect(P, V, S);
//         assertFalse(intersects, "Lines should not intersect and should be completely separate");
//     }

//     function testSpecificIntersections() public {
//         // Example to ensure proper intersection is detected
//         OctagonGeometry.Vertex memory p = OctagonGeometry.Vertex({x: 1, y: 1});
//         OctagonGeometry.Vertex memory v = OctagonGeometry.Vertex({x: 9, y: 9}); // Endpoint of Q
//         OctagonGeometry.SideLines memory s = OctagonGeometry.SideLines({
//             start: OctagonGeometry.Vertex({x: 0, y: 10}),
//             end: OctagonGeometry.Vertex({x: 10, y: 0})
//         });

//         (bool intersects, int256 ix, int256 iy) = octaGTestHelper.testDoesIntersect(p, v, s);
//         console.log("Intersection Expected:");
//         console.logBool(intersects);
//         console.logInt(ix);
//         console.logInt(iy);
//         assertTrue(intersects, "Lines should intersect");
//         assertEq(ix, 5e18, "Intersection x-coordinate incorrect");
//         assertEq(iy, 5e18, "Intersection y-coordinate incorrect");
//     }

//     function testIntersectingLinesControl() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex({x: 2, y: 3});
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex({x: 8, y: 9});

//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines({
//             start: OctagonGeometry.Vertex({x: 2, y: 9}),
//             end: OctagonGeometry.Vertex({x: 8, y: 3})
//         });

//         (bool intersects, int256 ix, int256 iy) = octaGTestHelper.testDoesIntersect(P, V, S);
//         require(intersects, "Lines should intersect.");
//         require(ix == 5e18 && iy == 6e18, "Intersection should be at (5,6).");
//     }

//     function testIntersectingLinesNew() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex({x: 1, y: 1});
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex({x: 4, y: 4});

//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines({
//             start: OctagonGeometry.Vertex({x: 1, y: 4}),
//             end: OctagonGeometry.Vertex({x: 4, y: 1})
//         });

//         // Scale factor applied to expected results
//         int256 scaleFactor = 1000;
//         (bool intersects, int256 ix, int256 iy) = octaGTestHelper.testDoesIntersect(P, V, S);
//         require(intersects, "Lines should intersect.");
//         require(ix == 25e17 && iy == 25e17, "Intersection should be at (2.5,2.5).");
//     }

//     function testNonIntersectingLines() public {
//         // Define the first line from point (0,0) to (2,2)
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex({x: 3, y: 3});
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex({x: 4, y: 4});

//         // Define the second line from (3,0) to (3,4)
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines({
//             start: OctagonGeometry.Vertex({x: 5, y: 5}),
//             end: OctagonGeometry.Vertex({x: 6, y: 6})
//         });

//         // Check for no intersection
//         (bool intersects, int256 ix, int256 iy) = octaGTestHelper.testDoesIntersect(P, V, S);
//         require(!intersects, "Lines should not intersect.");
//     }

//     function testParallelLines() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex(0, 0);
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex(1, 1);
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines(OctagonGeometry.Vertex(0, 1), OctagonGeometry.Vertex(1, 2));
//         (bool intersects,,) = octaGTestHelper.testDoesIntersect(P, V, S);
//         require(!intersects, "Lines should not intersect.");
//     }

//     function testIntersectingAtPoint() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex(0, 0);
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex(3, 3);
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines(OctagonGeometry.Vertex(0, 3), OctagonGeometry.Vertex(3, 0));
//         (bool intersects, int256 ix, int256 iy) = octaGTestHelper.testDoesIntersect(P, V, S);
//         require(intersects, "Lines should intersect.");
//         require(ix == 15e17 && iy == 15e17, "Intersection should be at (1.5, 1.5)."); // Assuming scale factor for illustration
//     }

//     function testNonIntersectingLiness() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex(0, 0);
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex(1, 1);
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines(OctagonGeometry.Vertex(2, 2), OctagonGeometry.Vertex(3, 3));
//         (bool intersects,,) = octaGTestHelper.testDoesIntersect(P, V, S);
//         require(!intersects, "Lines should not intersect.");
//     }

//     function testVerticalHorizontalIntersectingLines() public {
//         OctagonGeometry.Vertex memory P = OctagonGeometry.Vertex(1, 0);
//         OctagonGeometry.Vertex memory V = OctagonGeometry.Vertex(1, 3);
//         OctagonGeometry.SideLines memory S = OctagonGeometry.SideLines(OctagonGeometry.Vertex(0, 2), OctagonGeometry.Vertex(2, 2));
//         (bool intersects, int256 ix, int256 iy) = octaGTestHelper.testDoesIntersect(P, V, S);
//         require(intersects, "Lines should intersect.");
//         require(ix == 1e18 && iy == 2e18, "Intersection should be at (1, 2)."); // Assuming scale factor for illustration
//     }

//     detectCollisionSideIndex

//     function testCollisionTopSide() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(0, 16e18);
//         OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(0, 1e18); // Moves upward
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         (uint256 index, OctagonGeometry.Vertex memory intersection) = octaGTestHelper.testDetectCollisionSideIndex(currentPosition, velocity, sides);

//         require(index == 2, "Incorrect side index for collision.");
//         assertApproxEqual(intersection.x, 0, 1e13, "Intersection x-coordinate mismatch.");
//         assertApproxEqual(intersection.y, 17e18, 1e13, "Intersection y-coordinate mismatch.");
//     }

//     function testCollisionRightSide() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(16e18, 0);
//         OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(1e18, 0); // Moves right
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         (uint256 index, OctagonGeometry.Vertex memory intersection) = octaGTestHelper.testDetectCollisionSideIndex(currentPosition, velocity, sides);
//         require(index == 0, "Incorrect side index for collision.");
//         require(intersection.x == 17e18 && intersection.y == 0, "Intersection should be at (17e18, 0).");
//     }

//     function testCollisionBottomSide() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(0, -16e18);
//         OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(0, -1e18); // Moves downward
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         (uint256 index, OctagonGeometry.Vertex memory intersection) = octaGTestHelper.testDetectCollisionSideIndex(currentPosition, velocity, sides);

//         // Consider adding a small tolerance for comparison due to potential minor inaccuracies in intersection calculation
//         bool xCorrect = intersection.x == 0;
//         bool yCorrect = (intersection.y >= -17e18 - 1e16 && intersection.y <= -17e18 + 1e16);

//         require(index == 6, "Incorrect side index for collision.");
//         require(xCorrect && yCorrect, "Intersection should be at (0, -17e18).");
//     }

//     function testCollisionLeftSide() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(-16e18, 0);
//         OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(-1e18, 0); // Moves left
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         (uint256 index, OctagonGeometry.Vertex memory intersection) = octaGTestHelper.testDetectCollisionSideIndex(currentPosition, velocity, sides);

//         bool xCorrect = (intersection.x >= -17e18 - 1e16 && intersection.x <= -17e18 + 1e16);
//         bool yCorrect = intersection.y == 0;

//         require(index == 4, "Incorrect side index for collision.");
//         require(xCorrect && yCorrect, "Intersection should be at (-17e18, 0).");
//     }

//     // Test collision on the Northeast diagonal
//     function testCollisionDiagonalNE() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(12e18, 12e18);
//         OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(1e18, 1e18); // Moves northeast
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         (uint256 index, OctagonGeometry.Vertex memory intersection) = octaGTestHelper.testDetectCollisionSideIndex(currentPosition, velocity, sides);

//         require(index == 1, "Incorrect side index for collision.");
//         assertApproxEqual(intersection.x, 12020814145924902580, 1e13, "Intersection x-coordinate mismatch.");
//         assertApproxEqual(intersection.y, 12020814145924902580, 1e13, "Intersection y-coordinate mismatch.");
//     }

//     // Test collision on the Northwest diagonal
//     function testCollisionDiagonalNW() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(-12e18, 12e18);
//         OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(-1e18, 1e18); // Moves northwest
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         (uint256 index, OctagonGeometry.Vertex memory intersection) = octaGTestHelper.testDetectCollisionSideIndex(currentPosition, velocity, sides);

//         require(index == 3, "Incorrect side index for collision.");
//         assertApproxEqual(intersection.x, -12020814145924902580, 1e13, "Intersection x-coordinate mismatch.");
//         assertApproxEqual(intersection.y, 12020814145924902580, 1e13, "Intersection y-coordinate mismatch.");
//     }

//     // Test collision on the Southeast diagonal
//     function testCollisionDiagonalSE() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(12e18, -12e18);
//         OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(1e18, -1e18); // Moves southeast
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         (uint256 index, OctagonGeometry.Vertex memory intersection) = octaGTestHelper.testDetectCollisionSideIndex(currentPosition, velocity, sides);

//         require(index == 7, "Incorrect side index for collision.");
//         assertApproxEqual(intersection.x, 12020814145924902580, 1e13, "Intersection x-coordinate mismatch.");
//         assertApproxEqual(intersection.y, -12020814145924902580, 1e13, "Intersection y-coordinate mismatch.");
//     }

//     // Test collision on the Southwest diagonal
//     function testCollisionDiagonalSW() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(-12e18, -12e18);
//         OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(-1e18, -1e18); // Moves southwest
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         (uint256 index, OctagonGeometry.Vertex memory intersection) = octaGTestHelper.testDetectCollisionSideIndex(currentPosition, velocity, sides);

//         require(index == 5, "Incorrect side index for collision.");
//         assertApproxEqual(intersection.x, -12020814145924902580, 1e13, "Intersection x-coordinate mismatch.");
//         assertApproxEqual(intersection.y, -12020814145924902580, 1e13, "Intersection y-coordinate mismatch.");
//     }

//     function testRandomCollisionDetection() public {
//         uint256 fails = 0;
//         OctagonGeometry.SideLines[8] memory sides = octaGTestHelper.generateOctagonSideLengths(octaGTestHelper.generateOctagonVertices());
//         for (uint i = 0; i < 50; i++) {
//             int256 randX = random(0, 34000e18) - 17000e18; // Adjusted for a range around the octagon radius
//             int256 randY = random(1, 34000e18) - 17000e18;
//             int256 randDx = random(2, 20e18) - 10e18; // Smaller range for velocity
//             int256 randDy = random(3, 20e18) - 10e18;

//             OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(randX, randY);
//             OctagonGeometry.Vertex memory velocity = OctagonGeometry.Vertex(randDx, randDy);

//             (bool found, uint256 index, OctagonGeometry.Vertex memory intersection) = tryDetectCollision(currentPosition, velocity, sides);

//             if (!found) {
//                 fails++;
//                 continue;  // or handle the failure case appropriately
//             }

//             // Assert or log the valid intersection details
//             emit log_named_uint("Test Passed with index", index);
//             emit log_named_int("Intersection X", intersection.x);
//             emit log_named_int("Intersection Y", intersection.y);
//         }
//         assertLt(fails, 10, "Too many failed intersection detections"); // Optionally ensure failures are within acceptable limits
//     }

//     function testCalculateRicochetAdvanced() public {
//         // Setup the initial position and velocity towards a known side of the octagon
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(16e18, 0); // Close to the right side
//         int256 dx = 5e18; // Move right
//         int256 dy = 0; // No vertical movement

//         // Expected values for ricochet, assuming normal calculation and perfect collision handling
//         int256 expectedRicochetDx = -5e18; // Should reverse the horizontal direction
//         int256 expectedRicochetDy = 0; // Should remain the same

//         // Calculate the actual ricochet
//         (int256 ricochetDx, int256 ricochetDy) = octaGTestHelper.testCalculateRicochet(currentPosition, dx, dy);

//         // Log for debugging
//         console.log("Expected Dx:");
//         console.logInt(expectedRicochetDx);
//         console.log("Expected Dy:");
//         console.logInt(expectedRicochetDy);
//         console.log("Actual Dx:");
//         console.logInt(ricochetDx);
//         console.log("Actual Dy:");
//         console.logInt(ricochetDy);


//         // Assertions to verify the correctness
//         require(ricochetDx == expectedRicochetDx, "Ricochet Dx calculation failed");
//         require(ricochetDy == expectedRicochetDy, "Ricochet Dy calculation failed");
//     }

//     function testRicochetFuzzing() public {
//         for (uint i = 0; i < 20; i++) {
//             // Generate random position within bounds, converting to signed explicitly
//             int256 x = int256(random(0, 34e18)) - 17e18;
//             int256 y = int256(random(0, 34e18)) - 17e18;
//             // Generate random velocity
//             int256 dx = int256(random(0, 2e18)) - 1e18;
//             int256 dy = int256(random(0, 2e18)) - 1e18;

//             // Create a vertex for current position
//             OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(x, y);

//             // Call calculateRicochet to see how it handles these random inputs
//             (int256 ricochetDx, int256 ricochetDy) = octaGTestHelper.testCalculateRicochet(currentPosition, dx, dy);

//             // Use `require` for conditional checking with error messages
//             require(ricochetDx != dx || ricochetDy != dy, "Ricochet should change direction");
//         }
//     }

//     function testRicochetFuzzing() public {
//         OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();
//         for (uint i = 0; i < 20; i++) {
//             OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();
//             int256 startX = int256(uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 34e18) - 17e18; // Random X within [-20, 20]
//             int256 startY = int256(uint256(keccak256(abi.encodePacked(block.difficulty, i))) % 34e18) - 17e18; // Random Y within [-20, 20]
//             int256 moveX = int256(uint256(keccak256(abi.encodePacked(block.number, i))) % 34e18) - 2.5e18; // Random move X within [-2.5, 2.5]
//             int256 moveY = int256(uint256(keccak256(abi.encodePacked(block.timestamp + block.number, i))) % 34e18) - 2.5e18; // Random move Y within [-2.5, 2.5]

//             OctagonGeometry.Vertex memory endPoint = OctagonGeometry.Vertex(startX + moveX, startY + moveY);

//             if(octaGTestHelper.isVertexInsideOctagon(vertices, endPoint)){
//                 OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(startX, startY);
//                 (int256 ricochetDx, int256 ricochetDy) = octaGTestHelper.testCalculateRicochet(currentPosition, moveX, moveY);
//                 console.logInt(ricochetDx);
//                 console.logInt(ricochetDy);
//                 require((ricochetDx != startX || ricochetDy != startY), "Ricochet calculation should alter the direction or magnitude.");
//             }
//         }
//     }

//     function testRicochetNearBoundary() public {
//         OctagonGeometry.Vertex memory startPosition = OctagonGeometry.Vertex(10.5e18, 0);
//         int256 initialDx = -1e18;
//         int256 initialDy = 0;

//         int256 expectedPostRicochetDx = 1e18;
//         int256 expectedPostRicochetDy = 0;

//         (int256 ricochetDx, int256 ricochetDy) = octaGTestHelper.testCalculateRicochet(startPosition, initialDx, initialDy);

//         require(ricochetDx == expectedPostRicochetDx, "Ricochet Dx calculation failed");
//         require(ricochetDy == expectedPostRicochetDy, "Ricochet Dy should remain unchanged");
//     }

//     function testDiagonalRicochet() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(17e18, 17e18);
//         int256 movementMagnitude = 1e18;  // One unit, scaled

//         int256 dx = -movementMagnitude;  // Moving diagonally left-down
//         int256 dy = -movementMagnitude;

//         (int256 ricochetDx, int256 ricochetDy) = octaGTestHelper.testCalculateRicochet(currentPosition, dx, dy);

//         // Adjust expectations based on repeated test outcomes and understanding of reflection mechanics
//         int256 expectedRicochetDx = -dx;  // Assuming reflection reverses x-component
//         int256 expectedRicochetDy = dy;   // Assuming reflection maintains y-component's direction
//         console.log("Expected Ricochet Dx:");
//         console.logInt(expectedRicochetDx);
//         console.log("Actual:");
//         console.logInt(ricochetDx);

//         console.log("Expected Ricochet Dy:");
//         console.logInt(expectedRicochetDy);
//         console.log("Actual:");
//         console.logInt(ricochetDy);
//         assertEq(ricochetDx, expectedRicochetDx, "Ricochet dx does not match expected");
//         assertEq(ricochetDy, expectedRicochetDy, "Ricochet dy does not match expected");
//     }

//     function testRicochetCalculations() public {
//         OctagonGeometry.Vertex memory currentPosition;
//         int256 dx;
//         int256 dy;
//         int256 ricochetDx;
//         int256 ricochetDy;

//         // Test several points around the octagon
//         int256[] memory testPointsX = new int256[](4);
//         int256[] memory testPointsY = new int256[](4);
//         testPointsX[0] = 17e18; testPointsY[0] = 17e18;  // Near a vertex
//         testPointsX[1] = 10e18; testPointsY[1] = 10e18;  // Midpoint of a side
//         testPointsX[2] = 5e18;  testPointsY[2] = 15e18;  // Edge close to the center
//         testPointsX[3] = 0;     testPointsY[3] = 17e18;  // On an edge

//         for (uint i = 0; i < 4; i++) {
//             currentPosition = OctagonGeometry.Vertex(testPointsX[i], testPointsY[i]);
//             dx = 1e18;  // Consistent direction to simplify
//             dy = 1e18;

//             (ricochetDx, ricochetDy) = octaGTestHelper.testCalculateRicochet(currentPosition, dx, dy);

//             console.log("Test Point: ", i);
//             console.log("Input DX: ");
//             console.logInt(dx);
//             console.log("Input DY: ");
//             console.logInt(dy);
//             console.log("Ricochet DX: ");
//             console.logInt(ricochetDx);
//             console.log("Ricochet DY: ");
//             console.logInt(ricochetDy);

//             // Perform assertions or checks
//             require(ricochetDx != 0 || ricochetDy != 0, "Ricochet should not be zero vector");
//         }
//     }

//     function testSpecificRicochetCalculation() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(10e18, 0);  // Assuming radius is 10e18
//         int256 dx = 1e18;
//         int256 dy = 0;

//         (int256 ricochetDx, int256 ricochetDy) = octaGTestHelper.testCalculateRicochet(currentPosition, dx, dy);

//         // Expected values based on manual calculation
//         int256 expectedRicochetDx = -1e18;
//         int256 expectedRicochetDy = 0;

//         console.log("Expected Ricochet Dx:");
//         console.logInt(expectedRicochetDx);
//         console.log("Expected Ricochet Dy:");
//         console.logInt(expectedRicochetDy);
//         console.log("Actual Ricochet Dx:");
//         console.logInt(ricochetDx);
//         console.log("Actual Ricochet Dy:");
//         console.logInt(ricochetDy);

//         require(ricochetDx == expectedRicochetDx, "Ricochet Dx does not match expected");
//         require(ricochetDy == expectedRicochetDy, "Ricochet Dy does not match expected");
//     }

//     function testDiagonalRicochetCalculation() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(7.07e18, 7.07e18); // Assuming radius is 10 and sqrt(2) ≈ 1.414
//         int256 dx = 1e18;  // Moving diagonally
//         int256 dy = 1e18;

//         (int256 ricochetDx, int256 ricochetDy) = octaGTestHelper.testCalculateRicochet(currentPosition, dx, dy);

//         // Expected values based on manual calculation
//         int256 expectedRicochetDx = -1e18;
//         int256 expectedRicochetDy = -1e18;


//         require(ricochetDx == expectedRicochetDx, "Ricochet Dx does not match expected");
//         require(ricochetDy == expectedRicochetDy, "Ricochet Dy does not match expected");
//     }

//     function testComplexRicochetCalculation() public {
//         OctagonGeometry.Vertex memory currentPosition = OctagonGeometry.Vertex(9.9e18, 1e18); // Slightly off-center from the right vertex
//         int256 dx = 3e18;  // Unusual incoming dx
//         int256 dy = 4e18;  // Unusual incoming dy

//         (int256 ricochetDx, int256 ricochetDy) = octaGTestHelper.testCalculateRicochet(currentPosition, dx, dy);

//         // Manually calculate expected values for an oblique collision
//         int256 expectedRicochetDx = -3e18;  // Assuming an exact mirror bounce for simplicity in this example
//         int256 expectedRicochetDy = 4e18;   // dy remains unchanged due to horizontal normal

//         console.log("Expected Ricochet Dx:");
//         console.logInt(expectedRicochetDx);
//         console.log("Expected Ricochet Dy:");
//         console.logInt(expectedRicochetDy);

//         require(ricochetDx == expectedRicochetDx, "Ricochet Dx does not match expected");
//         require(ricochetDy == expectedRicochetDy, "Ricochet Dy does not match expected");
//     }

//     FIND VALID DIRECTION

//     Working
//     function testFindValidDirection() public {
//         OctagonGeometry.Vertex[8] memory octagonVertices = octaGTestHelper.generateOctagonVertices();

//         OctagonGeometry.Vertex memory centerPosition = OctagonGeometry.Vertex(0, 0);
//         (int256 dx, int256 dy) = octaGTestHelper.testFindValidDirection(centerPosition, octagonVertices);
//         console.log("Direction from center: ");
//         console.logInt(dx);
//         console.logInt(dy);
//         assertTrue(dx != 0 || dy != 0, "Function should find a valid direction from the center of the octagon.");

//         OctagonGeometry.Vertex memory edgePosition = OctagonGeometry.Vertex(17e18, 0);
//         (dx, dy) = octaGTestHelper.testFindValidDirection(edgePosition, octagonVertices);
//         console.log("Direction from edge (17,0): ");
//         console.logInt(dx);
//         console.logInt(dy);
//         assertTrue(dx != 0 || dy != 0, "Function should find a valid direction from the edge of the octagon.");

//         OctagonGeometry.Vertex memory outsidePosition = OctagonGeometry.Vertex(18e18, 0); 
//         vm.expectRevert("No valid move found");
//         octaGTestHelper.testFindValidDirection(outsidePosition, octagonVertices);
//     }

//     function testFindValidDirectionFromVertices() public {
//         OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();
        
//         for (uint i = 0; i < 8; i++) {
//             (int256 dx, int256 dy) = octaGTestHelper.testFindValidDirection(vertices[i], vertices);
//             console.log("Direction from vertex ", i, ": ");
//             console.logInt(dx);
//             console.logInt(dy);
//             assertTrue(dx != 0 || dy != 0, string(abi.encodePacked("Valid direction should be found from vertex ", Strings.toString(i))));
//         }
//     }

//     function testBoundaryConditions() public {
//         OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();
        
//         // Test halfway between two vertices
//         for (uint i = 0; i < 8; i++) {
//             OctagonGeometry.Vertex memory midpoint = OctagonGeometry.Vertex(
//                 (vertices[i].x + vertices[(i+1) % 8].x) / 2,
//                 (vertices[i].y + vertices[(i+1) % 8].y) / 2
//             );
            
//             (int256 dx, int256 dy) = octaGTestHelper.testFindValidDirection(midpoint, vertices);
//             console.log("Direction from midpoint of edge ", i, ": ");
//             console.logInt(dx);
//             console.logInt(dy);
//             assertTrue(dx != 0 || dy != 0, string(abi.encodePacked("Valid direction should be found from midpoint of edge ", Strings.toString(i))));
//         }
//     }

//     function testRandomPositions() public {
//         OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();
        
//         for (uint i = 0; i < 20; i++) {
//             int256 randomX = int256(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i))) % 40e18) - 20e18;
//             int256 randomY = int256(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i))) % 40e18) - 20e18;
            
//             OctagonGeometry.Vertex memory randomPosition = OctagonGeometry.Vertex(randomX, randomY);
//             try octaGTestHelper.testFindValidDirection(randomPosition, vertices) returns (int256 dx, int256 dy) {
//                 console.log("Random Test");
//                 console.log(i);
//                 console.log("Position x");
//                 console.logInt(randomX);
//                 console.log("Position y");
//                 console.logInt(randomY);
//                 console.log("Direction x");
//                 console.logInt(dx);
//                 console.log("Direction y");
//                 console.logInt(dy);
//                 assertTrue(dx != 0 || dy != 0, string(abi.encodePacked("Valid direction should be found from random position ", Strings.toString(i))));
//             } catch {
//                 console.log("Random Test failed to find direction.");
//                 console.log(i);
//                 console.log("Position x");
//                 console.logInt(randomX);
//                 console.log("Position y");
//                 console.logInt(randomY);
//                 console.log("Direction x");
//             }
//         }
//     }

//     Left to test
    
//     Fuzz testing
//     function testFuzz_FindValidDirection(uint256 seed) public {
//         vm.assume(seed < 1e18);  // Ensuring reasonable inputs
//         OctagonGeometry.Vertex[8] memory vertices = octaGTestHelper.generateOctagonVertices();

//         // Generate random position within bounds
//         int256 x = int256(seed % 20e18) - 10e18;
//         int256 y = int256(seed / 1e9 % 20e18) - 10e18;
//         OctagonGeometry.Vertex memory randomPosition = OctagonGeometry.Vertex(x, y);

//         try octaGTestHelper.testFindValidDirection(randomPosition, vertices) returns (int256 dx, int256 dy) {
//             assertTrue(dx != 0 || dy != 0, "Valid direction found");
//         } catch {
//             emit log("Failed to find direction for position: ");
//             console.log("X:");
//             console.logInt(x);
//             console.log("Y:");
//             console.logInt(y);
//         }
//     }

//     Invariant testing
//     function invariant_ParticipantsConsistency() public {
//         // Assuming MAX_PARTICIPANTS is a constant that can be accessed directly
//         uint256 maxParticipants = octaGTestHelper.MAX_PARTICIPANTS();
//         uint256 currentParticipants = octaGTestHelper.getNumberOfParticipants();
//         assertTrue(currentParticipants <= maxParticipants, "Max participants exceeded");

//         // Assuming generateOctagonVertices() is a function returning an array of Vertex
//         OctagonGeometry.Vertex[8] memory octagonVertices = octaGTestHelper.generateOctagonVertices();

//         for (uint256 i = 0; i < currentParticipants; i++) {
//             (int256 x, int256 y) = octaGTestHelper.getParticipantPosition(i);
//             OctagonGeometry.Vertex memory participantPosition = OctagonGeometry.Vertex(x, y);

//             // Checking if the participant position is inside the octagon
//             assertTrue(octaGTestHelper.isVertexInsideOctagon(octagonVertices, participantPosition),
//                 "Participant should be inside the octagon");
//         }
//     }


//     function testReflection() public {
//         int256 dx = -100;
//         int256 dy = -100;
//         int256 normalX = 0;
//         int256 normalY = 100;

//         int256 dp = octaGTestHelper.testDotProduct(dx, dy, normalX, normalY);
//         console.log("Dot Product:");
//         console.logInt(dp);

//         int256 ricochetDx = -dx;
//         int256 ricochetDy = -dy;
//         console.log("Direct Reflection - Dx: , Dy:");
//         console.logInt(ricochetDx);
//         console.logInt(ricochetDy);

//         ricochetDx = dx - 2 * dp * normalX;
//         ricochetDy = dy - 2 * dp * normalY;
//         console.log("Calculated Reflection - Dx: , Dy:");
//         console.logInt(ricochetDx);
//         console.logInt(ricochetDy);
//         assertEq(dp, 0, "Dot product should be 0 for perpendicular vectors");
//         assertEq(ricochetDx, -dx, "Ricochet Dx should directly invert Dx");
//         assertEq(ricochetDy, -dy, "Ricochet Dy should directly invert Dy");
//     }


//     function testMovementIntoWinningCircle() public {
//         int256 initialX = 2e18; 
//         int256 initialY = 2e18;
//         int256 moveToX = -1.3e18;
//         int256 moveToY = -1.3e18;

//         int256 newX = initialX + moveToX;
//         int256 newY = initialY + moveToY;

//         console.log("Initial position (x, y):");
//         console.logInt(initialX);
//         console.logInt(initialY);
//         console.log("Movement (dx, dy):");
//         console.logInt(moveToX);
//         console.logInt(moveToY);
//         console.log("New position (x, y):");
//         console.logInt(newX);
//         console.logInt(newY);

//         OctagonGeometry.Vertex memory newPosition = OctagonGeometry.Vertex(newX, newY);
//         bool isInside = octaGTestHelper.testIsWithinWinningCircle(newPosition);
//         console.log("Is within winning circle:", isInside);

//         // Assert that the new position is inside the winning circle
//         assertTrue(isInside, "The point should be inside the winning circle after movement.");
//     }
    
//     function testRunToWinningCircle() public {
//         uint256 tokenId = 1;  // Assuming you have a valid tokenId to test with
//         uint256 seed = 209385021;  // Hardcoded seed for testing
//         bool hasReachedTarget = false;
//         uint256 movementCount = 0;

//         octaGTestHelper.initializeParticipantForTest(tokenId, 17e18, 0);  // Setting initial position for test

//         while (!hasReachedTarget) {
//             hasReachedTarget = octaGTestHelper.testCalculateMovement(tokenId, seed);
//             (int256 x, int256 y) = octaGTestHelper.getParticipantPosition(tokenId);  // Retrieving the position

//             console.log("Movement:", movementCount);
//             console.log("Position X:");
//             console.logInt(x);
//             console.log("Position Y:");
//             console.logInt(y);

//             if (hasReachedTarget) {
//                 console.log("Winner determined");
//                 console.log("Winning X position:");
//                 console.logInt(x);
//                 console.log("Winning Y position:");
//                 console.logInt(y);
//                 break;
//             }

//             // Update seed for next movement
//             seed = uint256(keccak256(abi.encode(seed)));
//             movementCount++;
//         }

//         assertTrue(hasReachedTarget, "Should reach the winning circle");
//     }

//     Bet settingphantom@HP-elitebook:~/Documents/OctaG/contracts$ forge build 

//     function random(uint _seed, uint256 _range) internal view returns (int256) {
//         uint256 randomHash = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, _seed)));
//         return int256(randomHash % _range);
//     }

//     Helpers
//     function sqrt(uint256 x) internal pure returns (uint256) {
//         if (x == 0) return 0;
//         uint256 z = (x + 1) / 2;
//         uint256 y = x;
//         while (z < y) {
//             y = z;
//             z = (x / z + z) / 2;
//         }
//         return y;
//     }

//     function abs(int256 x) private pure returns (int256) {
//         return x >= 0 ? x : -x;
//     }

//     Helper function to check values within a small tolerance
//     function assertApproxEqual(int256 actual, int256 expected, int256 tolerance, string memory message) internal {
//         require((actual >= expected - tolerance) && (actual <= expected + tolerance), message);
//     }

// }


// contract MockERC721 is ERC721 {
//     constructor() ERC721("MockERC721", "MERC721") {}

//     function mint(address to, uint256 tokenId) public {
//         _mint(to, tokenId);
//     }
// }