// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

contract Mastermind {
    uint private constant MAX_GUESSES = 5;
    uint private constant MAX_TURNS = 6;
    uint private constant AFK_TIME_LIMIT = 1; // Example time limit for AFK in seconds
    uint private constant DISPUTE_TIME = 2; // Example time limit for dispute in seconds

    uint8 private constant EXTRA_POINTS = 3;
    uint private constant CODE_LENGTH = 4;
    uint private constant NUM_COLORS = 10;

    // TODO - should have a limit of colors
    // TODO - maybe check after code is revealed if maker used appropriate colors

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
        address afkAccuser;
        uint256 afkTimestamp;
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

    // ########## Events ##########
    event GameStart(uint8 gameId, address creator);
    event GameJoined(uint8 gameId, address joiner, address maker, address breaker);
    event GameFinish();
    event ChangeTurn();
    event GuessSubmitted(uint8 gameId, address player, uint8[] guess, uint256 timestamp);
    event FeedbackSubmitted(uint8 gameId, address player, uint8[] feedback, uint256 timestamp);
    event CodeRevealed(uint8 gameId, address player, uint8[] code);
    event CodeSubmitted(uint8 gameId, address player, bytes32 code);
    event CheatAccusation(uint8 gameId, uint8 guessNmr, address accuser, bool cheating);
    event AfkAccusation(uint8 gameId, address accuser, uint256 blockNumber);
    event AfkResponse(uint8 gameId, address responder);
    // ------------------------------------

    // ########## Modifiers ##########
    modifier validGame(uint8 gameId) {
        require(gameCounter >= gameId, "Invalid game id");
        _;
    }

    modifier rightStake() {
        require(msg.value > 0, "Stake required");
        _;
    }

    modifier rightLenght( uint256 length) {
        require(length == CODE_LENGTH, "Length invalid");
        _;
    }

    modifier validGuessNmr(uint8 guessNmr) {
        require(guessNmr < MAX_GUESSES, "Invalid guess number");
        _;
    }

    modifier isGameActive(Game storage game) {
        require(game.active, "Game not active anymore");
        _;
    }

    modifier isMakerTurn(Turn storage turn) {
        require(msg.sender == turn.maker, "Either not you turn, or not a player");
        _;
    }

    modifier isBreakerTurn(Turn storage turn) {
        require(msg.sender == turn.breaker, "Either not you turn, or not a player");
        _;
    }

    modifier isYourPlay(Game storage game) {
        require(msg.sender == game.whosPlaying, "Not your play");
        _;
    }
    // ------------------------------------
        
    /**
     * This function is called when a game is created to decide the roles of the players
     * 
     * @param game The game itself
     */
    function decideRoles(Game storage game) internal {
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

        game.whosPlaying = maker;
    }


    /**
     * This function is called after submiting the code to create a turn
     * 
     * @param game The game to create the turn for
     */
    function createTurn(Game storage game, Turn storage turn, bytes32 hashCode) internal { 
        address maker = turn.maker;
        address breaker = turn.breaker;
        
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


    function defendAfk(Game storage game) internal {
        if(block.timestamp - game.afkTimestamp > AFK_TIME_LIMIT) {
            game.active = false;
            payable(game.afkAccuser).transfer(game.stake);
            return;
        }

        game.afkTimestamp = 0;
        game.afkAccuser = address(0);
        emit AfkResponse(gameCounter, msg.sender);
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

        address maker = game.currentTurn.maker;
        address breaker = game.currentTurn.breaker;
        if(game.turnCounter != MAX_TURNS){
            game.currentTurn.maker = breaker;
            game.currentTurn.breaker = maker;
            game.whosPlaying = breaker;
            emit ChangeTurn();
        } else {
            game.whosPlaying = turn.breaker;
        }

        turn.finished = true;   
    }


    /**
     * This function is called to create a game
     * 
     * @param friendlyMatch boolean to check if the game should be for friends
     * @param friendAddr address of the friend
     */
    function createGame(bool friendlyMatch, address friendAddr) external payable rightStake() returns (uint8){
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
            address(0),
            0,
            false
        );
    
        emit GameStart(gameCounter, msg.sender);
        return gameCounter;
    }


    /**
     * This function is called to join a game, knowing its Id
     * 
     * @param gameId The game id
     */
    function joinGame(uint8 gameId) external payable validGame(gameId) {

        Game storage game = games[gameId];
        require(msg.value == game.stake, "Stake must match");
        require(!game.active, "This game is already active");
        require(game.createUser != msg.sender, "Cannot join your own game");
        if (game.friendlyMatch)
           require(msg.sender == game.friendAddr, "You don't have permission to join this game");
        

        game.joinUser = msg.sender;
        game.stake += msg.value;
        game.active = true;

        decideRoles(game);

        emit GameJoined(gameId, msg.sender, game.currentTurn.maker, game.currentTurn.breaker);
    }


    /** TODO - Think its done, check later again
     *  TODO - requires to be done
     * This function is called to join a game, without a specific Id
     * 
     */
    function joinGame() external payable {

        uint256 counter;
        uint8[] memory available = new uint8[](gameCounter);
        for (uint8 i = 1; i <= gameCounter; i++) {
            if (!games[i].active && games[i].createUser != msg.sender && games[i].stake == msg.value)
                if(games[i].friendlyMatch && games[i].friendAddr == msg.sender)
                    available[counter++] = i;
                else if(!games[i].friendlyMatch)
                    available[counter++] = i;
        }

        if(counter == 0)
            revert("No games available");

        uint8 gameId = available[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % counter];
        Game storage game = games[gameId];


        game.joinUser = msg.sender;
        game.stake += msg.value;
        game.active = true;

        decideRoles(game);
        
        emit GameJoined(gameId, msg.sender, game.currentTurn.maker, game.currentTurn.breaker);
    }


    /**
     * This function is called to submit the code
     * 
     * @param gameId The game id
     * @param hashCode The hash of the code
     */
    function submitCode(uint8 gameId, bytes32 hashCode) external 
        validGame(gameId) isGameActive(games[gameId]) isMakerTurn(games[gameId].currentTurn) isYourPlay(games[gameId]){

        Game storage game = games[gameId];

        Turn storage turn = game.currentTurn;

        // Checks if it's not first turn
        if(turn.timestamp != 0){
            require(turn.finished, "Previous turn not finished yet");
        }

        if(game.turnCounter == MAX_TURNS) {
            game.active = false;
            emit GameFinish();
            revert("Max turns reached");
        }

        if(msg.sender != game.afkAccuser && game.afkAccuser != address(0)) {
            defendAfk(game);
        }


        createTurn(game, turn, hashCode);
        game.whosPlaying = turn.breaker;

        emit CodeSubmitted(gameId, msg.sender, hashCode);
    }


    /**
     * This function is called to submit a guess
     * 
     * @param gameId The game id
     * @param guess The guess
     */
    function submitGuess(uint8 gameId, uint8[] calldata guess) external 
        validGame(gameId) rightLenght(guess.length) isGameActive(games[gameId])
        isBreakerTurn(games[gameId].currentTurn) isYourPlay(games[gameId]){
        Game storage game = games[gameId];
        
        Turn storage turn = game.currentTurn;
        require(!turn.finished, "Turn already finished");

        if(turn.guess.length >= MAX_GUESSES){
            turn.finished = true;
            revert("Max guesses reached");
        }

        if(msg.sender != game.afkAccuser && game.afkAccuser != address(0)) {
            defendAfk(game);
        }

        turn.guess.push(guess);
        turn.timestamp = block.timestamp;

        game.whosPlaying = turn.maker;
        emit GuessSubmitted(gameId, msg.sender, guess, turn.timestamp);
    }


    /**
     * This function is called to submit feedback
     * 
     * @param gameId the game id
     * @param feedback the feedback
     */
    function submitFeedback(uint8 gameId, uint8[] calldata feedback) external 
    validGame(gameId) rightLenght(feedback.length) isGameActive(games[gameId]) isMakerTurn(games[gameId].currentTurn) isYourPlay(games[gameId]){
        Game storage game = games[gameId];

        Turn storage turn = game.currentTurn;
        require(!turn.finished, "Turn already finished");

        if(msg.sender != game.afkAccuser && game.afkAccuser != address(0)) {
            defendAfk(game);
        }

        turn.feedback.push(feedback);
        turn.timestamp = block.timestamp;

        bool finished = true;
        for (uint i = 0; i < feedback.length; i++) {
            if (feedback[i] != 2) {
                finished = false;
                break;
            }
        }

        if(finished || turn.feedback.length == MAX_GUESSES) {
            turn.finished = true;
            game.whosPlaying = turn.maker;
        } else {
            game.whosPlaying = turn.breaker;
        }

        emit FeedbackSubmitted(gameId, msg.sender, feedback, turn.timestamp);
    }


    function accuseAfk(uint8 gameId) external isGameActive(games[gameId]){
        Game storage game = games[gameId];
        // TODO - check requires;
        require(msg.sender == game.createUser || msg.sender == game.joinUser, "Only players can accuse");
        require(game.whosPlaying != msg.sender, "Cannot accuse when it's your turn");
        require(game.afkTimestamp == 0, "AFK accusation already in progress");

        game.afkAccuser = msg.sender;
        game.afkTimestamp = block.timestamp;

        emit AfkAccusation(gameId, msg.sender, block.timestamp);
    }

    function verifyAfk(uint8 gameId) external {
        Game storage game = games[gameId];
        // TODO - check requires

        require(msg.sender == game.afkAccuser, "Only accuser can verify");
        require(block.timestamp - game.afkTimestamp > AFK_TIME_LIMIT, "The window to accuse AFK is not yet oppened");

        game.active = false;
        payable(game.afkAccuser).transfer(game.stake);
    }

    
    function accuseCheating(uint8 gameId, uint8 guessNmr) external 
        validGame(gameId) validGuessNmr(guessNmr) isGameActive(games[gameId]) isMakerTurn(games[gameId].currentTurn) isYourPlay(games[gameId]){
        Game storage game = games[gameId];

        Turn storage turn = game.currentTurn;
        require(turn.finished, "Turn not finished yet");
        require(block.timestamp - turn.timestamp <= DISPUTE_TIME, "The window to accuse of cheating has closed");
        
        // Logic for checking inconsistencies in feedback
        uint8[] storage revealedCode = turn.revealedCode;
        uint8[] storage guess = turn.guess[guessNmr];
        uint8[] storage feedback = turn.feedback[guessNmr];

        uint8[NUM_COLORS] memory colorCount;

        for (uint i = 0; i < revealedCode.length; i++) {
            colorCount[revealedCode[i]]++;
        }

        bool cheating = false;
        for (uint i = 0; i < guess.length; i++) {
            if (guess[i] == revealedCode[i]) {
                if (feedback[i] != 2) {
                    cheating = true;
                }
                colorCount[guess[i]]--;
            } else if (guess[i] != revealedCode[i]) {
                if (colorCount[guess[i]] > 0 && feedback[i] != 1) {
                    cheating = true;
                } else if (colorCount[guess[i]] == 0 && feedback[i] != 0) {
                    cheating = true;
                }
                colorCount[guess[i]]--;
            }
        }

        if (cheating) {      
            payable(msg.sender).transfer(game.stake);
        } else {
            payable(turn.maker).transfer(game.stake);
        }
        game.active = false;

        emit CheatAccusation(gameId, guessNmr, msg.sender, cheating);
        emit GameFinish();
    }


    /**
     * This function is called to reveal the code
     * 
     * @param gameId The game id
     * @param revealedCode The code to reveal
     */
    function revealCode(uint8 gameId, uint8[] calldata revealedCode) external 
        validGame(gameId) rightLenght(revealedCode.length) isGameActive(games[gameId]) isMakerTurn(games[gameId].currentTurn) isYourPlay(games[gameId]){
        Game storage game = games[gameId];

        Turn storage turn = game.currentTurn;
        require(turn.finished || turn.feedback.length == MAX_GUESSES, "Turn already finished");

        if(game.turnCounter == MAX_TURNS) {
            game.active = false;
            emit GameFinish();
        }

        if(msg.sender != game.afkAccuser && game.afkAccuser != address(0)) {
            defendAfk(game);
        }

        turn.revealedCode = revealedCode;
        turn.timestamp = block.timestamp;

        finalizeTurn(game, turn, revealedCode);

        emit CodeRevealed(gameId, msg.sender, revealedCode);
    }


    function finishGame(uint8 gameId) external 
        validGame(gameId) isBreakerTurn(games[gameId].currentTurn) isYourPlay(games[gameId]){
        Game storage game = games[gameId];
        require(game.turnCounter == MAX_TURNS, "Game not finished yet");

        if(msg.sender != game.afkAccuser && game.afkAccuser != address(0)) {
            defendAfk(game);
        }

        if (game.createUserPoints > game.joinUserPoints) {
            payable(game.createUser).transfer(game.stake);
        } else if (game.createUserPoints < game.joinUserPoints) {
            payable(game.joinUser).transfer(game.stake);
        } else {
            payable(game.createUser).transfer(game.stake / 2);
            payable(game.joinUser).transfer(game.stake / 2);
        }

        emit GameFinish();
    }
}
