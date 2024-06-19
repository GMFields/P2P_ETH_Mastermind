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
        Turn currentTurn;
        uint256 turnCounter;
        uint256 stake;
        bool active;
    }

    struct Turn {
        bool finished;
        uint8[][] guess;
        uint8[][] feedback;
        address breaker;
        address maker;
        bytes32 secretCodeHash;
        uint8[] revealedCode;
        uint256 timestamp; // to dispute
    }

    event GameStart(uint8 gameId, address creator);
    event GameJoined(uint8 gameId, address joiner, address maker, address breaker);
    event GameFinish();
    event ChangeTurn();
    event GuessSubmitted(uint8 gameId, address player, uint8[] guess, uint256 timestamp);
    event FeedbackSubmitted(uint8 gameId, address player, uint8[] feedback, uint256 timestamp);
    event CodeRevealed(uint8 gameId, address player, uint8[] code);

    function decideRoles(uint8 gameiD) internal {
        Game storage game = games[gameiD];

        address maker = game.createUser;
        address breaker = game.joinUser;

        // Randomly choose the maker and breaker
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 2);
        if (random == 0) {
            maker = game.joinUser;
            breaker = game.createUser;
        }

        game.currentTurn.maker = maker;
        game.currentTurn.breaker = breaker;
    }

    function createTurn(Game storage game) internal returns (Turn memory) { 
        require(game.turnCounter < MAX_TURNS, "Max turns reached");

        address maker = game.currentTurn.maker;
        address breaker = game.currentTurn.breaker;
        if(game.currentTurn.timestamp != 0) {
            // Keep from the old turn
            maker = game.currentTurn.breaker;
            breaker = game.currentTurn.maker;
        }
        
        // Create the first turn
        Turn memory turn = Turn(
            false,
            new uint8[][](0),
            new uint8[][](0),
            breaker,
            maker,
            bytes32(0),
            new uint8[](0),
            block.timestamp
        );

        game.turnCounter ++;
    
        return turn;
    }

    function createGame(bool friendlyMatch, address friendAddr) external payable returns (uint8){
        require(msg.value > 0, "Stake required");

        gameCounter++;
        
        games[gameCounter] = Game(
            msg.sender,
            address(0),
            0,
            0,
            friendlyMatch,
            friendAddr == address(0) ? address(0) : friendAddr,
            Turn(
                false,
                new uint8[][](0),
                new uint8[][](0),
                address(0),
                address(0),
                bytes32(0),
                new uint8[](0),
                0
            ),
            0,
            msg.value,
            true
        );
    
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
        if (game.friendlyMatch)
           require(game.friendAddr == msg.sender, "You don't have permission to join this game");
        
        require(msg.value == game.stake, "Stake must match");

        game.joinUser = msg.sender;
        game.stake += msg.value;

        emit GameJoined(gameId, msg.sender, game.currentTurn.maker, game.currentTurn.breaker);
    }

    function joinGame() external payable {
        require(gameCounter > 0, "No games available");

        uint256 counter;
        uint256[] memory available = new uint256[](gameCounter);
        for (uint i = 0; i < gameCounter; i++) {
            if (!games[i].active)
                available[counter++] = i;
        }
        Game storage game = games[available[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % counter]];

        //require(game.active, "Game not active anymore");
        require(game.joinUser == address(0), "Game already joined");
        require(game.createUser != msg.sender, "Cannot join your own game");
        if (game.friendlyMatch) 
           require(game.friendAddr == msg.sender, "You don't have permission to join this game");
        
        require(msg.value == game.stake, "Stake must match");

        game.joinUser = msg.sender;
        game.stake += msg.value;
        
        //emit GameJoined(0, msg.sender, game.currentTurn.maker, game.currentTurn.breaker);
    }

    function submitCode(uint8 gameId, bytes32 hashCode) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];
        require(game.active, "Game not active anymore");
        require(game.createUser == msg.sender || game.joinUser == msg.sender, "Not a player");

        Turn storage turn = game.currentTurn;
        require(turn.maker == msg.sender, "Not your turn");
        require(turn.guess.length == 0, "Game already started");

        turn.secretCodeHash = hashCode;
        turn.timestamp = block.timestamp;
        game.currentTurn = createTurn(game);
    }

    function submitGuess(uint8 gameId, uint8[] calldata guess) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];
        require(game.active, "Game not active anymore");
        require(game.createUser == msg.sender || game.joinUser == msg.sender, "Not a player");
        require(game.turnCounter < MAX_TURNS, "Max turns reached");
        
        Turn storage turn = game.currentTurn;
        require(turn.maker == msg.sender, "Not your turn");
        require(turn.guess.length <= MAX_GUESSES, "Max guesses reached");
        require(turn.guess.length == turn.feedback.length, "Feedback not submitted yet");

        turn.guess.push(guess);
        turn.timestamp = block.timestamp;

        emit GuessSubmitted(gameId, msg.sender, guess, turn.timestamp);
    }

    function submitFeedback(uint8 gameId, uint8[] calldata feedback) external {
        // requires
        // check all dependencies
        // TODO

        Game storage game = games[gameId];

        Turn storage turn = game.currentTurn;

        turn.feedback.push(feedback);
        turn.timestamp = block.timestamp;

        bool finished = true;
        for (uint i = 0; i < feedback.length; i++) {
            if (feedback[i] != 2) {
                finished = false;
                break;
            }
        }
        

        emit FeedbackSubmitted(gameId, msg.sender, feedback, turn.timestamp);
    }

    function accuseAFK() external {

    }

    /*
    function accuseCheating(uint8 gameId) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];

    }
    */

    function revealCode(uint8 gameId, uint8[] calldata revealedCode) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];
        require(game.active, "Game not active anymore");
        require(game.createUser == msg.sender || game.joinUser == msg.sender, "Not a player");

        Turn storage turn = game.currentTurn;
        require(turn.maker == msg.sender, "Not your turn");
        require(turn.guess.length == MAX_GUESSES, "Guesses not completed yet");
        require(turn.feedback.length == MAX_GUESSES, "Feedback not completed yet");
        require(turn.revealedCode.length == 0, "Code already revealed");

        turn.revealedCode = revealedCode;
        

        // call to change turn - TODO

        emit CodeRevealed(gameId, msg.sender, revealedCode);
    }
}
