// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../base/NFTBase.sol";
import "../utils/StringUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CardManager is NFTBase {
    address public mainContract;

    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner
    ) NFTBase(name_, symbol_, initialOwner) {}

    modifier onlyOwnerOrMainContract() {
        require(
            msg.sender == owner() || msg.sender == mainContract,
            "Only owner or main contract"
        );
        _;
    }

    // 部署後呼叫設定主合約地址
    function setMainContract(
        address _mainContract
    ) external onlyOwnerOrMainContract {
        mainContract = _mainContract;
    }

    using StringUtils for bytes32;

    struct CardInfo {
        string idolGroup;
        string member;
        string cardNumber;
        uint256 listPrice;
        string photoURI;
    }

    struct PendingTransfer {
        address buyer;
        uint256 amount;
        bool approved;
    }

    struct CardDisplay {
        string uid;
        string idolGroup;
        string member;
        string cardNumber;
        uint256 listPrice;
        string photoURI;
        bool isSold;
    }

    struct PendingRequest {
        string uid;
        address buyer;
        uint256 amount;
        uint256 timestamp;
    }

    CardInfo public defaultCardInfo;
    
    mapping(string => uint256) private uidToTokenId;
    mapping(uint256 => string) private tokenIdToUID;
    mapping(string => bool) public cardUIDUsed;
    mapping(string => CardInfo) public uidToCardInfo;
    mapping(string => PendingTransfer) public pendingTransfers;
    mapping(string => uint256) public requestTimestamps;
    mapping(uint256 => CardInfo) public tokenIdToCardInfo;
    mapping(address => uint256) public prepaidAmount;
    // NFT 階段狀態，1=未購買，2=已購買未綁定，3=已購買已綁定
    mapping(uint256 => uint8) public phase;
    
    string[] public allCardUIDs;
    string[] public resaleCardUIDs;
    mapping(string => bool) public isResaleListed;

    event CardPurchased(address indexed buyer, uint256 amount, string uid);
    event CardRequested(address indexed buyer, string uid);
    event CardApproved(string uid, address indexed buyer, uint256 tokenId);
    event CardInfoUpdatedWithUID(string uid, string idolGroup, string member, string cardNumber, uint256 listPrice, string photoURI);
    event CardRequestRejected(string uid, address buyer);
    event ResaleCancelled(string uid, address owner);

    // 設定卡片價格並批量發行指定數量的卡片
    function setCardPrice(
        uint256 newPrice,
        string memory idolGroup,
        string memory member,
        string memory cardNumber,
        uint256 listPrice,
        string memory photoURI,
        uint256 amount
    ) external onlyOwnerOrMainContract returns (string[] memory) {
        require(amount > 0, "Amount must be greater than 0");
        cardPrice = newPrice;

        bytes32 hash = keccak256(
            abi.encodePacked(
                idolGroup,
                member,
                cardNumber,
                listPrice,
                photoURI,
                block.timestamp,
                block.number
            )
        );
        string memory baseUID = StringUtils.toHexString(hash);

        string[] memory generatedUIDs = new string[](amount);

        for (uint256 i = 0; i < amount; i++) {
            string memory numberedUID = string(
                abi.encodePacked(baseUID, "-", Strings.toString(i + 1))
            );

            require(!cardUIDUsed[numberedUID], "UID already used");

            CardInfo memory newCardInfo = CardInfo(
                idolGroup,
                member,
                cardNumber,
                listPrice,
                photoURI
            );

            uidToCardInfo[numberedUID] = newCardInfo;
            cardUIDUsed[numberedUID] = true;
            allCardUIDs.push(numberedUID);
            generatedUIDs[i] = numberedUID;

            emit CardInfoUpdatedWithUID(
                numberedUID,
                idolGroup,
                member,
                cardNumber,
                listPrice,
                photoURI
            );
        }

        defaultCardInfo = CardInfo(
            idolGroup,
            member,
            cardNumber,
            listPrice,
            photoURI
        );

        return generatedUIDs;
    }

    // 獲取當前卡片價格
    function getCardPrice() external view returns (uint256) {
        return cardPrice;
    }

    // 用戶綁定實體卡片UID到已擁有的NFT
    function bindUID(string memory uid) external {
        require(!uidUsed[uid], "UID already bound");

        uint256 tokenId = uidToTokenId[uid];
        require(tokenId != 0, "Token not minted yet");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(phase[tokenId] == 2, "Token not in bindable phase");

        uidUsed[uid] = true;
        tokenIdToUID[tokenId] = uid;
        phase[tokenId] = 3;
    }

    // 管理員審批用戶的卡片綁定請求
    function approveTransfer(
        string memory uid
    ) external onlyOwnerOrMainContract {
        require(
            pendingTransfers[uid].amount == cardPrice,
            "Payment not received"
        );
        require(pendingTransfers[uid].buyer != address(0), "No request");
        require(!pendingTransfers[uid].approved, "Already approved");
        require(!uidUsed[uid], "UID already bound");

        address buyer = pendingTransfers[uid].buyer;
        uint256 tokenId = nextTokenId;
        _safeMint(buyer, tokenId);

        if (bytes(defaultCardInfo.photoURI).length > 0) {
            _setTokenURI(tokenId, defaultCardInfo.photoURI);
        }

        tokenIdToCardInfo[tokenId] = defaultCardInfo;

        uidUsed[uid] = true;
        uidToTokenId[uid] = tokenId;
        tokenIdToUID[tokenId] = uid;
        nextTokenId++;

        payable(owner()).transfer(cardPrice);
        pendingTransfers[uid].approved = true;

        emit CardApproved(uid, buyer, tokenId);
    }

    // 管理員拒絕用戶的卡片綁定請求並退款
    function rejectTransfer(
        string memory uid
    ) external onlyOwnerOrMainContract {
        require(pendingTransfers[uid].buyer != address(0), "No request exists");
        require(!pendingTransfers[uid].approved, "Already approved");

        address buyer = pendingTransfers[uid].buyer;
        uint256 amount = pendingTransfers[uid].amount;

        payable(buyer).transfer(amount);

        delete pendingTransfers[uid];
        delete requestTimestamps[uid];

        emit CardRequestRejected(uid, buyer);
    }

    // 獲取指定TokenID的卡片詳細資訊
    function getCardInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            string memory idolGroup,
            string memory member,
            string memory cardNumber,
            uint256 listPrice,
            string memory photoURI
        )
    {
        CardInfo memory info = tokenIdToCardInfo[tokenId];
        return (
            info.idolGroup,
            info.member,
            info.cardNumber,
            info.listPrice,
            info.photoURI
        );
    }

    // 獲取公司發行的所有卡片清單（含售出狀態）
    function getCompanyCards() external view returns (CardDisplay[] memory) {
        uint256 count = allCardUIDs.length;
        CardDisplay[] memory cards = new CardDisplay[](count);

        for (uint256 i = 0; i < count; i++) {
            string memory uid = allCardUIDs[i];
            CardInfo memory info = uidToCardInfo[uid];
            bool isSold = uidUsed[uid];

            cards[i] = CardDisplay({
                uid: uid,
                idolGroup: info.idolGroup,
                member: info.member,
                cardNumber: info.cardNumber,
                listPrice: info.listPrice,
                photoURI: info.photoURI,
                isSold: isSold
            });
        }

        return cards;
    }

    // 獲取所有可購買的一手卡片清單
    function getAvailableCards() external view returns (CardDisplay[] memory) {
        uint256 availableCount = 0;

        for (uint256 i = 0; i < allCardUIDs.length; i++) {
            string memory uid = allCardUIDs[i];
            uint256 tokenId = uidToTokenId[uid];
            if (tokenId == 0) {
                availableCount++;
            }
        }

        CardDisplay[] memory availableCards = new CardDisplay[](availableCount);
        uint256 index = 0;

        for (uint256 i = 0; i < allCardUIDs.length; i++) {
            string memory uid = allCardUIDs[i];
            uint256 tokenId = uidToTokenId[uid];
            if (tokenId == 0) {
                CardInfo memory info = uidToCardInfo[uid];
                availableCards[index] = CardDisplay({
                    uid: uid,
                    idolGroup: info.idolGroup,
                    member: info.member,
                    cardNumber: info.cardNumber,
                    listPrice: info.listPrice,
                    photoURI: info.photoURI,
                    isSold: false
                });
                index++;
            }
        }
        return availableCards;
    }

    // 用戶購買指定UID的一手卡片
    function purchaseSpecificCard(
        string memory uid,
        address recipient
    ) external payable returns (string memory) {
        require(!uidUsed[uid], "Card already sold");
        require(cardUIDUsed[uid], "Card does not exist");

        CardInfo memory info = uidToCardInfo[uid];
        require(msg.value == info.listPrice, "Incorrect payment amount");

        uint256 tokenId = nextTokenId;

        _safeMint(recipient, tokenId);

        if (bytes(info.photoURI).length > 0) {
            _setTokenURI(tokenId, info.photoURI);
        }

        tokenIdToCardInfo[tokenId] = info;

        uidToTokenId[uid] = tokenId;
        tokenIdToUID[tokenId] = uid;
        phase[tokenId] = 3;
        uidUsed[uid] = true;

        nextTokenId++;

        payable(owner()).transfer(msg.value);

        emit CardPurchased(recipient, msg.value, uid);
        emit CardApproved(uid, recipient, tokenId);

        return uid;
    }

    // 獲取所有待審批的卡片綁定請求
    function getPendingCardRequests()
        external
        view
        returns (PendingRequest[] memory)
    {
        uint256 pendingCount = 0;

        for (uint256 i = 0; i < allCardUIDs.length; i++) {
            string memory uid = allCardUIDs[i];
            if (
                pendingTransfers[uid].buyer != address(0) &&
                !pendingTransfers[uid].approved &&
                !uidUsed[uid]
            ) {
                pendingCount++;
            }
        }

        PendingRequest[] memory requests = new PendingRequest[](pendingCount);
        uint256 index = 0;

        for (uint256 i = 0; i < allCardUIDs.length; i++) {
            string memory uid = allCardUIDs[i];
            if (
                pendingTransfers[uid].buyer != address(0) &&
                !pendingTransfers[uid].approved &&
                !uidUsed[uid]
            ) {
                requests[index] = PendingRequest({
                    uid: uid,
                    buyer: pendingTransfers[uid].buyer,
                    amount: pendingTransfers[uid].amount,
                    timestamp: requestTimestamps[uid]
                });

                index++;
            }
        }

        return requests;
    }

    // 獲取指定用戶擁有的所有卡片
    function getUserCards(
        address user
    ) external view returns (CardDisplay[] memory) {
        uint256 balance = balanceOf(user);
        CardDisplay[] memory userCards = new CardDisplay[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);
            string memory uid = tokenIdToUID[tokenId];
            CardInfo memory info = tokenIdToCardInfo[tokenId];

            userCards[i] = CardDisplay({
                uid: uid,
                idolGroup: info.idolGroup,
                member: info.member,
                cardNumber: info.cardNumber,
                listPrice: info.listPrice,
                photoURI: info.photoURI,
                isSold: true
            });
        }

        return userCards;
    }

    // 用戶綁定實體卡片UID到指定接收者的NFT
    function bindUID(string memory uid, address recipient) external {
        require(!uidUsed[uid], "UID already bound");

        uint256 tokenId = uidToTokenId[uid];
        require(tokenId != 0, "Token not minted yet");
        require(ownerOf(tokenId) == recipient, "Not token owner");
        require(phase[tokenId] == 2, "Token not in bindable phase");

        uidUsed[uid] = true;
        tokenIdToUID[tokenId] = uid;
        phase[tokenId] = 3;
    }

    // 將擁有的卡片上架到二手市場
    function listCardForResale(
        string memory uid,
        uint256 resalePrice
    ) external {
        require(!isResaleListed[uid], "Already listed");

        CardInfo storage card = uidToCardInfo[uid];

        require(bytes(card.idolGroup).length > 0, "Card info missing");
        require(card.listPrice > 0, "Invalid card");

        card.listPrice = resalePrice;

        resaleCardUIDs.push(uid);
        isResaleListed[uid] = true;
    }

    // 獲取所有二手市場上架的卡片
    function getResaleCards() external view returns (CardDisplay[] memory) {
        uint256 count = 0;

        for (uint256 i = 0; i < resaleCardUIDs.length; i++) {
            if (isResaleListed[resaleCardUIDs[i]]) {
                count++;
            }
        }

        CardDisplay[] memory cards = new CardDisplay[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < resaleCardUIDs.length; i++) {
            string memory uid = resaleCardUIDs[i];
            if (isResaleListed[uid]) {
                CardInfo memory info = uidToCardInfo[uid];
                cards[index] = CardDisplay({
                    uid: uid,
                    idolGroup: info.idolGroup,
                    member: info.member,
                    cardNumber: info.cardNumber,
                    listPrice: info.listPrice, 
                    photoURI: info.photoURI,
                    isSold: false
                });
                index++;
            }
        }

        return cards;
    }

    // 獲取指定UID卡片的當前持有者地址
    function getNFTHolder(string memory uid) external view returns (address) {
        uint256 tokenId = uidToTokenId[uid];
        require(tokenId != 0, "Token does not exist");
        return ownerOf(tokenId);
    }

    // 購買二手市場上的卡片
    function purchaseResaleCard(
        string memory uid,
        address recipient
    ) external payable {
        require(isResaleListed[uid], "Card not for resale");

        uint256 tokenId = uidToTokenId[uid];
        address seller = ownerOf(tokenId);
        uint256 price = uidToCardInfo[uid].listPrice;

        require(msg.value == price, "Incorrect payment");

        _transfer(seller, recipient, tokenId);

        payable(seller).transfer(price);

        isResaleListed[uid] = false;

        for (uint256 i = 0; i < resaleCardUIDs.length; i++) {
            if (
                keccak256(abi.encodePacked(resaleCardUIDs[i])) ==
                keccak256(abi.encodePacked(uid))
            ) {
                resaleCardUIDs[i] = resaleCardUIDs[resaleCardUIDs.length - 1];
                resaleCardUIDs.pop();
                break;
            }
        }

        emit CardPurchased(recipient, price, uid);
        uidToTokenId[uid] = tokenId;
        tokenIdToUID[tokenId] = uid;
    }

    // 取消二手市場上架的卡片
    function cancelResale(string memory uid) external {
        isResaleListed[uid] = false;

        for (uint256 i = 0; i < resaleCardUIDs.length; i++) {
            if (
                keccak256(abi.encodePacked(resaleCardUIDs[i])) ==
                keccak256(abi.encodePacked(uid))
            ) {
                resaleCardUIDs[i] = resaleCardUIDs[resaleCardUIDs.length - 1];
                resaleCardUIDs.pop();
                break;
            }
        }

        emit ResaleCancelled(uid, msg.sender);
    }
}