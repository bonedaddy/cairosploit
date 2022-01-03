%lang starknet
%builtins pedersen range_check

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, assert_not_zero
from starkware.starknet.common.syscalls import storage_read, storage_write
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check
)

## @title RedefinedReference
## @description Exploiting redefined references
## @author Alucard <github.com/a5f9t4>

#############################################
##                METADATA                 ##
#############################################

@storage_var
func _reference() -> (ref: felt):
end

#############################################
##               CONSTRUCTOR               ##
#############################################

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    ref: felt
):
    _reference.write(ref)
    return ()
end

#############################################
##                 Exploit                 ##
#############################################

@view
func exploit{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (success: felt):
    alloc_locals
    let x = 5
    assert x = 10
    return (1)
end

#############################################
##                ACCESSORS                ##
#############################################

@view
func getRef{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (ref: felt):
    let (ref: felt) = _reference.read()
    return (ref)
end

#############################################
##                MUTATORS                 ##
#############################################

@external
func setRef{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    ref: felt
):
    _reference.write(ref)
    return ()
end
