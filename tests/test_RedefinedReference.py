import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, uint, str_to_felt, MAX_UINT256

signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def ownable_factory():
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        "contracts/utils/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    rr = await starknet.deploy(
        "contracts/RedefinedReference.cairo",
        constructor_calldata=[
            str_to_felt("gm everybody, gm")
        ]
    )
    return starknet, rr, owner


@pytest.mark.asyncio
async def test_constructor(ownable_factory):
    _, rr, _ = ownable_factory
    expected = await rr.getRef().call()
    assert expected.result.ref == str_to_felt("gm everybody, gm")

@pytest.mark.asyncio
async def test_exploit(ownable_factory):
    _, rr, owner = ownable_factory
    await signer.send_transaction(owner, rr.contract_address, 'exploit', [])
