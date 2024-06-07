const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Mastermind", function () {
  let Mastermind;
  let mastermind;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, addr1, addr2, _] = await ethers.getSigners();
    Mastermind = await ethers.getContractFactory("Mastermind");
    mastermind = await Mastermind.deploy();
    await mastermind.deployed();
  });

  it("Should create a game", async function () {
    const secretCodeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("1234"));
    await mastermind.connect(addr1).createGame(secretCodeHash, { value: ethers.utils.parseEther("1") });
    const game = await mastermind.games(1);
    expect(game.codeMaker).to.equal(addr1.address);
    expect(game.stake).to.equal(ethers.utils.parseEther("1"));
  });

  it("Should join a game", async function () {
    const secretCodeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("1234"));
    await mastermind.connect(addr1).createGame(secretCodeHash, { value: ethers.utils.parseEther("1") });
    await mastermind.connect(addr2).joinGame(1, { value: ethers.utils.parseEther("1") });
    const game = await mastermind.games(1);
    expect(game.codeBreaker).to.equal(addr2.address);
    expect(game.stake).to.equal(ethers.utils.parseEther("2"));
  });

  it("Should submit a guess", async function () {
    const secretCodeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("1234"));
    await mastermind.connect(addr1).createGame(secretCodeHash, { value: ethers.utils.parseEther("1") });
    await mastermind.connect(addr2).joinGame(1, { value: ethers.utils.parseEther("1") });

    const guess = [1, 2, 3, 4];
    await mastermind.connect(addr2).submitGuess(1, guess);
    const game = await mastermind.games(1);
    expect(game.numGuesses).to.equal(1);
  });

  it("Should reveal code and end game", async function () {
    const secretCodeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("1234"));
    await mastermind.connect(addr1).createGame(secretCodeHash, { value: ethers.utils.parseEther("1") });
    await mastermind.connect(addr2).joinGame(1, { value: ethers.utils.parseEther("1") });

    const code = [1, 2, 3, 4];
    await mastermind.connect(addr1).revealCode(1, code);
    const game = await mastermind.games(1);
    expect(game.active).to.equal(false);
  });

  it("Should handle AFK accusation", async function () {
    const secretCodeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("1234"));
    await mastermind.connect(addr1).createGame(secretCodeHash, { value: ethers.utils.parseEther("1") });
    await mastermind.connect(addr2).joinGame(1, { value: ethers.utils.parseEther("1") });

    // Simulate time passing
    await network.provider.send("evm_increaseTime", [TIME_LIMIT + 1]);
    await network.provider.send("evm_mine");

    await mastermind.connect(addr1).accuseAFK(1);
    const game = await mastermind.games(1);
    expect(game.active).to.equal(false);
  });
});
