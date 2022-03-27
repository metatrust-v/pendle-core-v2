const prefix = 'VM Exception while processing transaction: reverted with reason string';
export const errMsg = {
  INVALID_BASE_TOKEN: prefix + ' ' + "'invalid base token'",
  INSUFFICIENT_OUT: prefix + ' ' + "'insufficient out'",
  ERC20_BURN_EXCEEDS_BALANCE: prefix + ' ' + "'ERC20: burn amount exceeds balance'",
  ERC20_TRANSFER_EXCEEDS_BALANCE: prefix + ' ' + "'ERC20: transfer amount exceeds balance'",
  SAFE_ERC20_FAILED: prefix + ' ' + "'SafeERC20: ERC20 operation did not succeed'",
};
