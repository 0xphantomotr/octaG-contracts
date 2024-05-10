// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "MERC721") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    // Checks if the token is already minted
    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }
}