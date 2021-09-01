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
    pub peer_id_hex: PeerIdHex,
}

#[derive(Debug, StructOpt)]
pub struct PeerIdHex {
    /// Provides Hex version of PeerId as base58.
    #[structopt(long = "decode-peer-id", value_name = "PEERID")]
    pub peer_id: String,

    #[allow(missing_docs)]
	#[structopt(flatten)]
	pub shared_params: SharedParams,
}

impl PeerIdHex {
    pub fn convert_to_hex(&self) -> Result<(), sc_cli::Error> {
        let decoded_peer_id = decode(&self.peer_id)
            .with_alphabet(Alphabet::BITCOIN)
            .into_vec()
            .unwrap();

        println!("{:?}", decoded_peer_id.clone());

        let peer_id_hex = hex::encode(decoded_peer_id);

        println!("{:?}", peer_id_hex);

        Ok(())
    }
}

impl CliConfiguration for PeerIdHex {
    fn shared_params(&self) -> &sc_cli::SharedParams {
        &self.shared_params
    }
}

impl FromStr for PeerIdHex {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        todo!()
    }
}