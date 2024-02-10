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
            a1_neg.x, a1_neg.y, b.x[0], b.x[1], b.y[0], b.y[1], 
            alpha_1.x, alpha_1.y, beta_2.x[0], beta_2.x[1], beta_2.y[0], beta_2.y[1], 
            X.x, X.y, gama_2.x[0], gama_2.x[1], gama_2.y[0], gama_2.y[1], 
            c.x, c.y, delta_2.x[0], delta_2.x[1], delta_2.y[0], delta_2.y[1]
        ];

        return run24(input);
    }

    function testPairing12() public view returns (bool){
        uint256 aG1_x = 3010198690406615200373504922352659861758983907867017329644089018310584441462;
        uint256 aG1_y = 17861058253836152797273815394432013122766662423622084931972383889279925210507;

        uint256 bG2_x1 = 2725019753478801796453339367788033689375851816420509565303521482350756874229;
        uint256 bG2_x2 = 7273165102799931111715871471550377909735733521218303035754523677688038059653;
        uint256 bG2_y1 = 2512659008974376214222774206987427162027254181373325676825515531566330959255;
        uint256 bG2_y2 = 957874124722006818841961785324909313781880061366718538693995380805373202866;

        uint256 cG1_x = 4503322228978077916651710446042370109107355802721800704639343137502100212473;
        uint256 cG1_y = 6132642251294427119375180147349983541569387941788025780665104001559216576968;

        uint256 dG2_x1 = 18029695676650738226693292988307914797657423701064905010927197838374790804409;
        uint256 dG2_x2 = 14583779054894525174450323658765874724019480979794335525732096752006891875705;
        uint256 dG2_y1 = 2140229616977736810657479771656733941598412651537078903776637920509952744750;
        uint256 dG2_y2 = 11474861747383700316476719153975578001603231366361248090558603872215261634898;

        uint256[12] memory input = [
            aG1_x,
            aG1_y,
            bG2_x2,
            bG2_x1,
            bG2_y2,
            bG2_y1,
            cG1_x,
            cG1_y,
            dG2_x2,
            dG2_x1,
            dG2_y2,
            dG2_y1
        ];

        bool x = run12(input);
        console.log("result:", x);
        return x;
    }

       function testPairing24() public view returns (bool){
        uint256[24] memory input = [
            uint256(4503322228978077916651710446042370109107355802721800704639343137502100212473),
            15755600620544848102871225597907291547126923215509797882023933893086009631615,
            10191129150170504690859455063377241352678147020731325090942140630855943625622,
            16727484375212017249697795760885267597317766655549468217180521378213906474374,
            12345624066896925082600651626583520268054356403303305150512393106955803260718,
            13790151551682513054696583104432356791070435696840691503641536676885931241944,
            4503322228978077916651710446042370109107355802721800704639343137502100212473,
            6132642251294427119375180147349983541569387941788025780665104001559216576968,
            10191129150170504690859455063377241352678147020731325090942140630855943625622,
            16727484375212017249697795760885267597317766655549468217180521378213906474374,
            12345624066896925082600651626583520268054356403303305150512393106955803260718,
            13790151551682513054696583104432356791070435696840691503641536676885931241944,
            4503322228978077916651710446042370109107355802721800704639343137502100212473,
            6132642251294427119375180147349983541569387941788025780665104001559216576968,
            10857046999023057135944570762232829481370756359578518086990519993285655852781,
            8495653923123431417604973247489272438418190587263600148770280649306958101930,
            11559732032986387107991004021392285783925812861821192530917403151452391805634,
            4082367875863433681332203403145435568316851327593401208105741076214120093531,
            1,
            21888242871839275222246405745257275088696311157297823662689037894645226208581,
            10191129150170504690859455063377241352678147020731325090942140630855943625622,
            16727484375212017249697795760885267597317766655549468217180521378213906474374,
            12345624066896925082600651626583520268054356403303305150512393106955803260718,
            13790151551682513054696583104432356791070435696840691503641536676885931241944
        ];

        bool x = run24(input);
        console.log("result:", x);
        return x;
    }

   function run12(uint256[12] memory input) public view returns (bool) {
        assembly {
            let success := staticcall(gas(), 0x08, input, 0x0180, input, 0x20)
            if success {
                return(input, 0x20)
            }
        }
        revert("Wrong pairing");
    }

    function run24(uint256[24] memory input) public view returns (bool) {
        for (uint i = 0; i < 24; i++) {
            console.log("", input[i]);
        }
        assembly {
            let success := staticcall(gas(), 0x08, input, 0x300, input, 0x20)
            if success {
                return(input, 0x20)
            }
        }
        revert("Wrong pairing");
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
                logG1Point(p1[i]);
                logG2Point(p2[i]);
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

        function logG1Point(G1Point memory p) pure public {
            console.log("Point.x:", p.x);
            console.log("Point.y:", p.y);
        }

        function logG2Point(G2Point memory p) pure public {
            console.log("Point.x_1:", p.x[0]);
            console.log("Point.y_1:", p.y[0]);

            console.log("Point.x_2:", p.x[1]);
            console.log("Point.y_2:", p.y[1]);
        }
}

