// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

error BridgeNFTNative__NFTAlreadyStored();
error BridgeNFTNative__NFTCannotBeReceivedDirectly();
error BridgeNFTNative__NotEnoughBalance();
error BridgeNFTNative__NFTNotYours();

/// @title Bridge NFT Native
/// @author mektigboy
/// @notice Bridges NFT with native token as payment.
/// @dev Uses OpenZeppelin libraries.
contract BridgeNFTNative is IERC721Receiver, Ownable, ReentrancyGuard {
    struct Custody {
        uint256 tokenId;
        address holder;
    }

    event NFTCustody(uint256 indexed tokenId, address holder);
    event NFTRelease(uint256 indexed tokenId, address holder);

    uint256 public constant FEE_NATIVE = 0.00005 ether;

    mapping(uint256 => Custody) public s_holdCustody;

    ERC721Enumerable s_nonFungibleToken;

    constructor(ERC721Enumerable nonFungibleToken) {
        s_nonFungibleToken = nonFungibleToken;
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
            revert BridgeNFTNative__NFTCannotBeReceivedDirectly();
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
            revert BridgeNFTNative__NFTAlreadyStored();
        s_holdCustody[tokenId] = Custody(tokenId, msg.sender);
        s_nonFungibleToken.transferFrom(msg.sender, address(this), tokenId);
        emit NFTCustody(tokenId, msg.sender);
    }

    function retainNFTNative(uint256 tokenId) public payable nonReentrant {
        if (msg.value != FEE_NATIVE) revert BridgeNFTNative__NotEnoughBalance();
        if (msg.sender != s_nonFungibleToken.ownerOf(tokenId))
            revert BridgeNFTNative__NFTNotYours();
        if (s_holdCustody[tokenId].tokenId != 0)
            revert BridgeNFTNative__NFTAlreadyStored();
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

    function withdrawNative() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}
