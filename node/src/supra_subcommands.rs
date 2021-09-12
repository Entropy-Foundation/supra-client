use bs58::{decode, Alphabet};
use libp2p_core::PeerId;
use std::str::FromStr;
use structopt::StructOpt;

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

#[derive(Debug, StructOpt)]
pub struct GeneratePeerIdCmd {
    /// Generates PeerID from Public Key.
    #[structopt()]
    pub node_key: String,
}

impl GeneratePeerIdCmd {
    pub fn gen_peer_id(&self) -> Result<(), sc_cli::Error> {
        let key = &self.node_key;
        println!("Generating PeerID...");

        
        let bytes = bs58::decode(&key.clone()).into_vec().unwrap();
        println!("{:?}", bytes);

        let hex = hex::encode(bytes);
        println!("{}", hex);
        // // let public_key = 
        // let keypair = Keypair::from_protobuf_encoding(key.as_bytes()).unwrap();
        // // println!("{:?}", keypair);

        let peer_id = PeerId::from_str(&hex).unwrap();
        println!("{:?}", peer_id);
        Ok(())
    }
}