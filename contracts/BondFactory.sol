// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract BondFactory is ERC721, ERC721URIStorage, ERC721Burnable, AccessManaged, VRFConsumerBase {
    uint256 private _nextTokenId;
    bytes32 internal keyHash;
    uint256 internal fee;
    mapping(uint256 => Bond) public bonds;
    mapping(bytes32 => uint256) private requestToTokenId;

    struct Bond {
        uint256 couponRate;  // Coupon rate in basis points, e.g., 500 for 5%
        uint256 term;        // Term in years
        uint256 randomClearingPrice;  // Auction clearing price
    }

    constructor(address initialAuthority, address vrfCoordinator, address linkToken, bytes32 vrfKeyHash, uint256 vrfFee)
        ERC721("Bond", "EB")
        AccessManaged(initialAuthority)
        VRFConsumerBase(vrfCoordinator, linkToken)
    {
        keyHash = vrfKeyHash;
        fee = vrfFee;
    }

    function createBond(address to, string memory uri, uint256 couponRate, uint256 term) public restricted {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        uint256 tokenId = _nextTokenId++;
        bytes32 requestId = requestRandomness(keyHash, fee);
        requestToTokenId[requestId] = tokenId;
        bonds[tokenId] = Bond(couponRate, term, 0);  // Initialize with default randomClearingPrice
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 tokenId = requestToTokenId[requestId];
        uint256 randomClearingPrice = (randomness % 21) + 9990; // Converts 0-20 to 9990-10010
        bonds[tokenId].randomClearingPrice = randomClearingPrice;
    }

    function safeMint(address to, string memory uri) public restricted {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
