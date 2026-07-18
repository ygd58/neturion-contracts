// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "../src/AgentNetwork.sol";

contract DeployAgent is Script {
   function run() external {
       vm.startBroadcast();
       new AgentNetwork();
       vm.stopBroadcast();
   }
}
