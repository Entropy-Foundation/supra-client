use std::convert::TryInto;

use structopt::StructOpt;
use supra_cli::PeerIdHex;

#[derive(Debug, StructOpt)]
pub struct Cli {
    #[structopt(subcommand)]
    pub subcommand: Option<Subcommand>,

    #[structopt(flatten)]
    pub run: RunCmd,
}

#[derive(Debug, StructOpt)]
pub struct RunCmd {
    #[structopt(flatten)]
    pub base: sc_cli::RunCmd,

    /// Provides Hex version of PeerId as base58.
    #[structopt(name = "supra", about = "Converting Peer Id to Hex")]
    pub supra: PeerIdHex,

    /// sr25519 public key
    #[structopt(long, parse(try_from_str = parse_public_key))]
    pub sr25519_pub_key: Option<sp_core::sr25519::Public>,

}

fn parse_public_key(i: &str) -> Result<sp_core::sr25519::Public, String> {
    hex::decode(i)
        .map_err(|e| e.to_string())?
        .as_slice()
        .try_into()
        .or(Err("Invalid lenght".to_string()))
}

#[derive(Debug, StructOpt)]
pub enum Subcommand {
    /// Key management cli utilities
    Key(sc_cli::KeySubcommand),

    /// Build a chain specification.
    BuildSpec(sc_cli::BuildSpecCmd),

    /// Validate blocks.
    CheckBlock(sc_cli::CheckBlockCmd),

    /// Export blocks.
    ExportBlocks(sc_cli::ExportBlocksCmd),

    /// Export the state of a given block into a chain spec.
    ExportState(sc_cli::ExportStateCmd),

    /// Import blocks.
    ImportBlocks(sc_cli::ImportBlocksCmd),

    /// Remove the whole chain.
    PurgeChain(sc_cli::PurgeChainCmd),

    /// Revert the chain to a previous state.
    Revert(sc_cli::RevertCmd),

    /// The custom benchmark subcommmand benchmarking runtime pallets.
    #[structopt(name = "benchmark", about = "Benchmark runtime pallets.")]
    Benchmark(frame_benchmarking_cli::BenchmarkCmd),

    /// Supra CLI
    #[structopt(flatten)]
    SupraCli(supra_cli::PeerIdHex)
}
