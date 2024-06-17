// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Mastermind {
    uint private constant MAX_GUESSES = 5;
    uint private constant MAX_TURNS = 10;
    uint private constant TIME_LIMIT = 600; // Example time limit for AFK
    uint private constant DISPUTE_TIME = 600; // Example time limit for dispute

    mapping(uint => Game) public games;
    uint8 private gameCounter = 0;

    struct Game {
        address createUser;
        address joinUser;
        uint8 createUserPoints;
        uint8 joinUserPoints;
        bool friendlyMatch;
        address friendAddr;
        Turn[] turns;
        uint256 stake;
        bool active;
    }

    struct Turn {
        uint8[] guess;
        uint8[] feedback;
        address breaker;
        address maker;
        bytes32 secretCodeHash;
        uint8[] revealedCode;
        uint256 timestamp;
    }

    event GameStart(uint8 gameId, address creator);
    event GameJoined(uint8 gameId, address joiner);
    event GameFinish();
    event ChangeTurn();
    event GuessSubmitted();
    event CodeRevealed();

    function createGame(bool friendlyMatch, address friendAddr) external payable returns (uint8){
        require(msg.value > 0, "Stake required");



        gameCounter++;
        Game storage newGame = games[gameCounter];
        newGame.createUser = msg.sender;
        newGame.joinUser = address(0);
        newGame.createUserPoints = 0;
        newGame.joinUserPoints = 0;
        newGame.friendlyMatch = friendlyMatch;
        newGame.friendAddr = friendAddr == address(0) ? address(0) : friendAddr;
        newGame.stake = msg.value;
        newGame.active = true;
        newGame.turns.push(createTurn(newGame));
    
        emit GameStart(gameCounter, msg.sender);
        return gameCounter;
    }

    function joinGame(uint8 gameId) external payable {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];
        require(game.active, "Game not active anymore");
        require(game.joinUser == address(0), "Game already joined");
        require(game.createUser != msg.sender, "Cannot join your own game");
        require(game.friendlyMatch && game.friendAddr == msg.sender, "You don't have permission to join this game");
        require(msg.value == game.stake, "Stake must match");

        game.joinUser = msg.sender;
        game.stake += msg.value;

        emit GameJoined(gameId, msg.sender);
    }

    /*
    function joinGame() external payable returns (uint) {
        require(gameCounter > 0, "No games available");

        //TODO: Implement joinGame without gameId
    }
    */

    function createTurn(Game storage game) internal view returns (Turn memory) { 
        require(game.turns.length < MAX_TURNS, "Max turns reached");
    
        // Randomly choose the maker and breaker
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 2);
        address maker = game.createUser;
        address breaker = game.joinUser;
        if (random == 0) {
            maker = game.joinUser;
            breaker = game.createUser;
        }
    
        // Create the first turn
        Turn memory turn = Turn(
            new uint8[](0),
            new uint8[](0),
            breaker,
            maker,
            bytes32(0),
            new uint8[](0),
            block.timestamp
        );
    
        return turn;
    }

    function submitCode(uint8 gameId, bytes32 hashCode) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];
        require(game.active, "Game not active anymore");
        require(game.createUser == msg.sender || game.joinUser == msg.sender, "Not a player");

        Turn storage turn = game.turns[game.turns.length - 1];
        require(turn.maker == msg.sender, "Not your turn");
        require(turn.guess.length == 0, "Game already started");

        turn.secretCodeHash = hashCode;
        turn.timestamp = block.timestamp;

        emit ChangeTurn();
    }

    /*
    function submitGuess(uint8 gameId, uint8[] calldata guess) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];
        require(game.active, "Game not active anymore");
        require(game.createUser == msg.sender || game.joinUser == msg.sender, "Not a player");
        require(game.turns.length < MAX_TURNS, "Max turns reached");
        require(game.turns[game.turns.length - 1].breaker == msg.sender, "Not your turn");
        
        Turn memory turn = game.turns[game.turns.length - 1];
        require(turn.guess.length <= MAX_GUESSES, "Max guesses reached");
        require(turn.guess.length == turn.feedback.length, "Feedback not submitted yet");

        turn.guess = guess;
        turn.timestamp = block.timestamp;

        emit GuessSubmitted();
    }
    */

    function submitFeedback() external {

    }

    function accuseAFK() external {

    }

    function accuseCheating() external {

    }

    function revealCode() external {

    }
}
