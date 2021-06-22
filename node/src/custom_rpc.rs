use jsonrpc_core::Result;
use jsonrpc_derive::rpc;

#[rpc]
pub trait CustomRpc {
	#[rpc(name = "get_block_details")]
	fn get_block_details(&self) -> Result<u64>;
}

pub struct Custom;

impl CustomRpc for Custom {
	fn get_block_details(&self) -> Result<u64> {
		Ok(7)
	}
}