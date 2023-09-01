// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public immutable i_player = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();

        // assert(address(raffle).balance == 0);

        vm.deal(i_player, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // enterRaffle
    function testRaffleRevertWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(i_player);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector); // function selector
        raffle.enterRaffle();
    }

    function testRaffleRecordPlayerWhenTheyEnter() public {
        vm.prank(i_player);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == i_player);
    }

    // test emit event
    function testEmitsEventOnEntrance() public {
        vm.prank(i_player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(i_player);
        raffle.enterRaffle{value: entranceFee}();
    }

    // test with vm.warp and vm.roll
    // vm.warp: fast forward time
    // vm.roll: fast forward block
    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(i_player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(i_player);
        raffle.enterRaffle{value: entranceFee}();
    }

    // check upKeep
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNeotOpen() public {
        // Arrange
        vm.prank(i_player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // make raffle state not open -> be in calculating state
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    // testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.prank(i_player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    // testCheckUpkeepReturnsTrueWhenParametersAreMet
    function testCheckUpkeepReturnsTrueWhenParametersAreMet() public {
        // Arrange
        vm.prank(i_player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == true);
    }

    // test performUpkeep
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(i_player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        raffle.performUpkeep("");
        // Assert
        assert(
            raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER
        );
    }

    // TODO: initial balance is not ZERO when raffle deployed on Sepolia
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange: 
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint raffleStare = 0;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleStare
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(i_player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // what if we need to test using the output of an event?
    // cheatcode: recordLogs:
    // Tells the VM to start recording all the emitted events.
    // To access them, use getRecordedLogs.
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Act
        // how to get requestId from event:
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = raffle.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1); // calculating winner
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // test fulfillRandomness
    // use fuzz testing: put a varibale as a parameter for the function and then foundry will generate random values for it
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Arrange
        uint256 addtionalEntrants = 5;
        uint256 staringIndex = 1;
        for (
            uint256 i = staringIndex;
            i < staringIndex + addtionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            // hoax = vm.prank + vm.deal
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        // Act

        uint256 prize = entranceFee * (addtionalEntrants + 1);

        // how to get requestId from event:
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // pretent to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        // assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(raffle.getLastTimeStamp() > previousTimeStamp);
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE - entranceFee + prize
        );
    }
}
