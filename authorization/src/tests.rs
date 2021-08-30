use super::*;
use crate as pallet_node_authorization;

use frame_support::{assert_ok, assert_noop, parameter_types, ord_parameter_types};
use frame_system::EnsureSignedBy;
use sp_core::H256;
use sp_runtime::{traits::{BlakeTwo256, IdentityLookup, BadOrigin}, testing::Header};

type UncheckedExtrinsic = frame_system::mocking::MockUncheckedExtrinsic<Test>;
type Block = frame_system::mocking::MockBlock<Test>;

frame_support::construct_runtime!(
    pub enum Test where
        Block = Block,
        NodeBlock = Block,
        UncheckedExtrinsic = UncheckedExtrinsic,
    {
        System: frame_system::{Module, Call, Config, Storage, Event<T>},
        NodeAuthorization: pallet_node_authorization::{
            Module, Call, Storage, Config<T>, Event<T>,
        },
    }
);

parameter_types! {
    pub const BlockHashCount: u64 = 250;
}
impl frame_system::Config for Test {
    type BaseCallFilter = ();
    type DbWeight = ();
    type BlockWeights = ();
    type BlockLength = ();
    type Origin = Origin;
    type Index = u64;
    type BlockNumber = u64;
    type Hash = H256;
    type Call = Call;
    type Hashing = BlakeTwo256;
    type AccountId = u64;
    type Lookup = IdentityLookup<Self::AccountId>;
    type Header = Header;
    type Event = Event;
    type BlockHashCount = BlockHashCount;
    type Version = ();
    type PalletInfo = PalletInfo;
    type AccountData = ();
    type OnNewAccount = ();
    type OnKilledAccount = ();
    type SystemWeightInfo = ();
    type SS58Prefix = ();
}

ord_parameter_types! {
    pub const One: u64 = 1;
    pub const Two: u64 = 2;
    pub const Three: u64 = 3;
    pub const Four: u64 = 4;
}
parameter_types! {
    pub const MaxWellKnownNodes: u32 = 4;
    pub const MaxPeerIdLength: u32 = 2;
}
impl Config for Test {
    type Event = Event;
    type MaxWellKnownNodes = MaxWellKnownNodes;
    type MaxPeerIdLength = MaxPeerIdLength;
    type AddOrigin = EnsureSignedBy<One, u64>;
    type RemoveOrigin = EnsureSignedBy<Two, u64>;
    type SwapOrigin = EnsureSignedBy<Three, u64>;
    type ResetOrigin = EnsureSignedBy<Four, u64>;
    type WeightInfo = ();
}

fn test_node(id: u8) -> PeerId {
    PeerId(vec![id])
}

fn new_test_ext() -> sp_io::TestExternalities {
    let mut t = frame_system::GenesisConfig::default().build_storage::<Test>().unwrap();
    pallet_node_authorization::GenesisConfig::<Test> {
        nodes: vec![(test_node(10), 10), (test_node(20), 20), (test_node(30), 30)],
    }.assimilate_storage(&mut t).unwrap();
    t.into()
}

#[test]
fn add_well_known_node_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::add_well_known_node(Origin::signed(2), test_node(15), 15),
            BadOrigin
        );
        assert_noop!(
            NodeAuthorization::add_well_known_node(Origin::signed(1), PeerId(vec![1, 2, 3]), 15),
            Error::<Test>::PeerIdTooLong
        );
        assert_noop!(
            NodeAuthorization::add_well_known_node(Origin::signed(1), test_node(20), 20),
            Error::<Test>::AlreadyJoined
        );

        assert_ok!(
            NodeAuthorization::add_well_known_node(Origin::signed(1), test_node(15), 15)
        );
        assert_eq!(
            WellKnownNodes::get(),
            BTreeSet::from_iter(vec![test_node(10), test_node(15), test_node(20), test_node(30)])
        );
        assert_eq!(Owners::<Test>::get(test_node(10)), 10);
        assert_eq!(Owners::<Test>::get(test_node(20)), 20);
        assert_eq!(Owners::<Test>::get(test_node(30)), 30);
        assert_eq!(Owners::<Test>::get(test_node(15)), 15);

        assert_noop!(
            NodeAuthorization::add_well_known_node(Origin::signed(1), test_node(25), 25),
            Error::<Test>::TooManyNodes
        );
    });
}

#[test]
fn remove_well_known_node_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::remove_well_known_node(Origin::signed(3), test_node(20)),
            BadOrigin
        );
        assert_noop!(
            NodeAuthorization::remove_well_known_node(Origin::signed(2), PeerId(vec![1, 2, 3])),
            Error::<Test>::PeerIdTooLong
        );
        assert_noop!(
            NodeAuthorization::remove_well_known_node(Origin::signed(2), test_node(40)),
            Error::<Test>::NotExist
        );

        AdditionalConnections::insert(
            test_node(20),
            BTreeSet::from_iter(vec![test_node(40)])
        );
        assert!(AdditionalConnections::contains_key(test_node(20)));

        assert_ok!(
            NodeAuthorization::remove_well_known_node(Origin::signed(2), test_node(20))
        );
        assert_eq!(
            WellKnownNodes::get(),
            BTreeSet::from_iter(vec![test_node(10), test_node(30)])
        );
        assert!(!Owners::<Test>::contains_key(test_node(20)));
        assert!(!AdditionalConnections::contains_key(test_node(20)));
    });
}

#[test]
fn swap_well_known_node_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::swap_well_known_node(
                Origin::signed(4), test_node(20), test_node(5)
            ),
            BadOrigin
        );
        assert_noop!(
            NodeAuthorization::swap_well_known_node(
                Origin::signed(3), PeerId(vec![1, 2, 3]), test_node(20)
            ),
            Error::<Test>::PeerIdTooLong
        );
        assert_noop!(
            NodeAuthorization::swap_well_known_node(
                Origin::signed(3), test_node(20), PeerId(vec![1, 2, 3])
            ),
            Error::<Test>::PeerIdTooLong
        );

        assert_ok!(
            NodeAuthorization::swap_well_known_node(
                Origin::signed(3), test_node(20), test_node(20)
            )
        );
        assert_eq!(
            WellKnownNodes::get(),
            BTreeSet::from_iter(vec![test_node(10), test_node(20), test_node(30)])
        );

        assert_noop!(
            NodeAuthorization::swap_well_known_node(
                Origin::signed(3), test_node(15), test_node(5)
            ),
            Error::<Test>::NotExist
        );
        assert_noop!(
            NodeAuthorization::swap_well_known_node(
                Origin::signed(3), test_node(20), test_node(30)
            ),
            Error::<Test>::AlreadyJoined
        );

        AdditionalConnections::insert(
            test_node(20),
            BTreeSet::from_iter(vec![test_node(15)])
        );
        assert_ok!(
            NodeAuthorization::swap_well_known_node(
                Origin::signed(3), test_node(20), test_node(5)
            )
        );
        assert_eq!(
            WellKnownNodes::get(),
            BTreeSet::from_iter(vec![test_node(5), test_node(10), test_node(30)])
        );
        assert!(!Owners::<Test>::contains_key(test_node(20)));
        assert_eq!(Owners::<Test>::get(test_node(5)), 20);
        assert!(!AdditionalConnections::contains_key(test_node(20)));
        assert_eq!(
            AdditionalConnections::get(test_node(5)),
            BTreeSet::from_iter(vec![test_node(15)])
        );
    });
}

#[test]
fn reset_well_known_nodes_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::reset_well_known_nodes(
                Origin::signed(3),
                vec![(test_node(15), 15), (test_node(5), 5), (test_node(20), 20)]
            ),
            BadOrigin
        );
        assert_noop!(
            NodeAuthorization::reset_well_known_nodes(
                Origin::signed(4),
                vec![
                    (test_node(15), 15),
                    (test_node(5), 5),
                    (test_node(20), 20),
                    (test_node(25), 25),
                ]
            ),
            Error::<Test>::TooManyNodes
        );

        assert_ok!(
            NodeAuthorization::reset_well_known_nodes(
                Origin::signed(4),
                vec![(test_node(15), 15), (test_node(5), 5), (test_node(20), 20)]
            )
        );
        assert_eq!(
            WellKnownNodes::get(),
            BTreeSet::from_iter(vec![test_node(5), test_node(15), test_node(20)])
        );
        assert_eq!(Owners::<Test>::get(test_node(5)), 5);
        assert_eq!(Owners::<Test>::get(test_node(15)), 15);
        assert_eq!(Owners::<Test>::get(test_node(20)), 20);
    });
}

#[test]
fn claim_node_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::claim_node(Origin::signed(1), PeerId(vec![1, 2, 3])),
            Error::<Test>::PeerIdTooLong
        );
        assert_noop!(
            NodeAuthorization::claim_node(Origin::signed(1), test_node(20)),
            Error::<Test>::AlreadyClaimed
        );

        assert_ok!(NodeAuthorization::claim_node(Origin::signed(15), test_node(15)));
        assert_eq!(Owners::<Test>::get(test_node(15)), 15);
    });
}

#[test]
fn remove_claim_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::remove_claim(Origin::signed(15), PeerId(vec![1, 2, 3])),
            Error::<Test>::PeerIdTooLong
        );
        assert_noop!(
            NodeAuthorization::remove_claim(Origin::signed(15), test_node(15)),
            Error::<Test>::NotClaimed
        );

        assert_noop!(
            NodeAuthorization::remove_claim(Origin::signed(15), test_node(20)),
            Error::<Test>::NotOwner
        );

        assert_noop!(
            NodeAuthorization::remove_claim(Origin::signed(20), test_node(20)),
            Error::<Test>::PermissionDenied
        );

        Owners::<Test>::insert(test_node(15), 15);
        AdditionalConnections::insert(
            test_node(15),
            BTreeSet::from_iter(vec![test_node(20)])
        );
        assert_ok!(NodeAuthorization::remove_claim(Origin::signed(15), test_node(15)));
        assert!(!Owners::<Test>::contains_key(test_node(15)));
        assert!(!AdditionalConnections::contains_key(test_node(15)));
    });
}

#[test]
fn transfer_node_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::transfer_node(Origin::signed(15), PeerId(vec![1, 2, 3]), 10),
            Error::<Test>::PeerIdTooLong
        );
        assert_noop!(
            NodeAuthorization::transfer_node(Origin::signed(15), test_node(15), 10),
            Error::<Test>::NotClaimed
        );

        assert_noop!(
            NodeAuthorization::transfer_node(Origin::signed(15), test_node(20), 10),
            Error::<Test>::NotOwner
        );

        assert_ok!(NodeAuthorization::transfer_node(Origin::signed(20), test_node(20), 15));
        assert_eq!(Owners::<Test>::get(test_node(20)), 15);
    });
}

#[test]
fn add_connections_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::add_connections(
                Origin::signed(15), PeerId(vec![1, 2, 3]), vec![test_node(5)]
            ),
            Error::<Test>::PeerIdTooLong
        );
        assert_noop!(
            NodeAuthorization::add_connections(
                Origin::signed(15), test_node(15), vec![test_node(5)]
            ),
            Error::<Test>::NotClaimed
        );

        assert_noop!(
            NodeAuthorization::add_connections(
                Origin::signed(15), test_node(20), vec![test_node(5)]
            ),
            Error::<Test>::NotOwner
        );

        assert_ok!(
            NodeAuthorization::add_connections(
                Origin::signed(20),
                test_node(20),
                vec![test_node(15), test_node(5), test_node(25), test_node(20)]
            )
        );
        assert_eq!(
            AdditionalConnections::get(test_node(20)),
            BTreeSet::from_iter(vec![test_node(5), test_node(15), test_node(25)])
        );
    });
}

#[test]
fn remove_connections_works() {
    new_test_ext().execute_with(|| {
        assert_noop!(
            NodeAuthorization::remove_connections(
                Origin::signed(15), PeerId(vec![1, 2, 3]), vec![test_node(5)]
            ),
            Error::<Test>::PeerIdTooLong
        );
        assert_noop!(
            NodeAuthorization::remove_connections(
                Origin::signed(15), test_node(15), vec![test_node(5)]
            ),
            Error::<Test>::NotClaimed
        );

        assert_noop!(
            NodeAuthorization::remove_connections(
                Origin::signed(15), test_node(20), vec![test_node(5)]
            ),
            Error::<Test>::NotOwner
        );

        AdditionalConnections::insert(
            test_node(20),
            BTreeSet::from_iter(vec![test_node(5), test_node(15), test_node(25)])
        );
        assert_ok!(
            NodeAuthorization::remove_connections(
                Origin::signed(20),
                test_node(20),
                vec![test_node(15), test_node(5)]
            )
        );
        assert_eq!(
            AdditionalConnections::get(test_node(20)),
            BTreeSet::from_iter(vec![test_node(25)])
        );
    });
}

#[test]
fn get_authorized_nodes_works() {
    new_test_ext().execute_with(|| {
        AdditionalConnections::insert(
            test_node(20),
            BTreeSet::from_iter(vec![test_node(5), test_node(15), test_node(25)])
        );

        let mut authorized_nodes = Module::<Test>::get_authorized_nodes(&test_node(20));
        authorized_nodes.sort();
        assert_eq!(
            authorized_nodes,
            vec![test_node(5), test_node(10), test_node(15), test_node(25), test_node(30)]
        );
    });
}