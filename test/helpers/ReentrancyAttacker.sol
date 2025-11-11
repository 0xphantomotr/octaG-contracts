// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOctaG {
    function placeBet(address collectionId, uint256 tokenId) external payable;
}

contract ReentrancyAttacker {
    enum AttackMode { None, PlaceBet }

    AttackMode public mode;
    IOctaG public target;
    address public collection;
    uint256 public tokenId;
    bool public lastSuccess;
    uint256 public triggerCount;

    event AttackTriggered(AttackMode mode, bool success);

    function configure(IOctaG _target, address _collection, uint256 _tokenId, AttackMode _mode) external {
        target = _target;
        collection = _collection;
        tokenId = _tokenId;
        mode = _mode;
        lastSuccess = false;
        triggerCount = 0;
    }

    receive() external payable {
        if (mode == AttackMode.PlaceBet && address(target) != address(0)) {
            (bool success, ) = address(target).call{value: 0}(
                abi.encodeWithSelector(IOctaG.placeBet.selector, collection, tokenId)
            );
            lastSuccess = success;
            triggerCount += 1;
            emit AttackTriggered(mode, success);
        } else {
            lastSuccess = false;
            triggerCount += 1;
            emit AttackTriggered(mode, false);
        }
    }
}
