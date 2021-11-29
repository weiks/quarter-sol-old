pragma solidity 0.5.6;

//Interface to control transfer of q2
contract ITransferController {
    function addWhiteAddressToWhiteList(address _user, bool status)
        public
        returns (bool);

    function isWhiteListed(address _user) public view returns (bool);
}
