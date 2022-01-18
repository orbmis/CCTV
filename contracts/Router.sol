// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * Implementation of "unstructered proxy" pattern.
 */
contract Router {

    // storage position of the admin address of the router.
    bytes32 private constant ROUTER_ADMIN = keccak256('cctv.proxy.admin');

    /**
    * Reverts transaction if called by an account that's not the admin.
    */
    modifier onlyAdmin() {
        require(msg.sender == getRouterAdmin());
        _;
    }

    /**
    * The constructor sets router admin address.
    */
    constructor() {
        setRouterAdmin(msg.sender);
    }

    /**
    * Retrieves the address of the admin account allowed to update router configuration.
    *
    * @return admin the address of the owner
    */
    function getRouterAdmin() public view returns (address admin) {
        bytes32 storagePosition = ROUTER_ADMIN;

        assembly {
            admin := sload(storagePosition)
        }
    }

    /**
    * Sets the address of the router admin.
    *
    * @param admin The address of the admin of the router.
    */
    function setRouterAdmin(address admin) public {
        bytes32 storagePosition = ROUTER_ADMIN;

        assembly {
            sstore(storagePosition, admin)
        }
    }

    /**
    * Helper function to retrieve a method id from a function selector.
    *
    * @param functionSelector The function selector to get the id for.
    * @return methodId Teh respective method id.
    */
    function getMethodId(string memory functionSelector) public pure returns (bytes4 methodId) {
        methodId = bytes4(keccak256(abi.encodePacked(functionSelector)));
    }

    /**
    * Stores a collection of method ids for a contract deployed at a specific address.
    * The hash of the method id is used as the storage location for the value to be stored,
    * which is the address of the associated contract.
    *
    * The router can then look up a contract address for various function calls, by hashing
    * the method id and retrieving the value stored at that location. In this way the router
    * knows how to route different function calls to different addresses.
    *
    * This is basically the "unstructured storage" pattern used for routing.
    * The only caveat is that there is currently no protection against selector collisions,
    * meaning the same function with the same arguments in different contracts can cause issues.
    *
    * The method ids are the first 4 bytes of the hash of the function selector.
    * The function selector is the name of the function and nad types of each argument / parameter.
    * For example, the selector for this function is: "setFunctionMapping(address,bytes4[])".
    *
    * @param contractAddress The address of the contract to route the function calls to.
    * @param methodIds Teh method ids of th functions to route to the contract.
    */
    function setFunctionMapping(address contractAddress, bytes4[] memory methodIds)
      external
    {
        for (uint i = 0; i < methodIds.length; i++) {
            bytes32 storagePosition = keccak256(abi.encodePacked(methodIds[i]));

            assembly {
                sstore(storagePosition, contractAddress)
            }
        }
    }

    /**
    * Retrieves the contract address to route a funcation call to, by looking up the address
    * at the storage position that is determined by the hash of the functional call's method id.
    *
    * @param methodId The method id of the function selector of the function that's being called.
    * @return contractAddress The address to the contract to route the function call to.
    */
    function getFunctionMapping(bytes4 methodId) view internal returns (address contractAddress) {
        bytes32 storagePosition = keccak256(abi.encodePacked(methodId));

        assembly {
            contractAddress := sload(storagePosition)
        }
    }

    /**
    * Forwards incoming function calls to the destination contract.
    * The destination contract is determined by looking up the contract address
    * at the storage position identified by hashing the function selector.
    */
    fallback() external {
        address destination = getFunctionMapping(msg.sig);

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            let result := delegatecall(gas(), destination, ptr, calldatasize(), 0, 0)

            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 {
                revert(ptr, size)
            }
            default {
                return(ptr, size)
            }
        }
    }
}
