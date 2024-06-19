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
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("1") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);


        const game = await mastermind.games(1);
        expect(game.currentTurn.secretCodeHash).to.deep.equal(secretCodeHash);
    });

    it("Should submit guess and feedback", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("1") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("1") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;
        const nAddr = addr == addr1 ? addr1 : addr2;

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);
        await mastermind.connect(nAddr).submitGuess(1, [1, 3, 4, 8]);
        await mastermind.connect(addr).submitFeedback(1, [2, 1, 1, 0]);


        const game = await mastermind.games(1);
        expect(game.currentTurn.guess[0].map(Number)).to.deep.equal([1, 3, 4, 8]);
        expect(game.currentTurn.feedback[0].map(Number)).to.deep.equal([2, 1, 1, 0]);
    });

    it("Should change turn by breaking the code", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("1") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("1") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;
        const nAddr = addr == addr1 ? addr1 : addr2;

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);
        await mastermind.connect(nAddr).submitGuess(1, [1, 2, 3, 4]);
        await mastermind.connect(addr).submitFeedback(1, [2, 2, 2, 2]);
        


        const game = await mastermind.games(1);
        expect(game.currentTurn.guess[0].map(Number)).to.deep.equal([1, 3, 4, 8]);
        expect(game.currentTurn.feedback[0].map(Number)).to.deep.equal([2, 1, 1, 0]);
    });

});