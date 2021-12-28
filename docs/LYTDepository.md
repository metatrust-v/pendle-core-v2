#  LYT Depository
[Back](PendleV2.md)

### Overview
* This is like a bank, where any "protocol" (each identified by an address) could use to store their LYTs
  * Each "protocol" could have multiple users
* If many protocols use the LYT Depository, it will be more efficient to transfer LYTs across them (since it will just be an "internal bank transfer")

### Interface
* `deposit(address lyt, address account, uint256 amount)`
  * Deposit funds for a certain account
  * Note: use balanceOf() to check the deposit amount
* `withdraw(address lyt, uint256 amount, address destination)`
  * Withdraw LYTs to the destination, from the msg.sender's account
* `flashloan(address lyt, uint256 amount, address receiver, bytes data)`
  * Flashloan an amount of lyt, to be sent to `receiver`
  * After sending the amount, call a callback function `receiver.handleFlashloan(lyt, amount, data)`
  * If the receiver is not in a whitelist, charge a fees on the flashloan


### [Deprecated] Interface v2
* `deposit(address lyt, address protocol, address user, uint256 amount)`
  * Deposit funds for a certain user of a protocol
  * Note: use balanceOf() to check the deposit amount
* `withdraw(address lyt, address user, uint256 amount, address destination)`
  * Withdraw LYTs to the destination
  * Can only be called by the `protocol` contract
* `flashloan(address lyt, uint256 amount, address receiver, bytes data)`
  * Flashloan an amount of lyt, to be sent to `receiver`
  * After sending the amount, call a callback function `receiver.handleFlashloan(lyt, amount, data)`
  * If the receiver is not in a whitelist, charge a fees on the flashloan
