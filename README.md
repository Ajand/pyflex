# pyflex

Python API for GEB contracts.

<https://discord.gg/kB4vcYs>

## Introduction

The _GEB_  system incentivizes external agents, called _keepers_,
to automate certain operations around the Ethereum blockchain. In order to ease their
development, an API around most of the Reflexer contracts has been created. It can be used
not only by keepers, but may also be found useful by authors of some other, unrelated
utilities aiming to interact with these contracts.

Based on this API, a set of reference Reflexer keepers is being developed:
[auction-keeper](https://github.com/reflexer-labs/auction-keeper)

You only need to install this project directly if you want to build your own keepers,
or if you want to play with this API library itself. If you just want to install
one of reference keepers, go to one of the repositories linked above and start from there.
Each of these keepers references some version of `pyflex` via a Git submodule.

## Installation

This project uses *Python 3.6.6*.

In order to clone the project and install required third-party packages please execute:
```
git clone https://github.com/reflexer-labs/pyflex.git
cd pyflex
pip3 install -r requirements.txt
```

### Known Ubuntu issues

In order for the `secp256k` Python dependency to compile properly, following packages will need to be installed:
```
sudo apt-get install build-essential automake libtool pkg-config libffi-dev python-dev python-pip libsecp256k1-dev
```

(for Ubuntu 18.04 Server)

### Known macOS issues

In order for the Python requirements to install correctly on _macOS_, please install
`openssl`, `libtool`, `pkg-config` and `automake` using [Homebrew](https://brew.sh/):
```
brew install openssl libtool pkg-config automake
```

and set the `LDFLAGS` environment variable before you run `pip3 install -r requirements.txt`:
```
export LDFLAGS="-L$(brew --prefix openssl)/lib" CFLAGS="-I$(brew --prefix openssl)/include"
```

## Available APIs

The current version provides APIs around:
* `ERC20Token`,
* `SAFEEngine`, `LiquidationEngine`, `AccountingEngine`, `TaxCollector`, `CollateralAuctionHouse`, `PreSettlementSurplusAuctionHouse`, `PostSettlementSurplusAuctionHouse`, `DebtAuctionHouse` (<https://github.com/reflexer-labs/geb>)
* `TxManager` (<https://github.com/reflexer-labs/tx-manager>),
* `DSGuard` (<https://github.com/reflexer-labs/ds-guard>),
* `DSToken` (<https://github.com/reflexer-labs/ds-token>),
* `DSEthToken` (<https://github.com/dapphub/ds-eth-token>),
* `DSValue` (<https://github.com/reflexer-labs/ds-value>),
* `DSVault` (<https://github.com/dapphub/ds-vault>)
* `ZrxExchange`, `ZrxExchangeV2`

APIs around the following functionality have not been implemented:
* Coin Savings Account
* Global Settlement
* Governance (`DSAuth`, `VoteQuorum`, `DSGuard`, `Proposal`, `DSDelegateRoles`, `DSRoles`)

Contributions from the community are appreciated.

## Code samples

Below you can find some code snippets demonstrating how the API can be used both for developing
your own keepers and for creating some other utilities interacting with the _GEB_
ecosystem contracts.

### Updating a DSValue

This snippet demonstrates how to update a `DSValue` with the ETH/USD rate pulled from _CryptoCompare_:

```python
import json
import urllib.request

from web3 import HTTPProvider, Web3

from pyflex import Address
from pyflex.feed import DSValue
from pyflex.numeric import Wad


def cryptocompare_rate() -> Wad:
    with urllib.request.urlopen("https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD") as url:
        data = json.loads(url.read().decode())
        return Wad.from_number(data['USD'])


web3 = Web3(HTTPProvider(endpoint_uri="http://localhost:8545"))

dsvalue = DSValue(web3=web3, address=Address('0x038b3d8288df582d57db9be2106a27be796b0daf'))
dsvalue.update_result(cryptocompare_rate().value).transact()
```
### System Coin

This snippet demonstrates how to create a SAFE and draw system coins

```python
import sys
from web3 import Web3, HTTPProvider

from pyflex import Address
from pyflex.deployment import GfDeployment
from pyflex.keys import register_keys
from pyflex.numeric import Wad


web3 = Web3(HTTPProvider(endpoint_uri="https://localhost:8545",
                         request_kwargs={"timeout": 10}))
web3.eth.defaultAccount = sys.argv[1]   # ex: 0x0000000000000000000000000000000aBcdef123
register_keys(web3, [sys.argv[2]])      # ex: key_file=~keys/default-account.json,pass_file=~keys/default-account.pass

geb = GfDeployment.from_json(web3=web3, conf=open("tests/config/kovan-addresses.json", "r").read())
our_address = Address(web3.eth.defaultAccount)

# Choose the desired collateral; in this case we'll wrap some Eth
collateral = geb.collaterals['ETH-A']
collateral_type = collateral.collateral_type
collateral.collateral.deposit(Wad.from_number(3)).transact()

# Add collateral and allocate the desired amount of system coins
collateral.approve(our_address)
collateral.adapter.join(our_address, Wad.from_number(3)).transact()
geb.safe_engine.modify_safe_collateralization(collateralType, our_address, delta_collateral=Wad.from_number(3), delta_debt=Wad.from_number(153)).transact()
print(f"SAFE system coin balance before withdrawal: {geb.safe_engine.coin_balance(our_address)}")

# Mint and withdraw our system coin
geb.approve_system_coin(our_address)
geb.system_coin_adapter.exit(our_address, Wad.from_number(153)).transact()
print(f"SAFE system coin balance after withdrawal:  {geb.safe_engine.coin_balance(our_address)}")

# Repay (and burn) our system coins
assert geb.system_coin_adapter.join(our_address, Wad.from_number(153)).transact()
print(f"SAFE system balance after repayment:   {geb.safe_engine.coin_balance(our_address)}")

# Withdraw our collateral
geb.safe_engine.modify_safe_collateralization(collateralType, our_address, delta_collateral=Wad(0), delta_debt=Wad.from_number(-153)).transact()
geb.safe_engine.modify_safe_collateralization(collateralType, our_address, delta_collateral=Wad.from_number(-3), delta_debt=Wad(0)).transact()
collateral.adapter.exit(our_address, Wad.from_number(3)).transact()
print(f"SAFE system coin balance w/o collateral:    {geb.safe_engine.coin_balance(our_address)}")
```

## Testing

Prerequisites:
* [docker and docker-compose](https://www.docker.com/get-started)

This project uses [pytest](https://docs.pytest.org/en/latest/) for unit testing.  Testing of GEB is
performed on a Dockerized local testchain included in `tests\config`.

In order to be able to run tests, please install development dependencies first by executing:
```
pip3 install -r requirements-dev.txt
```

You can then run all tests with:
```
./test.sh
```

By default, `pyflex` will not send a transaction to the chain if gas estimation fails, because this means the
transaction would revert.  For testing purposes, it is sometimes useful to send bad transactions to the chain.  To
accomplish this, set class variable `gas_estimate_for_bad_txs` in your application.  For example:
```
from pyflex import Transact
Transact.gas_estimate_for_bad_txs = 200000
```

## License

See [COPYING](https://github.com/reflexer-labs/pyflex/blob/master/COPYING) file.
