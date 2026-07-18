// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NETURION Confidential Data Marketplace
 * @notice Fairblock IBE ile şifreli veri alım/satım platformu
 * @dev Satıcı veriyi şifreli yükler, alıcı ödeme yapar, decryption key açılır
 */
contract DataMarketplace {

    struct DataListing {
        address seller;
        string title;
        string description;
        bytes encryptedData;    // Fairblock IBE ile şifrelenmiş veri
        bytes32 dataHash;       // Veri bütünlük doğrulama
        uint256 price;          // Wei cinsinden fiyat
        uint256 conditionBlock; // Bu block'tan sonra decryption key açılır
        bool active;
        uint256 salesCount;
    }

    struct Purchase {
        address buyer;
        uint256 listingId;
        uint256 paidAt;
        bool keyReleased;
    }

    DataListing[] public listings;
    mapping(uint256 => Purchase[]) public purchases;
    mapping(address => uint256[]) public sellerListings;
    mapping(address => uint256[]) public buyerPurchases;

    event ListingCreated(uint256 indexed id, address seller, string title, uint256 price);
    event DataPurchased(uint256 indexed listingId, address buyer, uint256 purchaseIndex);
    event KeyReleased(uint256 indexed listingId, address buyer);

    function createListing(
        string calldata title,
        string calldata description,
        bytes calldata encryptedData,
        bytes32 dataHash,
        uint256 price,
        uint256 conditionBlock
    ) external returns (uint256) {
        uint256 id = listings.length;
        listings.push(DataListing({
            seller: msg.sender,
            title: title,
            description: description,
            encryptedData: encryptedData,
            dataHash: dataHash,
            price: price,
            conditionBlock: conditionBlock,
            active: true,
            salesCount: 0
        }));
        sellerListings[msg.sender].push(id);
        emit ListingCreated(id, msg.sender, title, price);
        return id;
    }

    function purchaseData(uint256 listingId) external payable {
        DataListing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");

        uint256 purchaseIndex = purchases[listingId].length;
        purchases[listingId].push(Purchase({
            buyer: msg.sender,
            listingId: listingId,
            paidAt: block.timestamp,
            keyReleased: false
        }));
        buyerPurchases[msg.sender].push(listingId);
        listing.salesCount++;

        // Transfer payment to seller
        payable(listing.seller).transfer(msg.value);

        emit DataPurchased(listingId, msg.sender, purchaseIndex);
    }

    function getListingCount() external view returns (uint256) {
        return listings.length;
    }

    function hasPurchased(uint256 listingId, address buyer) external view returns (bool) {
        Purchase[] storage p = purchases[listingId];
        for (uint256 i = 0; i < p.length; i++) {
            if (p[i].buyer == buyer) return true;
        }
        return false;
    }
}
