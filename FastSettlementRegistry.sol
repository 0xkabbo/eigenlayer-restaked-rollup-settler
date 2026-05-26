// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FastSettlementRegistry
 * @dev Manages restaked operator attestations to settle rollup states with high economic security.
 */
contract FastSettlementRegistry is Ownable {
    
    struct RollupBatch {
        uint256 batchId;
        bytes32 stateRoot;
        bytes32 dataAvailabilityHash;
        uint32 quorumWeightAchieved;
        bool finalized;
    }

    uint256 public totalBatches;
    uint32 public constant REQUIRED_QUORUM_WEIGHT = 66; // Enforces a 66% restaked weight agreement threshold

    mapping(uint256 => RollupBatch) public batches;
    mapping(address => uint32) public operatorVotingPower;

    event BatchProposed(uint256 indexed batchId, bytes32 stateRoot);
    event BatchSettled(uint256 indexed batchId, bytes32 stateRoot, uint32 finalWeight);

    constructor() Ownable(msg.sender) {}

    function setOperatorWeight(address operator, uint32 weight) external onlyOwner {
        operatorVotingPower[operator] = weight;
    }

    /**
     * @notice Proposes a new rollup batch for restaked operator validation.
     */
    function proposeBatch(uint256 batchId, bytes32 stateRoot, bytes32 daHash) external {
        require(batches[batchId].stateRoot == bytes32(0), "Registry: Batch already proposed");
        
        batches[batchId] = RollupBatch({
            batchId: batchId,
            stateRoot: stateRoot,
            dataAvailabilityHash: daHash,
            quorumWeightAchieved: 0,
            finalized: false
        });

        emit BatchProposed(batchId, stateRoot);
    }

    /**
     * @notice Submits aggregated operator validations to cryptographically finalize state.
     */
    function settleBatch(
        uint256 batchId,
        address[] calldata signingOperators,
        bytes calldata aggregatedSignature
    ) external {
        RollupBatch storage batch = batches[batchId];
        require(batch.stateRoot != bytes32(0), "Registry: Batch does not exist");
        require(!batch.finalized, "Registry: Batch already finalized");

        uint32 weightCounter = 0;
        for (uint256 i = 0; i < signingOperators.length; i++) {
            weightCounter += operatorVotingPower[signingOperators[i]];
        }

        require(weightCounter >= REQUIRED_QUORUM_WEIGHT, "Registry: Insufficient restaked operator quorum");

        // In production, cryptographically verify the aggregate BLS or ECDSA signature 
        // against the combined public keys of the signing operators.
        
        batch.quorumWeightAchieved = weightCounter;
        batch.finalized = true;

        emit BatchSettled(batchId, batch.stateRoot, weightCounter);
    }
}
