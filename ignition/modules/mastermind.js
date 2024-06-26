const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("mastermind_module", (m) => {
  const mastermind = m.contract("Mastermind");

  return { mastermind };
});