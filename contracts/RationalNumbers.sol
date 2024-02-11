// SPDX-License-Identifier: MIT
import "hardhat/console.sol";


pragma solidity ^0.8.15;

contract RationalNumbers {
    struct G1Point {
        uint256 x;
        uint256 y;
    }

    struct G2Point {
        uint256[2] x;
        uint256[2] y;
    }

    uint256 constant curve_order =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint constant prime =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    G1Point G1;
    G1Point alpha_1;
    G2Point beta_2;
    G2Point gama_2;
    G2Point delta_2;

    constructor(
        G1Point memory _alpha_1, 
        G2Point memory _beta_2, 
        G2Point memory _gama_2, 
        G2Point memory _delta_2) public {
        G1 = G1Point(1, 2);
        alpha_1 = _alpha_1;
        beta_2 = _beta_2;
        gama_2 = _gama_2;
        delta_2 = _delta_2;
    }

    function rationalAdd(
        G1Point calldata A,
        G1Point calldata B,
        uint256 num,
        uint256 den
    ) public view returns (bool verified) {
        uint256 inv_den = expmod(den, curve_order - 2, curve_order);
        uint256 num_den = mulmod(num, inv_den, curve_order);
        G1Point memory left = add(A, B);
        G1Point memory right = scalar_mul(G1, num_den);

        return (left.x == right.x && left.y == right.y);
    }

    function matMul(
        uint256[] calldata matrix,
        uint256 n, // n x n for the matrix
        G1Point[] calldata s, // n elements
        G1Point[] calldata o // n elements
    ) public view returns (bool verified) {
        if (matrix.length != n * n || s.length != n || o.length != n) {
            revert();
        }

        for (uint i = 0; i < n; i++) {
            G1Point memory Ms = scalar_mul(s[0], matrix[i * n]);
            for (uint j = 1; j < n; j++) {
                Ms = add(Ms, scalar_mul(s[j], matrix[i * n + j]));
            }
            if (Ms.x != o[i].x || Ms.y != o[i].y) {
                return false;
            }
        }
        
        return true;
    }

    function expmod(uint base, uint e, uint m) public view returns (uint o) {
        assembly {
            // define pointer
            let p := mload(0x40)
            // store data assembly-favouring ways
            mstore(p, 0x20) // Length of Base
            mstore(add(p, 0x20), 0x20) // Length of Exponent
            mstore(add(p, 0x40), 0x20) // Length of Modulus
            mstore(add(p, 0x60), base) // Base
            mstore(add(p, 0x80), e) // Exponent
            mstore(add(p, 0xa0), m) // Modulus
            if iszero(staticcall(sub(gas(), 2000), 0x05, p, 0xc0, p, 0x20)) {
                revert(0, 0)
            }
            // data
            o := mload(p)
        }
    }

    function add(
        G1Point memory p1,
        G1Point memory p2
    ) internal view returns (G1Point memory r) {
        uint256[4] memory input;
        input[0] = p1.x;
        input[1] = p1.y;
        input[2] = p2.x;
        input[3] = p2.y;
        bool success;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }

        require(success, "pairing-add-failed");
    }

    /*
     * @return r the product of a point on G1 and a scalar, i.e.
     *         p == p.scalar_mul(1) and p.plus(p) == p.scalar_mul(2) for all
     *         points p.
     */
    function scalar_mul(
        G1Point memory p,
        uint256 s
    ) internal view returns (G1Point memory r) {
        uint256[3] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }
        }
        require(success, "pairing-mul-failed");
    }

      function negate(G1Point memory p) internal pure returns (G1Point memory) {
            // The prime q in the base field F_q for G1
            if (p.x == 0 && p.y == 0) {
            return G1Point(0, 0);
            } else {
            return G1Point(p.x, prime - (p.y % prime));
            }
        }

    function checkPairings(G1Point memory a, 
                          G2Point memory b,
                          G1Point memory c,
                          uint256 x1,
                          uint256 x2,
                          uint256 x3) public view returns (bool){

        G1Point memory x1G1 = scalar_mul(G1, x1);
        G1Point memory x2G1 = scalar_mul(G1, x2);
        G1Point memory x3G1 = scalar_mul(G1, x3);
        G1Point memory X = add(add(x1G1, x2G1), x3G1);        
        G1Point memory a1_neg = negate(a);
        //return pairing(negate(a), b, alpha_1, beta_2, X, gama_2, c, delta_2);
        uint256[24] memory input = [
            a1_neg.x, a1_neg.y, b.x[1], b.x[0], b.y[1], b.y[0], 
            alpha_1.x, alpha_1.y, beta_2.x[1], beta_2.x[0], beta_2.y[1], beta_2.y[0], 
            X.x, X.y, gama_2.x[1], gama_2.x[0], gama_2.y[1], gama_2.y[0], 
            c.x, c.y, delta_2.x[1], delta_2.x[0], delta_2.y[1], delta_2.y[0]
        ];

        return run24(input);
    }

    function run24(uint256[24] memory input) public view returns (bool) {
        assembly {
            let success := staticcall(gas(), 0x08, input, 0x300, input, 0x20)
            if success {
                return(input, 0x20)
            }
        }
        revert("Wrong pairing");
    }
}

