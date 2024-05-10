## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

```solidity
    // Might use later
    function IdentifyCollisionSide(int256 dx, int256 dy) internal view returns (Direction) {
        console.logInt(dx);
        console.logInt(dy);
        if (dx == 0 && dy == 0) {
            console.log("Reverting: No movement");
            revert("IdentifyCollisionSide: No movement");
        }

        console.logInt(dy);
        console.log("Wrapping dx, dy into complex number");
        Complex memory movement = wrap(sd(dx), sd(dy));
        console.log("Wrapped into complex number, converting to polar");
        (, SD59x18 angle) = toPolar(movement);
        console.logInt(angle.unwrap());
        
        int256 degrees = int256(angle.unwrap() * 180 / int256(PI.unwrap()));
        console.logInt(degrees);

        if (degrees >= -22 && degrees < 22) {
            console.log("Direction: Right");
            return Direction.Right;
        } else if (degrees >= 22 && degrees < 67) {
            console.log("Direction: UpRight");
            return Direction.UpRight;
        } else if (degrees >= 67 && degrees < 112) {
            console.log("Direction: Up");
            return Direction.Up;
        } else if (degrees >= 112 && degrees < 157) {
            console.log("Direction: UpLeft");
            return Direction.UpLeft;
        } else if ((degrees >= 157) || (degrees < -157)) {
            console.log("Direction: Left");
            return Direction.Left;
        } else if (degrees >= -157 && degrees < -112) {
            console.log("Direction: DownLeft");
            return Direction.DownLeft;
        } else if (degrees >= -112 && degrees < -67) {
            console.log("Direction: Down");
            return Direction.Down;
        } else if (degrees >= -67 && degrees < -22) {
            console.log("Direction: DownRight");
            return Direction.DownRight;
        } 

        console.log("Defaulting to Direction.Up");
        return Direction.Up; 
    }

    function IdentifyCollisionSideFallback(int256 dx, int256 dy) public pure returns (Direction) {
        if (dx == 0 && dy == 0) {
            return Direction.None; 
        }

        bool xPositive = dx > 0;
        bool yPositive = dy > 0;
        int256 absDx = abs(dx);
        int256 absDy = abs(dy);

        int256 ratio = (absDx - absDy) * 100 / (absDx + absDy);

        if (ratio > 50) return xPositive ? Direction.Right : Direction.Left;
        else if (ratio < -50) return yPositive ? Direction.Up : Direction.Down;
        else {
            if (xPositive && yPositive) return Direction.UpRight;
            if (!xPositive && yPositive) return Direction.UpLeft;
            if (xPositive && !yPositive) return Direction.DownRight;
            if (!xPositive && !yPositive) return Direction.DownLeft;
        }

        return Direction.None; 
    }
```