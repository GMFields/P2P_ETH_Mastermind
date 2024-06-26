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
    
    it("Should create & join a game", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("0.000000000000000001") });

        const game = await mastermind.games(1);
        expect(game.createUser).to.equal(addr1.address);
        expect(game.stake).to.equal(ethers.parseEther("0.000000000000000002"));
    });

    it("Should join random game", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        await mastermind.connect(addr2)["joinGameRandom()"]({ value: ethers.parseEther("0.000000000000000001") });
        
        const game = await mastermind.games(1);
        expect(game.joinUser).to.equal(addr2.address);
        expect(game.stake).to.equal(ethers.parseEther("0.000000000000000002"));
    });
        
        
    it("Should submit code" , async function () {   
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("0.000000000000000001") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);
        
        const game = await mastermind.games(1);
        expect(game.currentTurn.secretCodeHash).to.equal(secretCodeHash);
    });

    it("Should submit guess and feedback", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("0.000000000000000001") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;
        const nAddr = addr == addr1 ? addr2 : addr1;
        
        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);
        await mastermind.connect(nAddr).submitGuess(1, [1, 3, 4, 8]);
        await mastermind.connect(addr).submitFeedback(1, [2, 1, 1, 0]);
            
        const game = await mastermind.games(1);
        expect(game.currentTurn.guess[0].map(Number)).to.deep.equal([1, 3, 4, 8]);
        expect(game.currentTurn.feedback[0].map(Number)).to.deep.equal([2, 1, 1, 0]);
    });
            
    it("Should test if user is AFK", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("0.000000000000000001") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);
        await mastermind.connect(addr).accuseAfk(1);

        await new Promise(r => setTimeout(r, 10000));
        await mastermind.connect(addr).verifyAfk(1);   

        const game = await mastermind.games(1);
        expect(game.active).to.deep.equal(false);
    });


    it("Should test if user answer too late after accused of AFK", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("0.000000000000000001") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;
        const nAddr = addr == addr1 ? addr2 : addr1;

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);
        await mastermind.connect(addr).accuseAfk(1);

        await new Promise(r => setTimeout(r, 10000));
        await mastermind.connect(nAddr).submitGuess(1, [1, 3, 4, 8]);
        

        const game = await mastermind.games(1);
        expect(game.active).to.deep.equal(false);
    });

    it("Should break the code and check cheating", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("0.000000000000000001") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;
        const nAddr = addr == addr1 ? addr2 : addr1;

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);
        await mastermind.connect(nAddr).submitGuess(1, [2, 1, 4, 3]);
        await mastermind.connect(addr).submitFeedback(1, [1, 1, 1, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [1, 2, 3, 4]);
        await mastermind.connect(addr).submitFeedback(1, [2, 2, 2, 2]);
        
        const game = await mastermind.games(1);
        expect(game.currentTurn.finished).to.deep.equal(true);
        
        await mastermind.connect(addr).revealCode(1, [1, 2, 3, 4]);
        await mastermind.connect(nAddr).accuseCheating(1, 0);

        const game2 = await mastermind.games(1);
        expect(game2.active).to.deep.equal(false);
    });

    it("Should change turn by breaking the code", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("0.000000000000000001") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;
        const nAddr = addr == addr1 ? addr2 : addr1;

        const secretCodeHash = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash);
        await mastermind.connect(nAddr).submitGuess(1, [1, 2, 3, 4]);
        await mastermind.connect(addr).submitFeedback(1, [2, 2, 2, 2]);
        
        const game = await mastermind.games(1);
        expect(game.currentTurn.finished).to.deep.equal(true);
        
        await mastermind.connect(addr).revealCode(1, [1, 2, 3, 4]);
        const secretCodeHash2 = ethers.keccak256(ethers.toUtf8Bytes("4321"));

        
        await mastermind.connect(nAddr).submitCode(1, secretCodeHash2);
        
        const game2 = await mastermind.games(1);
        expect(game2.currentTurn.secretCodeHash).to.deep.equal(secretCodeHash2);
    });

    it("Should test finish game", async function () {
        await mastermind.connect(addr1).createGame(true, addr2, { value: ethers.parseEther("0.000000000000000001") });
        const tx = await mastermind.connect(addr2).joinGame(1, { value: ethers.parseEther("0.000000000000000001") });
        const receipt = await tx.wait();
        const args = receipt.logs[0].args;
        const addr = args[2] == addr1.address ? addr1 : addr2;
        const nAddr = addr == addr1 ? addr2 : addr1;

        // Turn 1
        const secretCodeHash1 = ethers.keccak256(ethers.toUtf8Bytes("1234"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash1);
        await mastermind.connect(nAddr).submitGuess(1, [4, 2, 3, 1]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [4, 2, 3, 1]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [4, 2, 3, 1]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [4, 2, 3, 1]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [1, 2, 3, 4]);
        await mastermind.connect(addr).submitFeedback(1, [2, 2, 2, 2]);
        await mastermind.connect(addr).revealCode(1, [1, 2, 3, 4]);
 
        // Turn 2
        const secretCodeHash2 = ethers.keccak256(ethers.toUtf8Bytes("2134"));
        await mastermind.connect(nAddr).submitCode(1, secretCodeHash2);
        await mastermind.connect(addr).submitGuess(1, [4, 1, 3, 1]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [4, 1, 3, 1]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [4, 1, 3, 1]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [4, 1, 3, 1]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [2, 1, 3, 4]);
        await mastermind.connect(nAddr).submitFeedback(1, [2, 2, 2, 2]);
        await mastermind.connect(nAddr).revealCode(1, [2, 1, 3, 4]);

        // Turn 3
        const secretCodeHash3 = ethers.keccak256(ethers.toUtf8Bytes("1243"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash3);
        await mastermind.connect(nAddr).submitGuess(1, [3, 2, 4, 1]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [3, 2, 4, 1]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [3, 2, 4, 1]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [3, 2, 4, 1]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [1, 2, 4, 3]);
        await mastermind.connect(addr).submitFeedback(1, [2, 2, 2, 2]);
        await mastermind.connect(addr).revealCode(1, [1, 2, 4, 3]);
        
        // Turn 4
        const secretCodeHash4 = ethers.keccak256(ethers.toUtf8Bytes("2143"));
        await mastermind.connect(nAddr).submitCode(1, secretCodeHash4);
        await mastermind.connect(addr).submitGuess(1, [3, 1, 4, 2]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [3, 1, 4, 2]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [3, 1, 4, 2]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [3, 1, 4, 2]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [2, 1, 4, 3]);
        await mastermind.connect(nAddr).submitFeedback(1, [2, 2, 2, 2]);
        await mastermind.connect(nAddr).revealCode(1, [2, 1, 4, 3]);

        // Turn 5
        const secretCodeHash5 = ethers.keccak256(ethers.toUtf8Bytes("3412"));
        await mastermind.connect(addr).submitCode(1, secretCodeHash5);
        await mastermind.connect(nAddr).submitGuess(1, [2, 4, 1, 3]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [2, 4, 1, 3]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [2, 4, 1, 3]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [2, 4, 1, 3]);
        await mastermind.connect(addr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(nAddr).submitGuess(1, [3, 4, 1, 2]);
        await mastermind.connect(addr).submitFeedback(1, [2, 2, 2, 2]);
        await mastermind.connect(addr).revealCode(1, [3, 4, 1, 2]);

        // Turn 5
        const secretCodeHash6 = ethers.keccak256(ethers.toUtf8Bytes("3412"));
        await mastermind.connect(nAddr).submitCode(1, secretCodeHash6);
        await mastermind.connect(addr).submitGuess(1, [2, 4, 1, 3]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [2, 4, 1, 3]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [2, 4, 1, 3]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [2, 4, 1, 3]);
        await mastermind.connect(nAddr).submitFeedback(1, [1, 2, 2, 1]);
        await mastermind.connect(addr).submitGuess(1, [3, 4, 1, 2]);
        await mastermind.connect(nAddr).submitFeedback(1, [2, 2, 2, 2]);
        await mastermind.connect(nAddr).revealCode(1, [3, 4, 1, 2]);

        await mastermind.connect(addr).finishGame(1);

        const game = await mastermind.games(1);
        expect(game.active).to.deep.equal(false);
    });
});