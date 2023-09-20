// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @notice Library for converting numbers into strings and other string operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol)
library LibString {
    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(uint256 value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits.
            str := add(mload(0x40), 0x80)
            // Update the free memory pointer to allocate.
            mstore(0x40, add(str, 0x20))
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            let w := not(0) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for {
                let temp := value
            } 1 {

            } {
                str := add(str, w) // `sub(str, 1)`.
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                if iszero(temp) {
                    break
                }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `length` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `length * 2 + 2` bytes.
    /// Reverts if `length` is too small for the output to contain all the digits.
    function toHexString(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value, length);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `length` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `length * 2` bytes.
    /// Reverts if `length` is too small for the output to contain all the digits.
    function toHexStringNoPrefix(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            // We need 0x20 bytes for the trailing zeros padding, `length * 2` bytes
            // for the digits, 0x02 bytes for the prefix, and 0x20 bytes for the length.
            // We add 0x20 to the total and round down to a multiple of 0x20.
            // (0x20 + 0x20 + 0x02 + 0x20) = 0x62.
            str := add(mload(0x40), and(add(shl(1, length), 0x42), not(0x1f)))
            // Allocate the memory.
            mstore(0x40, add(str, 0x20))
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let start := sub(str, add(length, length))
            let w := not(1) // Tsk.
            let temp := value
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for {

            } 1 {

            } {
                str := add(str, w) // `sub(str, 2)`.
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(xor(str, start)) {
                    break
                }
            }

            if temp {
                // Store the function selector of `HexLengthInsufficient()`.
                mstore(0x00, 0x2194895a)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Compute the string's length.
            let strLength := sub(end, str)
            // Move the pointer and write the length.
            str := sub(str, 0x20)
            mstore(str, strLength)
        }
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), 20);
    }

    /// @dev Returns a concatenated string of `a` and `b`.
    /// Cheaper than `string.concat()` and does not de-align the free memory pointer.
    function concat(
        string memory a,
        string memory b
    ) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let w := not(0x1f)
            result := mload(0x40)
            let aLength := mload(a)
            // Copy `a` one word at a time, backwards.
            for {
                let o := and(add(aLength, 0x20), w)
            } 1 {

            } {
                mstore(add(result, o), mload(add(a, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) {
                    break
                }
            }
            let bLength := mload(b)
            let output := add(result, aLength)
            // Copy `b` one word at a time, backwards.
            for {
                let o := and(add(bLength, 0x20), w)
            } 1 {

            } {
                mstore(add(output, o), mload(add(b, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) {
                    break
                }
            }
            let totalLength := add(aLength, bLength)
            let last := add(add(result, 0x20), totalLength)
            // Zeroize the slot after the string.
            mstore(last, 0)
            // Stores the length.
            mstore(result, totalLength)
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, and(add(last, 0x1f), w))
        }
    }
}
