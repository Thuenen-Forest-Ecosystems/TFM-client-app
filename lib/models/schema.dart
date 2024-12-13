import 'package:powersync/powersync.dart';
import 'package:powersync_attachments_helper/powersync_attachments_helper.dart';

const listOfLookupTables = [
  'lookup_browsing',
  'lookup_cluster_situation',
  'lookup_cluster_status',
  'lookup_dead_wood_type',
  'lookup_decomposition',
  'lookup_edge_status',
  'lookup_edge_type',
  'lookup_elevation_level',
  'lookup_exploration_instruction',
  'lookup_ffh_forest_type_field',
  'lookup_forest_community_field',
  'lookup_forest_office',
  'lookup_forest_status',
  'lookup_gnss_quality',
  'lookup_grid_density',
  'lookup_growth_district',
  'lookup_harvesting_method',
  'lookup_land_use',
  'lookup_management_type',
  'lookup_marker_profile',
  'lookup_marker_status',
  'lookup_property_size_class',
  'lookup_property_type',
  'lookup_pruning',
  'lookup_sampling_stratum',
  'lookup_stand_dev_phase',
  'lookup_stand_layer',
  'lookup_stand_structure',
  'lookup_state',
  'lookup_stem_breakage',
  'lookup_stem_form',
  'lookup_terrain',
  'lookup_terrain_form',
  'lookup_tree_size_class',
  'lookup_tree_species',
  'lookup_tree_species_group',
  'lookup_tree_status',
  'lookup_trees_less_4meter_count_factor',
  'lookup_trees_less_4meter_layer',
  'lookup_trees_less_4meter_mirrored',
  'lookup_trees_less_4meter_origin',
  'lookup_use_restriction',
];

const lookupTemplate = [
  Column.text('name_de'),
  Column.text('name_en'),
  Column.text('interval'),
  Column.integer('sort'),
  Column.text('abbreviation'),
];

Schema schema = Schema(([
  const Table.localOnly('settings', [
    Column.text('sortGeneral'),
    Column.text('user_id'),
  ]),
  const Table('users_profile', [
    Column.text('email'),
    Column.text('users_name'),
    Column.text('users_company'),
    Column.text('user_id'),
    Column.text('phone'),
    Column.integer('is_admin'),
  ]),
  const Table('schemas', [
    Column.text('interval_name'),
    Column.text('title'),
    Column.text('description'),
    Column.text('created_at'),
    Column.integer('is_visible'),
  ]),
  const Table('cluster', [
    Column.text('intkey'),
    Column.text('cluster_name'),
    Column.text('created_at'),
    Column.text('select_access_by'),
    Column.text('update_access_by'),
    Column.text('state_responsible'),
    Column.text('states_affected'),
  ]),
  const Table('plot', [
    Column.text('intkey'),
    Column.text('plot_name'),
    Column.text('cluster_id'),
    Column.text('center_location_json'),
    Column.text('created_at'),
    Column.text('modified_local'),
  ]),
  ...listOfLookupTables.map((tableName) => Table(tableName, List.from(lookupTemplate))),
  AttachmentsQueueTable(attachmentsQueueTableName: defaultAttachmentsQueueTableName),
]));