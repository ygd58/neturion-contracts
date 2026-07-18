import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const NeturionJobBoardModule = buildModule("NeturionJobBoardModule", (m) => {
  const jobBoard = m.contract("NeturionJobBoard");
  return { jobBoard };
});

export default NeturionJobBoardModule;
