//! Service and ServiceFactory implementation. Specialized wrapper over substrate service.

use libp2p_kad::record::Key;
use node_template_runtime::debug::info;
use node_template_runtime::{self, opaque::Block, RuntimeApi};
use sc_client_api::{ExecutorProvider, RemoteBackend, blockchain::HeaderBackend};
use sp_consensus_aura::sr25519::AuthorityPair as AuraPair;
use sp_core::Decode;
use sc_executor::native_executor_instance;
use sc_finality_grandpa::SharedVoterState;
use sc_keystore::LocalKeystore;
use sp_inherents::{InherentDataProviders, ProvideInherentData};
use sc_service::{Configuration, TaskManager, error::Error as ServiceError};
use std::{path::PathBuf};
use std::sync::Arc;
use std::time::Duration;

pub use sc_executor::NativeExecutor;

// Our native executor instance.
native_executor_instance!(
	pub Executor,
	node_template_runtime::api::dispatch,
	node_template_runtime::native_version,
	frame_benchmarking::benchmarking::HostFunctions,
);

type FullClient = sc_service::TFullClient<Block, RuntimeApi, Executor>;
type FullBackend = sc_service::TFullBackend<Block>;
type FullSelectChain = sc_consensus::LongestChain<FullBackend, Block>;

// TO DO inherent data provider
pub const INHERENT_IDENTIFIER: sp_inherents::InherentIdentifier = *b"dhtdataM";

impl ProvideInherentData for DataMap {
    fn on_register(&self, _: &InherentDataProviders) -> Result<(), sp_inherents::Error> {
		Ok(())
	}

    fn inherent_identifier(&self) -> &'static sp_inherents::InherentIdentifier {
		// let key = format!("{:?}", self.key);
		//Todo: convert keys above to bytes array. 
		&INHERENT_IDENTIFIER
    }

    fn provide_inherent_data(&self, inherent_data: &mut sp_consensus::InherentData) -> Result<(), sp_inherents::Error> {
        // dht value: block
		// let mut data = InherentData::new();
		inherent_data.put_data(INHERENT_IDENTIFIER, &self.value)
		// todo!()
    }

    fn error_to_string(&self, error: &[u8]) -> Option<String> {
        sp_inherents::Error::decode(&mut &error[..]).map(|e| e.into_string()).ok()
    }
}

pub fn build_inherent_data_providers(key: String) -> Result<InherentDataProviders, ServiceError> {
	let providers = InherentDataProviders::new();

	let key_new= key.into_bytes();

	providers
		.register_provider(DataMap::new(key_new))
		.map_err(Into::into)
		.map_err(sp_consensus::error::Error::InherentData)?;

	Ok(providers)
}

pub fn new_partial(config: &Configuration) -> Result<sc_service::PartialComponents<
	FullClient, FullBackend, FullSelectChain,
	sp_consensus::DefaultImportQueue<Block, FullClient>,
	sc_transaction_pool::FullPool<Block, FullClient>,
	(
		sc_consensus_aura::AuraBlockImport<
			Block,
			FullClient,
			sc_finality_grandpa::GrandpaBlockImport<FullBackend, Block, FullClient, FullSelectChain>,
			AuraPair
		>,
		sc_finality_grandpa::LinkHalf<Block, FullClient, FullSelectChain>,
	)
>, ServiceError> {
	if config.keystore_remote.is_some() {
		return Err(ServiceError::Other(
			format!("Remote Keystores are not supported.")))
	}
	
	let (client, backend, keystore_container, task_manager) =
	sc_service::new_full_parts::<Block, RuntimeApi, Executor>(&config)?;
	let client = Arc::new(client);

	let key = format!("{}", client.info().finalized_number);
	
	let inherent_data_providers =  build_inherent_data_providers(key)?;
	
	let select_chain = sc_consensus::LongestChain::new(backend.clone());

	let transaction_pool = sc_transaction_pool::BasicPool::new_full(
		config.transaction_pool.clone(),
		config.role.is_authority().into(),
		config.prometheus_registry(),
		task_manager.spawn_handle(),
		client.clone(),
	);

	let (grandpa_block_import, grandpa_link) = sc_finality_grandpa::block_import(
		client.clone(),
		&(client.clone() as Arc<_>),
		select_chain.clone(),
	)?;

	let aura_block_import = sc_consensus_aura::AuraBlockImport::<_, _, _, AuraPair>::new(
		grandpa_block_import.clone(), client.clone(),
	);

	let import_queue = sc_consensus_aura::import_queue::<_, _, _, AuraPair, _, _>(
		sc_consensus_aura::slot_duration(&*client)?,
		aura_block_import.clone(),
		Some(Box::new(grandpa_block_import.clone())),
		client.clone(),
		inherent_data_providers.clone(),
		&task_manager.spawn_handle(),
		config.prometheus_registry(),
		sp_consensus::CanAuthorWithNativeVersion::new(client.executor().clone()),
	)?;

	Ok(sc_service::PartialComponents {
		client,
		backend,
		task_manager,
		import_queue,
		keystore_container,
		select_chain,
		transaction_pool,
		inherent_data_providers,
		other: (aura_block_import, grandpa_link),
	})
}

fn remote_keystore(_url: &String) -> Result<Arc<LocalKeystore>, &'static str> {
	// FIXME: here would the concrete keystore be built,
	//        must return a concrete type (NOT `LocalKeystore`) that
	//        implements `CryptoStore` and `SyncCryptoStore`
	Err("Remote Keystore not supported.")
}

/// Supra data structure to be saved in the DHT. 
#[derive(Debug, Eq, PartialEq)]
struct DataMap {
	/// The (opaque) key of a record. 
	/// It is derived from the blockchain info's(Info<Block>) finalized_number 
	key: Key, 
	/// Our value is the best(latest) block hashed parsed to bytes
	value: Vec<u8>,
}

impl DataMap {
	pub fn new(key: Vec<u8>) -> Self {
		let key = Key::from(key);
		Self {
			key,
			value: Default::default()
		}
	}
}

#[derive(Debug, Clone)]
struct DhtLocalStorage {
	path: PathBuf,
	// password: String
}

/// Builds a new service for a full client.
pub fn new_full(mut config: Configuration) -> Result<TaskManager, ServiceError> {
	let sc_service::PartialComponents {
		client,
		backend,
		mut task_manager,
		import_queue,
		mut keystore_container,
		select_chain,
		transaction_pool,
		inherent_data_providers,
		other: (block_import, grandpa_link),
	} = new_partial(&config)?;

	if let Some(url) = &config.keystore_remote {
		match remote_keystore(url) {
			Ok(k) => keystore_container.set_remote_keystore(k),
			Err(e) => {
				return Err(ServiceError::Other(
					format!("Error hooking up remote keystore for {}: {}", url, e)))
			}
		};
	}

	config.network.extra_sets.push(sc_finality_grandpa::grandpa_peers_set_config());

	let (network, network_status_sinks, system_rpc_tx, network_starter) =
		sc_service::build_network(sc_service::BuildNetworkParams {
			config: &config,
			client: client.clone(),
			transaction_pool: transaction_pool.clone(),
			spawn_handle: task_manager.spawn_handle(),
			import_queue,
			on_demand: None,
			block_announce_validator_builder: None,
		})?;

	if config.offchain_worker.enabled {
		sc_service::build_offchain_workers(
			&config, backend.clone(), task_manager.spawn_handle(), client.clone(), network.clone(),
		);
	}

	config.network.enable_dht_random_walk = true;
	
	// Current best block at initialization, to report to the RPC layer.
	let last_hash = client.info().finalized_hash;
	let block_collected = format!("{}", last_hash.clone());
	info!("Current block saved to peer DHT {:?}", block_collected);
	
	//define batch key as_bytes
	let current_block_number: u32 = client.info().finalized_number;
	
	let parsed_block_number = format!("{}", current_block_number.clone());
	
	info!("DHT record key {:?}", &parsed_block_number);
	let key = Key::from(parsed_block_number.as_bytes().to_vec());
	
	let data = DataMap {
		key,
		value: block_collected.as_bytes().to_vec()
	};
	
	// parse data into dht 
	network.put_value(data.key.clone(), data.value);
	
	network.get_value(&data.key.clone());
	
	//event 50663.
	
	let role = config.role.clone();
	let force_authoring = config.force_authoring;
	let backoff_authoring_blocks: Option<()> = None;
	let name = config.network.node_name.clone();
	let enable_grandpa = !config.disable_grandpa;
	let prometheus_registry = config.prometheus_registry().cloned();

	let rpc_extensions_builder = {
		let client = client.clone();
		let pool = transaction_pool.clone();

		Box::new(move |deny_unsafe, _| {
			let deps = crate::rpc::FullDeps {
				client: client.clone(),
				pool: pool.clone(),
				deny_unsafe,
			};

			crate::rpc::create_full(deps)
		})
	};

	let (_rpc_handlers, telemetry_connection_notifier) = sc_service::spawn_tasks(
		sc_service::SpawnTasksParams {
			network: network.clone(),
			client: client.clone(),
			keystore: keystore_container.sync_keystore(),
			task_manager: &mut task_manager,
			transaction_pool: transaction_pool.clone(),
			rpc_extensions_builder,
			on_demand: None,
			remote_blockchain: None,
			backend,
			network_status_sinks,
			system_rpc_tx,
			config,
		},
	)?;

	if role.is_authority() {
		let proposer_factory = sc_basic_authorship::ProposerFactory::new(
			task_manager.spawn_handle(),
			client.clone(),
			transaction_pool,
			prometheus_registry.as_ref(),
		);

		let can_author_with =
			sp_consensus::CanAuthorWithNativeVersion::new(client.executor().clone());

		let aura = sc_consensus_aura::start_aura::<_, _, _, _, _, AuraPair, _, _, _,_>(
			sc_consensus_aura::slot_duration(&*client)?,
			client.clone(),
			select_chain,
			block_import,
			proposer_factory,
			network.clone(),
			inherent_data_providers.clone(),
			force_authoring,
			backoff_authoring_blocks,
			keystore_container.sync_keystore(),
			can_author_with,
		)?;

		// the AURA authoring task is considered essential, i.e. if it
		// fails we take down the service with it.
		task_manager.spawn_essential_handle().spawn_blocking("aura", aura);
	}

	// if the node isn't actively participating in consensus then it doesn't
	// need a keystore, regardless of which protocol we use below.
	let keystore = if role.is_authority() {
		Some(keystore_container.sync_keystore())
	} else {
		None
	};

	let grandpa_config = sc_finality_grandpa::Config {
		// FIXME #1578 make this available through chainspec
		gossip_duration: Duration::from_millis(333),
		justification_period: 512,
		name: Some(name),
		observer_enabled: false,
		keystore,
		is_authority: role.is_network_authority(),
	};

	if enable_grandpa {
		// start the full GRANDPA voter
		// NOTE: non-authorities could run the GRANDPA observer protocol, but at
		// this point the full voter should provide better guarantees of block
		// and vote data availability than the observer. The observer has not
		// been tested extensively yet and having most nodes in a network run it
		// could lead to finality stalls.
		let grandpa_config = sc_finality_grandpa::GrandpaParams {
			config: grandpa_config,
			link: grandpa_link,
			network,
			voting_rule: sc_finality_grandpa::VotingRulesBuilder::default().build(),
			prometheus_registry,
			shared_voter_state: SharedVoterState::empty(),
			telemetry_on_connect: telemetry_connection_notifier.map(|x| x.on_connect_stream()),
		};

		// the GRANDPA voter task is considered infallible, i.e.
		// if it fails we take down the service with it.
		task_manager.spawn_essential_handle().spawn_blocking(
			"grandpa-voter",
			sc_finality_grandpa::run_grandpa_voter(grandpa_config)?
		);
	}

	network_starter.start_network();
	Ok(task_manager)
}

/// Builds a new service for a light client.
pub fn new_light(mut config: Configuration) -> Result<TaskManager, ServiceError> {
	let (client, backend, keystore_container, mut task_manager, on_demand) =
		sc_service::new_light_parts::<Block, RuntimeApi, Executor>(&config)?;

	config.network.extra_sets.push(sc_finality_grandpa::grandpa_peers_set_config());

	let select_chain = sc_consensus::LongestChain::new(backend.clone());

	let transaction_pool = Arc::new(sc_transaction_pool::BasicPool::new_light(
		config.transaction_pool.clone(),
		config.prometheus_registry(),
		task_manager.spawn_handle(),
		client.clone(),
		on_demand.clone(),
	));

	let (grandpa_block_import, _) = sc_finality_grandpa::block_import(
		client.clone(),
		&(client.clone() as Arc<_>),
		select_chain.clone(),
	)?;

	let aura_block_import = sc_consensus_aura::AuraBlockImport::<_, _, _, AuraPair>::new(
		grandpa_block_import.clone(),
		client.clone(),
	);

	let import_queue = sc_consensus_aura::import_queue::<_, _, _, AuraPair, _, _>(
		sc_consensus_aura::slot_duration(&*client)?,
		aura_block_import,
		Some(Box::new(grandpa_block_import)),
		client.clone(),
		InherentDataProviders::new(),
		&task_manager.spawn_handle(),
		config.prometheus_registry(),
		sp_consensus::NeverCanAuthor,
	)?;

	let (network, network_status_sinks, system_rpc_tx, network_starter) =
		sc_service::build_network(sc_service::BuildNetworkParams {
			config: &config,
			client: client.clone(),
			transaction_pool: transaction_pool.clone(),
			spawn_handle: task_manager.spawn_handle(),
			import_queue,
			on_demand: Some(on_demand.clone()),
			block_announce_validator_builder: None,
		})?;

	if config.offchain_worker.enabled {
		#[cfg(feature = "light-client")]
		{
			sp_keystore::SyncCryptoStore::sr25519_generate_new(
				&*keystore,
				runtime::client::KEY_TYPE,
				Some("//Alice"),
			)
			.expect("Creating key with account Alice should succeed.");
		}

		sc_service::build_offchain_workers(
			&config, backend.clone(), task_manager.spawn_handle(), client.clone(), network.clone(),
		);
	}

	sc_service::spawn_tasks(sc_service::SpawnTasksParams {
		remote_blockchain: Some(backend.remote_blockchain()),
		transaction_pool,
		task_manager: &mut task_manager,
		on_demand: Some(on_demand),
		rpc_extensions_builder: Box::new(|_, _| ()),
		config,
		client,
		keystore: keystore_container.sync_keystore(),
		backend,
		network,
		network_status_sinks,
		system_rpc_tx,
	})?;

	network_starter.start_network();

	Ok(task_manager)
}

