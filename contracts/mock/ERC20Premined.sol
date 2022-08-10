import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ERC20Premined is ERC20Burnable {
    uint8 decimal;
    constructor(
        string memory name,
        uint8 _decimal
    ) ERC20(name, name) {
        decimal = _decimal;
        _mint(msg.sender, 2 ** 255);
    }

    function decimals() public view virtual override returns (uint8) {
        return decimal;
    }
}