const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("mastermind-module", (m) => {
  const mastermind = m.contract("Mastermind");

  m.call(mastermind, "launch", []);

  return { mastermind };
});