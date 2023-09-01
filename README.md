# Provenably Random Raffle Contracts

## About

This code is to create a proveably random smart contract lottery.

## What we want it to do?

1. Users can enter by paying for a ticket
    1. The ticket fees are going to go to the winner during the draw
2. After X period of time, the lottery will automatically draw a winner
    1. And this will be done programatically
3. Using Chainlink VRF & Chainlink Automation 
    1. Chainlink VRF -> Randomness 
    2. Chainlink Automation -> Time based trigger 

## Tests
1. Write some deploy scripts
2. Write some tests
    1. unit test
    2. integration test: testing deply scripts and various components of our smart contract
    3. forked test: pseudo staging integration tests 
    4. staging test: run test on a testnet/mainnet (could be Ethereum compatible but cheaper gas L2)

## Credits to [Cyfrin foundry full course](https://github.com/Cyfrin/foundry-full-course-f23#lesson-9-foundry-smart-contract-lottery)
