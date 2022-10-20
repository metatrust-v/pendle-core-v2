// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IBulkSeller {
    function swapExactTokenForSy(address receiver, uint256 netTokenIn)
        external
        returns (uint256 netSyOut);

    function swapExactSyForToken(address receiver, uint256 exactSyIn)
        external
        returns (uint256 netTokenOut);

    function SY() external view returns (address);

    function token() external view returns (address);
}
