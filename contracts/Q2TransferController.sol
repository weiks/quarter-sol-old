pragma solidity 0.5.6;
import "./Ownable.sol";
import "./IQ2TransferController.sol";

//implementation to control transfer of q2

contract Q2TransferController is IQ2TransferController, Ownable {
    mapping(address => bool) public whitelistedAddresses;

    mapping(address => bool) moderator;

    // add addresss to transfer q2
    function addWhiteAddressToWhiteList(address _user, bool status)
        public
        returns (bool)
    {
        require(msg.sender == owner || moderator[msg.sender]);
        whitelistedAddresses[_user] = status;
    }

    function isWhiteListed(address _user) public view returns (bool) {
        return whitelistedAddresses[_user];
    }

    function addModerator(address _user, bool status) public onlyOwner {
        moderator[_user] = status;
    }
}
