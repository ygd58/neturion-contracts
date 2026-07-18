// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SealedBidAuctionExample.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        // Deploy with mock decrypter address, 1 hour deadline, 0 fee
        new SealedBidAuctionExample(
            address(0x94),
            block.timestamp + 3600,
            0
        );
        vm.stopBroadcast();
    }
}
