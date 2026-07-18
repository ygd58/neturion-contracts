// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "../src/DataMarketplace.sol";

contract DeployMarketplace is Script {
    function run() external {
        vm.startBroadcast();
        new DataMarketplace();
        vm.stopBroadcast();
    }
}
