// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/*
    Implement a solidity contract that verifies the computation for the EC points.

    $$
    0 = -A_1B_2 +\alpha_1\beta_2 + X_1\gamma_2 + C_1\delta_2\\X_1=x_1G1 + x_2G1 + x_3G1
    $$

    Pick any (nontrivial) values to generate the points that results a balanced equation.

    Note that x1, x2, x3 are uint256 and the rest are G1 or G2 points.

    You will need to take in the following as arguments to a public function:

    $$
    A_1, B_2, C_1, x_1,x_2,x_3
    $$

    Use the ethereum precompiles for addition and multiplication to compute $X$, 
    then the precompile for pairing to compute the entire equation in one go.

    All other points should be hardcoded into the contract. For example, suppose you want

    $$
    \alpha_1 = 5G_1\\
    \beta_2 = 6G_2\\
    ...
    $$

    You need to compute those values and write them as constants inside the contract.

    **Tip: make the pairing work with only two sets of points (2 G1 and 2 G2) first for simple examples. 
    The order for G2 in the precompile is not what you are expecting it to be!**
*/

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

    constructor() {
        G1 = G1Point(1, 2);
        alpha_1 = G1Point(3, 4);
        beta_2 = G2Point([uint256(5), 6], [uint256(7), 8]);
        gama_2 = G2Point([uint256(9), 10], [uint256(11), 12]);
        delta_2 = G2Point([uint256(9), 10], [uint256(11), 12]);
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
        
        return pairing(negate(a), b, alpha_1, beta_2, X, gama_2, c, delta_2);
    }

      function pairing(
            G1Point memory a1,
            G2Point memory a2,
            G1Point memory b1,
            G2Point memory b2,
            G1Point memory c1,
            G2Point memory c2,
            G1Point memory d1,
            G2Point memory d2
        ) internal view returns (bool) {
            G1Point[4] memory p1 = [a1, b1, c1, d1];
            G2Point[4] memory p2 = [a2, b2, c2, d2];

            uint256 inputSize = 24;
            uint256[] memory input = new uint256[](inputSize);

            for (uint256 i = 0; i < 4; i++) {
                uint256 j = i * 6;
                input[j + 0] = p1[i].x;
                input[j + 1] = p1[i].y;
                input[j + 2] = p2[i].x[0];
                input[j + 3] = p2[i].x[1];
                input[j + 4] = p2[i].y[0];
                input[j + 5] = p2[i].y[1];
            }

            uint256[1] memory out;
            bool success;

            // solium-disable-next-line security/no-inline-assembly
            assembly {
                success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
                // Use "invalid" to make gas estimation work
                switch success case 0 { invalid() }
            }

            require(success, "pairing-opcode-failed");

            return out[0] != 0;
        }
}

