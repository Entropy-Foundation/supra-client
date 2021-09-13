use structopt::StructOpt;
use bs58::{decode, Alphabet};

#[derive(Debug, StructOpt)]
pub struct PeerIdHexCmd {
    /// Provides Hex version of PeerId as base58.
    #[structopt()]
    pub peer_id: String,
}

impl PeerIdHexCmd {
    pub fn convert_to_hex(&self) -> Result<(), sc_cli::Error> {
        println!("Converting Peer ID in base58 to hex");

        let decoded_peer_id = decode(&self.peer_id)
            .with_alphabet(Alphabet::BITCOIN)
            .into_vec()
            .unwrap();

        println!("Bytes: {:?}", decoded_peer_id);

        println!("Hex: {:?}", hex::encode(decoded_peer_id));

        Ok(())
    }
}