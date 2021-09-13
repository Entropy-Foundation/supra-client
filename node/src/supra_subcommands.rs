use structopt::StructOpt;
use bs58::{decode, Alphabet};
use hex;
use libp2p_core::{identity::{ed25519,PublicKey}};

#[derive(Debug, StructOpt)]
pub struct SecretKeyHexCmd {
    /// Provides Hex version of PeerId as base58.
    #[structopt()]
    pub secret_key: String,
}

impl SecretKeyHexCmd {
    pub fn convert_to_peer_vec(&self) -> Result<(), sc_cli::Error> {
        let bytes = hex::decode(&self.secret_key).unwrap();
        let secret = ed25519::SecretKey::from_bytes(bytes).unwrap();
        let keypair = ed25519::Keypair::from(secret);
        let node_secret = hex::encode(keypair.secret().as_ref());
        let peer_id = PublicKey::Ed25519(keypair.public()).into_peer_id();
        let vec_of_peer = bs58::decode(peer_id.to_base58()).into_vec().unwrap();

        println!("PeerId: {:?}", peer_id);
        println!("Node Key: {:?}", node_secret);
        println!("PeerId Vector:{:?}",&vec_of_peer);
        println!("peerId Hex:{:?}", hex::encode(&vec_of_peer));

        Ok(())
    }
}