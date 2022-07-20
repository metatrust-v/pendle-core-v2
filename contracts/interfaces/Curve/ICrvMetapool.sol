// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface ICrvMetapool {
    function add_liquidity(
        uint256 _deposit_amount,
        uint256 _min_amount,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity(
        uint256 _burn_amount,
        uint256[2] memory _min_amounts,
        address _receiver
    ) external returns (uint256[2] memory);

    function calc_token_amount(uint256[2] memory _amounts, bool _is_deposit)
        external
        view
        returns (uint256);

    function calc_withdraw_one_coin(uint256 _burn_amount, uint256 i)
        external
        view
        returns (uint256);
}
