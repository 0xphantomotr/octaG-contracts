// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Trigonometry} from "./utils/Trigonometry.sol";

contract OctagonGeometry {

    struct Vertex {
        int256 x;
        int256 y;
    }

    struct SideLines {
        Vertex start;
        Vertex end;
    }

    uint256 public constant RADIUS = 17e18;
    Vertex private center = Vertex(0, 0);
    
    function generateOctagonVertices() public view returns (Vertex[8] memory) {

        Vertex[8] memory vertices;

        uint256 angleIncrement = (Trigonometry.PI / 4);

        for(uint256 i = 0; i < 8; i++) {
            uint256 angle = angleIncrement * i;
            int256 x = Trigonometry.cos(angle) * int256(RADIUS) / 1e18;
            int256 y = Trigonometry.sin(angle) * int256(RADIUS) / 1e18;

            vertices[i].x = center.x + x;
            vertices[i].y = center.y + y;
        }
        
        return vertices;
    }

    function generateOctagonSideLengths(Vertex[8] memory vertices) public pure returns (SideLines[8] memory) {
        SideLines[8] memory sidesLines;

        for (uint256 i = 0; i < vertices.length; i++) {
            sidesLines[i].start = vertices[i];
            sidesLines[i].end = vertices[(i + 1) % vertices.length]; // Correctly assign the end vertex
        }

        return sidesLines;
    }
}