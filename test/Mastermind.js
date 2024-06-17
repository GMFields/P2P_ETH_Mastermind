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
    });

    it("Should create a game", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("1") });
        await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("1") });
        const game = await mastermind.games(1);
        expect(game.createUser).to.equal(addr1.address);
        expect(game.stake).to.equal(ethers.parseEther("2"));
    });

    it("Should submit code" , async function () {   
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("1") });
        await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("1") });

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr1).submitCode(1, secretCodeHash);
        const game = await mastermind.games(1);
        expect(game).to.deep.equal(secretCodeHash);
    });
});