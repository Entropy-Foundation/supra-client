// use libp2p::PeerId;
pub use sc_cli::{CliConfiguration, SharedParams};
use structopt::StructOpt;
use bs58::{decode, Alphabet};
use std::str::FromStr;

#[derive(Debug, StructOpt)]
pub struct SupraCmd {
    #[allow(missing_docs)]
	#[structopt(flatten)]
	pub shared_params: SharedParams,

    #[allow(missing_docs)]
    #[structopt(flatten)]
    pub peer_id_hex: PeerIdHexCmd,
}

#[derive(Debug, StructOpt)]
pub struct PeerIdHexCmd {
    /// Provides Hex version of PeerId as base58.
    #[structopt()]
    pub peer_id: String,

    #[allow(missing_docs)]
	#[structopt(flatten)]
	pub shared_params: SharedParams,
}

impl PeerIdHexCmd {
    pub fn convert_to_hex(&self) -> Result<(), sc_cli::Error> {
        let decoded_peer_id = decode(&self.peer_id)
            .with_alphabet(Alphabet::BITCOIN)
            .into_vec()
            .unwrap();

        println!("Decoded PeerId in bytes: {:?}", decoded_peer_id.clone());

        let peer_id_hex = hex::encode(decoded_peer_id);

        println!("Decoded PeerId in hex: {:?}", peer_id_hex);

        Ok(())
    }
}

impl CliConfiguration for PeerIdHexCmd {
    fn shared_params(&self) -> &sc_cli::SharedParams {
        &self.shared_params
    }
}

impl FromStr for PeerIdHexCmd {
    type Err = String;

    fn from_str(_s: &str) -> Result<Self, Self::Err> {
        todo!()
    }
}