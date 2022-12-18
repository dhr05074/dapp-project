// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "./IRoomShare.sol";

contract RoomShare is IRoomShare {
    mapping(address => Rent[]) userRents;
    mapping(uint256 => Room) public rooms;
    mapping(uint256 => Rent) rents;
    mapping(uint256 => Rent[]) roomRents;

    uint256 public roomId = 0;
    uint256 rentId = 0;

    function getAllRooms() public view returns (Room[] memory) {
        /* 모든 방을 조회한다. */
        Room[] memory allRooms = new Room[](roomId);
        for (uint256 i = 0; i < roomId; i++) {
            allRooms[i] = rooms[i];
        }
        return allRooms;
    }

    function getMyRents() external view override returns (Rent[] memory) {
        /* 함수를 호출한 유저의 대여 목록을 가져온다. */
        return userRents[msg.sender];
    }

    function getRoomRentHistory(uint256 _roomId)
        external
        view
        override
        returns (Rent[] memory)
    {
        /* 특정 방의 대여 히스토리를 보여준다. */
        return roomRents[_roomId];
    }

    function shareRoom(
        string calldata name,
        string calldata location,
        uint256 price
    ) external override {
        /**
         * 1. isActive 초기값은 true로 활성화, 함수를 호출한 유저가 방의 소유자이며, 365 크기의 boolean 배열을 생성하여 방 객체를 만든다.
         * 2. 방의 id와 방 객체를 매핑한다.
         */
        Room memory room = Room(
            roomId,
            name,
            location,
            true,
            price,
            msg.sender,
            new bool[](365)
        );
        rooms[roomId] = room;

        emit NewRoom(roomId++);
    }

    function rentRoom(
        uint256 _roomId,
        uint256 year,
        uint256 checkInDate,
        uint256 checkOutDate
    ) external payable override {
        /**
         * 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.
         *    a. 현재 활성화(isActive) 되어 있는지
         *    b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지
         *    c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei)
         * 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
         * *** 체크아웃 날짜에는 퇴실하여야하며, 해당일까지 숙박을 이용하려면 체크아웃날짜는 그 다음날로 변경하여야한다. ***
         */

        Room storage room = rooms[_roomId];
        require(room.isActive, "Room is not active");
        for (uint256 i = checkInDate; i < checkOutDate; i++) {
            require(room.isRented[i] == false, "Room is already rented");
        }

        uint256 rentPrice = 1.0e15 * (checkOutDate - checkInDate) * room.price;
        require(msg.value == rentPrice, "Not enough money");

        payable(room.owner).transfer(msg.value);
        _createRent(_roomId, year, checkInDate, checkOutDate);
    }

    function _createRent(
        uint256 _roomId,
        uint256 year,
        uint256 checkInDate,
        uint256 checkOutDate
    ) internal {
        /**
         * 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
         * 2. 계정과 대여 객체들을 매핑한다. (대여 목록)
         * 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
         */

        Room storage room = rooms[_roomId];
        for (uint256 i = checkInDate; i < checkOutDate; i++) {
            room.isRented[i] = true;
        }

        Rent memory rent = Rent(
            rentId,
            _roomId,
            year,
            checkInDate,
            checkOutDate,
            msg.sender
        );
        rents[rentId] = rent;
        roomRents[_roomId].push(rent);
        userRents[msg.sender].push(rent);

        emit NewRent(_roomId, rentId++);
    }

    function _sendFunds(address owner, uint256 value) internal {
        payable(owner).transfer(value);
    }

    function recommendDate(
        uint256 _roomId,
        uint256 checkInDate,
        uint256 checkOutDate
    ) external view override returns (uint256[2] memory) {
        /**
         * 대여가 이미 진행되어 해당 날짜에 대여가 불가능 할 경우,
         * 기존에 예약된 날짜가 언제부터 언제까지인지 반환한다.
         * checkInDate(체크인하려는 날짜) <= 대여된 체크인 날짜 , 대여된 체크아웃 날짜 < checkOutDate(체크아웃하려는 날짜)
         */
        Room memory room = rooms[_roomId];
        uint256 start = 0;
        uint256 end = 0;
        bool isStart = false;
        for (uint256 i = checkInDate; i < checkOutDate; i++) {
            if (room.isRented[i] == true) {
                if (isStart == false) {
                    start = i;
                    isStart = true;
                }
                end = i;
            }
        }

        return [start, end];
    }

    // optional 1
    // caution: 방의 소유자를 먼저 체크해야한다.
    // isActive 필드만 변경한다.
    function markRoomAsInactive(uint256 _roomId) external override {
        Room storage rm = rooms[_roomId];
        if (rm.owner == msg.sender) {
            rm.isActive = false;
        }
    }

    // optional 2
    // caution: 변수의 저장공간에 유의한다.
    // isRented 필드의 초기화를 진행한다.
    function initializeRoomShare(uint256 _roomId) external override {
        for (uint256 i = 0; i < rooms[_roomId].isRented.length; i++) {
            rooms[_roomId].isRented[i] = false;
        }
    }
}
