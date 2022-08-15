// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

error BridgeNFTCustom__NFTAlreadyStored();
error BridgeNFTCustom__NFTCannotBeReceivedDirectly();
error BridgeNFTCustom__NotEnoughBalance();
error BridgeNFTCustom__NFTNotYours();

/// @title Bridge NFT Custom
/// @author mektigboy
/// @notice Bridges NFT with custom ERC20 token as payment.
/// @dev Uses OpenZeppelin libraries.
contract BridgeNFTCustom is IERC721Receiver, Ownable, ReentrancyGuard {
    struct Custody {
        uint256 tokenId;
        address holder;
    }

    event NFTCustody(uint256 indexed tokenId, address holder);
    event NFTRelease(uint256 indexed tokenId, address holder);

    uint256 public constant FEE_CUSTOM = 1 ether;
    uint256 public constant FEE_NATIVE = 0.00005 ether;

    mapping(uint256 => Custody) public s_holdCustody;

    ERC721Enumerable s_nonFungibleToken;
    IERC20 s_payToken;

    constructor(ERC721Enumerable nonFungibleToken, IERC20 payToken) {
        s_nonFungibleToken = nonFungibleToken;
        s_payToken = payToken;
    }

    function emergencyDelete(uint256 tokenId) public nonReentrant onlyOwner {
        delete s_holdCustody[tokenId];
        emit NFTRelease(tokenId, msg.sender);
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        if (from != address(0x0))
            revert BridgeNFTCustom__NFTCannotBeReceivedDirectly();
        return IERC721Receiver.onERC721Received.selector;
    }

    function releaseNFT(uint256 tokenId, address wallet)
        public
        nonReentrant
        onlyOwner
    {
        s_nonFungibleToken.transferFrom(address(this), wallet, tokenId);
        delete s_holdCustody[tokenId];
        emit NFTRelease(tokenId, msg.sender);
    }

    function retainNewNFT(uint256 tokenId) public nonReentrant onlyOwner {
        if (s_holdCustody[tokenId].tokenId != 0)
            revert BridgeNFTCustom__NFTAlreadyStored();
        s_holdCustody[tokenId] = Custody(tokenId, msg.sender);
        s_nonFungibleToken.transferFrom(msg.sender, address(this), tokenId);
        emit NFTCustody(tokenId, msg.sender);
    }

    /// @notice This function retains the NFT payed with custom token selected by user.
    function retainNFTCustom(uint256 tokenId) public payable nonReentrant {
        if (msg.sender != s_nonFungibleToken.ownerOf(tokenId))
            revert BridgeNFTCustom__NFTNotYours();
        if (s_holdCustody[tokenId].tokenId != 0)
            revert BridgeNFTCustom__NFTAlreadyStored();
        s_payToken.transferFrom(msg.sender, address(this), FEE_CUSTOM);
        s_holdCustody[tokenId] = Custody(tokenId, msg.sender);
        s_nonFungibleToken.transferFrom(msg.sender, address(this), tokenId);
        emit NFTCustody(tokenId, msg.sender);
    }

    /// @notice This function retains the NFT payed with native token.
    function retainNFTNative(uint256 tokenId) public payable nonReentrant {
        if (msg.value != FEE_NATIVE) revert BridgeNFTCustom__NotEnoughBalance();
        if (msg.sender != s_nonFungibleToken.ownerOf(tokenId))
            revert BridgeNFTCustom__NFTNotYours();
        if (s_holdCustody[tokenId].tokenId != 0)
            revert BridgeNFTCustom__NFTAlreadyStored();
        s_holdCustody[tokenId] = Custody(tokenId, msg.sender);
        s_nonFungibleToken.transferFrom(msg.sender, address(this), tokenId);
        emit NFTCustody(tokenId, msg.sender);
    }

    function updateOwner(uint256 tokenId, address newHolder)
        public
        nonReentrant
        onlyOwner
    {
        s_holdCustody[tokenId] = Custody(tokenId, newHolder);
        emit NFTCustody(tokenId, newHolder);
    }

    function withdrawCustom() public payable onlyOwner {
        s_payToken.transfer(msg.sender, s_payToken.balanceOf(address(this)));
    }

    function withdrawNative() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}
