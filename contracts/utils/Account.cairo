%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import call_contract, get_caller_address, get_tx_signature
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single
)

## @title Account
## @description A stripped down Account adapted from OpenZeppelin's [Account.cairo](https://github.com/OpenZeppelin/cairo-contracts/blob/main/contracts/Account.cairo).
## @author Alucard <github.com/a5f9t4>

#############################################
##                 STORAGE                 ##
#############################################

struct Message:
    member sender: felt
    member to: felt
    member selector: felt
    member calldata: felt*
    member calldata_size: felt
    member nonce: felt
end

@storage_var
func current_nonce() -> (res: felt):
end

@storage_var
func public_key() -> (res: felt):
end

#############################################
##               CONSTRUCTOR               ##
#############################################

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(_public_key: felt):
    public_key.write(_public_key)
    return()
end

#############################################
##                MODIFIERS                ##
#############################################

@view
func assert_only_self{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}():
    let (self) = get_contract_address()
    let (caller) = get_caller_address()
    assert self = caller
    return ()
end

#############################################
##                ACCESSORS                ##
#############################################

@view
func get_public_key{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (res: felt):
    let (res) = public_key.read()
    return (res=res)
end

@view
func get_nonce{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (res: felt):
    let (res) = current_nonce.read()
    return (res=res)
end

#############################################
##                 MUTATORS                ##
#############################################

@external
func set_public_key{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(new_public_key: felt):
    assert_only_self()
    public_key.write(new_public_key)
    return ()
end

#############################################
##                  LOGIC                  ##
#############################################

@view
func is_valid_signature{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr: SignatureBuiltin*
}(
    hash: felt,
    signature_len: felt,
    signature: felt*
) -> ():
    let (_public_key) = public_key.read()

    # This interface expects a signature pointer and length to make
    # no assumption about signature validation schemes.
    # But this implementation does, and it expects a (sig_r, sig_s) pair.
    let sig_r = signature[0]
    let sig_s = signature[1]

    verify_ecdsa_signature(
        message=hash,
        public_key=_public_key,
        signature_r=sig_r,
        signature_s=sig_s)

    return ()
end

@external
func execute{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr: SignatureBuiltin*
}(
    to: felt,
    selector: felt,
    calldata_len: felt,
    calldata: felt*,
    nonce: felt
) -> (response_len: felt, response: felt*):
    alloc_locals

    let (__fp__, _) = get_fp_and_pc()
    let (_address) = get_contract_address()
    let (_current_nonce) = current_nonce.read()

    local message: Message = Message(
        _address,
        to,
        selector,
        calldata,
        calldata_size=calldata_len,
        _current_nonce
    )

    ## CHECKS ##
    let (hash) = hash_message(&message)
    let (signature_len, signature) = get_tx_signature()
    is_valid_signature(hash, signature_len, signature)

    ## EFFECTS ##
    current_nonce.write(_current_nonce + 1)

    ## INTERACTIONS ##
    let response = call_contract(
        contract_address=message.to,
        function_selector=message.selector,
        calldata_size=message.calldata_size,
        calldata=message.calldata
    )

    return (response_len=response.retdata_size, response=response.retdata)
end

func hash_message{
    pedersen_ptr: HashBuiltin*
}(
    message: Message*
) -> (res: felt):
    alloc_locals
    # we need to make `res_calldata` local
    # to prevent the reference from being revoked
    let (local res_calldata) = hash_calldata(message.calldata, message.calldata_size)
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        # first three iterations are 'sender', 'to', and 'selector'
        let (hash_state_ptr) = hash_update(
            hash_state_ptr,
            message,
            3
        )
        let (hash_state_ptr) = hash_update_single(
            hash_state_ptr, res_calldata)
        let (hash_state_ptr) = hash_update_single(
            hash_state_ptr, message.nonce)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func hash_calldata{
    pedersen_ptr: HashBuiltin*
}(
    calldata: felt*,
    calldata_size: felt
) -> (res: felt):
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update(
            hash_state_ptr,
            calldata,
            calldata_size
        )
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end