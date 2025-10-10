// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {Safe} from "@safe-utils/src/Safe.sol";
import {Addresses} from "@script/Addresses.s.sol";
import {BaseScript} from "@script/BaseScript.s.sol";
import {BaseVault} from "@src/utils/BaseVault.sol";
import {console} from "forge-std/console.sol";

contract ProposeSafeTxSetTotalAssetsCapScript is BaseScript, Addresses {
    using Safe for *;

    Safe.Client internal safe;

    uint256 TOTAL_ASSETS_CAP = 10_000e6;

    address signer;
    string derivationPath;

    function setUp() public override {
        super.setUp();
        signer = vm.envAddress("SIGNER");
        derivationPath = vm.envString("DERIVATION_PATH");
        safe.initialize(addresses[block.chainid][Contract.GovernanceMultisig]);
    }

    function run() public {
        address[] memory vaults =
            block.chainid == 1 ? getMainnetVaults() : block.chainid == 8453 ? getBaseVaults() : new address[](0);

        TimelockController timelockController =
            TimelockController(payable(addresses[block.chainid][Contract.TimelockController_VAULT_MANAGER_ROLE]));

        address[] memory multisigTargets = new address[](vaults.length);
        bytes[] memory multisigDatas = new bytes[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            address target = vaults[i];
            uint256 value = 0;
            bytes memory data = abi.encodeCall(BaseVault.setTotalAssetsCap, (TOTAL_ASSETS_CAP));
            bytes32 predecessor = bytes32(0);
            bytes32 salt = keccak256(abi.encode(target, value, data, predecessor));
            uint256 delay = timelockController.getMinDelay();
            multisigTargets[i] = address(timelockController);
            multisigDatas[i] =
                abi.encodeCall(timelockController.schedule, (target, value, data, predecessor, salt, delay));
        }

        safe.proposeTransactions(multisigTargets, multisigDatas, signer, derivationPath);
    }

    function getMainnetVaults() public view returns (address[] memory ans) {
        ans = new address[](1);
        ans[0] = addresses[1][Contract.CashStrategyVault];
        return ans;
    }

    function getBaseVaults() public view returns (address[] memory ans) {
        ans = new address[](1);
        ans[0] = addresses[8453][Contract.CashStrategyVault];
        return ans;
    }
}
