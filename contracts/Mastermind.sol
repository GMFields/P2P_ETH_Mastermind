// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

contract Mastermind {
    uint private constant MAX_GUESSES = 5;
    uint private constant MAX_TURNS = 10;
    uint8 private constant EXTRA_POINTS = 3;
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
        address whosPlaying;
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


    /**
     * This function is called when a game is created to decide the roles of the players
     * 
     * @param gameiD The game id
     */
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


    /**
     * This function is called after submiting the code to create a turn
     * 
     * @param game The game to create the turn for
     */
    function createTurn(Game storage game, bytes32 hashCode) internal { 
        require(game.turnCounter < MAX_TURNS, "Max turns reached");

        address maker = game.currentTurn.maker;
        address breaker = game.currentTurn.breaker;
        if(game.currentTurn.timestamp != 0) {
            // Keep from the old turn
            maker = game.currentTurn.breaker;
            breaker = game.currentTurn.maker;
        }
        
        // Create the first turn
        game.currentTurn = Turn({
            finished: false,
            guess: new uint8[][](0),
            feedback: new uint8[][](0),
            breaker: breaker,
            maker: maker,
            secretCodeHash: hashCode,
            revealedCode: new uint8[](0),
            timestamp: block.timestamp
        });

        game.turnCounter ++;
    }


    /**
     * This function is called to finalize a turn
     * 
     * @param game The game to finalize the turn for
     * @param turn The turn to finalize
     * @param revealedCode The code to reveal
     */
    function finalizeTurn(Game storage game, Turn storage turn, uint8[] calldata revealedCode) internal {
        bytes memory newHaschCodeString;
        for(uint i = 0; i < revealedCode.length; i++){
            newHaschCodeString =  abi.encodePacked(newHaschCodeString, Strings.toString(revealedCode[i]));
        }
        
        bytes32 newHashCode = keccak256(abi.encodePacked(string(newHaschCodeString)));
        require(newHashCode == turn.secretCodeHash, "Invalid code");
        
        uint8 extraPoints = 0;
        if(turn.guess.length == MAX_GUESSES) {
            extraPoints = EXTRA_POINTS;
        }

        if(turn.maker == game.createUser) {
            game.createUserPoints += uint8(turn.guess.length) + extraPoints;
        } else {
            game.joinUserPoints += uint8(turn.guess.length) + extraPoints;
        }

        turn.finished = true;   
    }


    /**
     * This function is called to create a game
     * 
     * @param friendlyMatch boolean to check if the game should be for friends
     * @param friendAddr address of the friend
     */
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
            address(0),
            true
        );
    
        emit GameStart(gameCounter, msg.sender);
        return gameCounter;
    }


    /**
     * This function is called to join a game, knowing its Id
     * 
     * @param gameId The game id
     */
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
        game.active = true;

        decideRoles(gameId);

        emit GameJoined(gameId, msg.sender, game.currentTurn.maker, game.currentTurn.breaker);
    }


    /** TODO
     * This function is called to join a game, without a specific Id
     * 
     */
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
        game.active = true;

        //decideRoles(gameId);
        
        emit GameJoined(0, msg.sender, game.currentTurn.maker, game.currentTurn.breaker);
    }


    /**
     * This function is called to submit the code
     * 
     * @param gameId The game id
     * @param hashCode The hash of the code
     */
    function submitCode(uint8 gameId, bytes32 hashCode) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];
        require(game.active, "Game not active anymore");
        require(game.createUser == msg.sender || game.joinUser == msg.sender, "Not a player");

        Turn storage turn = game.currentTurn;
        require(turn.maker == msg.sender, "Not your turn");
        if(turn.timestamp != 0){
            require(turn.finished, "Previous turn not finished yet");
            if (block.timestamp - game.currentTurn.timestamp <= DISPUTE_TIME) {
                revert("Not enough time has passed to start a new turn");
            }
        }
        // Check if the game enough time has passed to start new turn

        createTurn(game, hashCode);
    }


    /**
     * This function is called to submit a guess
     * 
     * @param gameId The game id
     * @param guess The guess
     */
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


    /**
     * This function is called to submit feedback
     * 
     * @param gameId the game id
     * @param feedback the feedback
     */
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

        if(finished) {
            turn.finished = true;
        }
        

        emit FeedbackSubmitted(gameId, msg.sender, feedback, turn.timestamp);
    }

    function accuseAFK() external {

    }

    
    function accuseCheating(uint8 gameId) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];

        Turn storage turn = game.currentTurn;

        require(turn.finished, "Turn not finished yet");
        require(block.timestamp - turn.timestamp <= DISPUTE_TIME, "The window to accuse of cheating has closed");
        
        // Logic for checking inconsistencies in feedback
        uint8[] storage revealedCode = turn.revealedCode;
        uint8[][] storage guesses = turn.guess;
        uint8[][] storage feedbacks = turn.feedback;

        // TODO - checks all consistency in feedbacks, but pdf says client should provide own guess to dispute
        for (uint i = 0; i < feedbacks.length; i++) {
            uint8[] storage guess = guesses[i];
            uint8[] storage feedback = feedbacks[i];
            uint8[10] memory colorCount;

            for (uint j = 0; j < revealedCode.length; j++) {
                colorCount[revealedCode[j]]++;
            }

            for (uint j = 0; j < guess.length; j++) {
                if (guess[j] == revealedCode[j]) {
                    if (feedback[j] != 2) {
                        game.active = false;
                        payable(msg.sender).transfer(game.stake);
                        return;
                    }
                    colorCount[guess[j]]--;
                } else if (guess[j] != revealedCode[j]) {
                    if (colorCount[guess[j]] > 0 && feedback[j] != 1) {
                        game.active = false;
                        payable(msg.sender).transfer(game.stake);
                        return;
                    } else if (colorCount[guess[j]] == 0 && feedback[j] != 0) {
                        game.active = false;
                        payable(msg.sender).transfer(game.stake);
                        return;
                    }
                    colorCount[guess[j]]--;
                }
            }
        }
    }


    /**
     * This function is called to reveal the code
     * 
     * @param gameId The game id
     * @param revealedCode The code to reveal
     */
    function revealCode(uint8 gameId, uint8[] calldata revealedCode) external {
        require(gameCounter > 0, "No games available");
        require(gameCounter >= gameId, "Invalid game id");

        Game storage game = games[gameId];
        require(game.active, "Game not active anymore");
        require(game.createUser == msg.sender || game.joinUser == msg.sender, "Not a player");

        Turn storage turn = game.currentTurn;
        require(turn.maker == msg.sender, "Not your turn");
        require(turn.finished || turn.guess.length == MAX_GUESSES || turn.feedback.length == MAX_GUESSES, "Turn not finished yet");
        require(turn.revealedCode.length == 0, "Code already revealed");

        turn.revealedCode = revealedCode;
        turn.timestamp = block.timestamp;

        // TODO Done- should check if hash of revealed code matches the hash of the secret code
        // TODO Done - should distribute the points for of the players
        finalizeTurn(game, turn, revealedCode);

        emit CodeRevealed(gameId, msg.sender, revealedCode);
    }


    function finishGame(uint8 gameId) external {
        Game storage game = games[gameId];
        require(game.turnCounter == MAX_TURNS, "Game not finished yet");

        Turn storage turn = game.currentTurn;
        require(turn.breaker == msg.sender, "Not your turn");

        if (game.createUserPoints > game.joinUserPoints) {
            payable(game.createUser).transfer(game.stake);
        } else if (game.createUserPoints < game.joinUserPoints) {
            payable(game.joinUser).transfer(game.stake);
        } else {
            payable(game.createUser).transfer(game.stake / 2);
            payable(game.joinUser).transfer(game.stake / 2);
        }
    }
}
