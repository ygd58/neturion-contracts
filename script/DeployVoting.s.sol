// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "../src/PrivateVoting.sol";

contract DeployVoting is Script {
    function run() external {
        vm.startBroadcast();
        new PrivateVoting();
        vm.stopBroadcast();
    }
}
