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
  'lookup_ffh_forest_type',
  'lookup_forest_community',
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
  'lookup_stand_development_phase',
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
  'lookup_trees_less_4meter_layer',
  'lookup_trees_less_4meter_mirrored',
  'lookup_trees_less_4meter_origin',
  'lookup_usage_type',
  'lookup_natur_schutzgebiet',
  'lookup_vogel_schutzgebiet',
  'lookup_natur_park',
  'lookup_national_park',
  'lookup_ffh',
  'lookup_biosphaere',
  'lookup_biogeographische_region',
  'lookup_basal_area_factor',
  'lookup_biotope',
  'lookup_harvest_restriction',
  'lookup_accessibility',
];

const lookupTemplate = [Column.text('name_de'), Column.text('name_en'), Column.text('interval'), Column.integer('sort'), Column.text('code')];

Schema schema = Schema(([
  const Table.localOnly('device_settings', [Column.text('key'), Column.text('value')]),
  const Table.localOnly('user_settings', [Column.text('value'), Column.text('key'), Column.text('user_id')]),

  const Table.localOnly('settings', [Column.text('sortGeneral'), Column.text('user_id'), Column.text('language')]),
  const Table.localOnly('plot_nested_json', [Column.text('cluster_id'), Column.text('plot'), Column.text('tree'), Column.text('deadwood')]),
  const Table('users_profile', [Column.integer('can_admin_troop'), Column.integer('is_organization_admin'), Column.integer('is_admin'), Column.integer('state_responsible'), Column.text('organization_id'), Column.text('email')]),
  const Table('schemas', [
    Column.text('created_at'),
    Column.text('interval_name'),
    Column.integer('is_visible'),
    Column.text('title'),
    Column.text('description'),
    Column.text('bucket_schema_file_name'),
    Column.text('bucket_plausability_file_name'),
    Column.text('schema'),
  ]),
  const Table('records', [
    Column.text('properties'),
    Column.text('schema_name'),
    Column.text('schema_id'),
    Column.text('plot_id'),
    Column.text('troop_id'),
    Column.text('previous_properties'),
    Column.text('organization_id'),
    Column.integer('is_valid'),
  ]),

  const Table('records_test', [Column.text('plot_id'), Column.text('created_at')]),

  const Table('cluster', [
    Column.text('intkey'),
    Column.text('cluster_name'),
    Column.text('state_responsible'),
    Column.text('topo_map_sheet'),
    Column.text('states_affected'),
    Column.text('grid_density'),
    Column.text('cluster_status'),
    Column.text('cluster_situation'),
    Column.text('inspire_grid_cell'),
  ]),
  const Table('organizations', [
    Column.text('apex_domain'),
    Column.text('created_at'),
    Column.text('created_by'),
    Column.text('name'),
    Column.integer('state_responsible'),
    Column.text('parent_organization_id'),
    Column.integer('can_admin_organization'),
    Column.integer('can_admin_troop'),
  ]),
  const Table('troop', [Column.text('plot_ids'), Column.text('name'), Column.text('supervisor_id'), Column.text('user_ids'), Column.text('organization_id')]),
  const Table('plot', [Column.text('intkey'), Column.text('plot_name'), Column.text('cluster_id'), Column.text('center_location_json'), Column.text('created_at'), Column.text('modified_local')]),
  /*const Table('tree', [
    Column.text('intkey'),
    Column.text('plot_id'),
    Column.text('tree_number'),
    Column.text('azimuth'),
    Column.text('distance'),
    Column.text('tree_species'),
    Column.text('dbh'),
    Column.text('dbh_height'),
    Column.text('tree_status'),
    Column.text('tree_height'),
    Column.text('stem_crown'),
    Column.text('tree_height_azimuth'),
    Column.text('tree_height_distance'),
    Column.text('tree_age'),
  ]),
  const Table('deadwood', [
    Column.text('intkey'),
    Column.text('plot_id'),
    Column.text('created_at'),
    Column.text('modified_at'),
    Column.text('modified_by'),
  ]),*/
  ...listOfLookupTables.map((tableName) => Table(tableName, List.from(lookupTemplate))),
  AttachmentsQueueTable(attachmentsQueueTableName: defaultAttachmentsQueueTableName),
]));
