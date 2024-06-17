// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Mastermind is Ownable {
    uint public constant MAX_GUESSES = 10;
    uint public constant TIME_LIMIT = 600; // Example time limit for AFK

    struct Game {
        address codeMaker;
        address codeBreaker;
        bytes32 secretCodeHash;
        uint8[] secretCode;
        uint8 maxGuesses;
        uint8 numGuesses;
        uint256 stake;
        uint256 lastAction;
        bool active;
    }

    mapping(uint => Game) public games;
    uint public gameCounter;

    event GameCreated(uint gameId, address creator);
    event GameJoined(uint gameId, address joiner);
    event GuessSubmitted(uint gameId, address guesser, uint8[] guess);
    event CodeRevealed(uint gameId, address revealer, uint8[] code);
    event GameEnded(uint gameId, address winner);

    modifier onlyPlayer(uint gameId) {
        require(msg.sender == games[gameId].codeMaker || msg.sender == games[gameId].codeBreaker, "Not a player");
        _;
    }

    constructor() Ownable() {}

    function createGame(bytes32 secretCodeHash) external payable returns (uint) {
        require(msg.value > 0, "Stake required");

        gameCounter++;
        games[gameCounter] = Game({
            codeMaker: msg.sender,
            codeBreaker: address(0),
            secretCodeHash: secretCodeHash,
            secretCode: new uint8[](0), // Correctly initialize an empty dynamic array
            maxGuesses: MAX_GUESSES,
            numGuesses: 0,
            stake: msg.value,
            lastAction: block.timestamp,
            active: true
        });

        emit GameCreated(gameCounter, msg.sender);
        return gameCounter;
    }

    function joinGame(uint gameId) external payable {
        Game storage game = games[gameId];
        require(game.codeBreaker == address(0), "Game already joined");
        require(msg.value == game.stake, "Stake must match");

        game.codeBreaker = msg.sender;
        game.stake += msg.value;

        emit GameJoined(gameId, msg.sender);
    }

    function submitGuess(uint gameId, uint8[] calldata guess) external onlyPlayer(gameId) {
        Game storage game = games[gameId];
        require(game.active, "Game not active");
        require(msg.sender == game.codeBreaker, "Not the codebreaker");
        require(game.numGuesses < game.maxGuesses, "Max guesses reached");

        game.numGuesses++;
        game.lastAction = block.timestamp;

        // Compute feedback (CC and NC)
        (uint8 CC, uint8 NC) = _computeFeedback(game.secretCode, guess);

        emit GuessSubmitted(gameId, msg.sender, guess);

        if (CC == uint8(game.secretCode.length)) {
            game.active = false;
            payable(game.codeBreaker).transfer(game.stake);
            emit GameEnded(gameId, game.codeBreaker);
        }
    }

    function revealCode(uint gameId, uint8[] calldata code) external onlyPlayer(gameId) {
        Game storage game = games[gameId];
        require(game.active, "Game not active");
        require(msg.sender == game.codeMaker, "Not the codemaker");
        require(keccak256(abi.encodePacked(code)) == game.secretCodeHash, "Invalid code");

        game.secretCode = code;
        game.active = false;

        if (game.numGuesses >= game.maxGuesses) {
            payable(game.codeMaker).transfer(game.stake);
            emit GameEnded(gameId, game.codeMaker);
        }

        emit CodeRevealed(gameId, msg.sender, code);
    }

    function accuseAFK(uint gameId) external onlyPlayer(gameId) {
        Game storage game = games[gameId];
        require(block.timestamp > game.lastAction + TIME_LIMIT, "Too soon to accuse");

        address winner = (msg.sender == game.codeMaker) ? game.codeMaker : game.codeBreaker;
        game.active = false;
        payable(winner).transfer(game.stake);

        emit GameEnded(gameId, winner);
    }

    function _computeFeedback(uint8[] memory secret, uint8[] memory guess) internal pure returns (uint8, uint8) {
        uint8 CC = 0;
        uint8 NC = 0;
        bool[] memory secretMatched = new bool[](secret.length);
        bool[] memory guessMatched = new bool[](guess.length);

        // Calculate CC
        for (uint8 i = 0; i < secret.length; i++) {
            if (secret[i] == guess[i]) {
                CC++;
                secretMatched[i] = true;
                guessMatched[i] = true;
            }
        }

        // Calculate NC
        for (uint8 i = 0; i < secret.length; i++) {
            if (!secretMatched[i]) {
                for (uint8 j = 0; j < guess.length; j++) {
                    if (!guessMatched[j] && secret[i] == guess[j]) {
                        NC++;
                        guessMatched[j] = true;
                        break;
                    }
                }
            }
        }

        return (CC, NC);
    }
}
