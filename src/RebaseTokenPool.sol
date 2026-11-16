// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/contracts/pools/TokenPool.sol";
import {Pool} from "@ccip/contracts/libraries/Pool.sol";
import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
import {FinalityCodec} from "@ccip/contracts/libraries/FinalityCodec.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address _advancedPoolHooks, address _rnmProxy, address _router)
        TokenPool(_token, 18, _advancedPoolHooks, _rnmProxy, _router)
    {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        public
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn, FinalityCodec.WAIT_FOR_FINALITY_FLAG, "", 0);
        address originalSender = lockOrBurnIn.originalSender;
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        public
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(
            releaseOrMintIn, releaseOrMintIn.sourceDenominatedAmount, FinalityCodec.WAIT_FOR_FINALITY_FLAG
        );
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseToken(address(i_token))
            .mint(releaseOrMintIn.receiver, releaseOrMintIn.sourceDenominatedAmount, userInterestRate);

        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.sourceDenominatedAmount});
    }
}
