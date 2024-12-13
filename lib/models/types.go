package database

import "database/sql"

type PrivateCi2027001LookupTemplateSelect struct {
	Interval []interface{} `json:"interval"`
	NameDe   string        `json:"name_de"`
	NameEn   string        `json:"name_en"`
	Sort     int32         `json:"sort"`
}

type PrivateCi2027001LookupTemplateInsert struct {
	Interval []interface{} `json:"interval"`
	NameDe   string        `json:"name_de"`
	NameEn   string        `json:"name_en"`
	Sort     int32         `json:"sort"`
}

type PrivateCi2027001LookupTemplateUpdate struct {
	Interval []interface{}  `json:"interval"`
	NameDe   sql.NullString `json:"name_de"`
	NameEn   sql.NullString `json:"name_en"`
	Sort     sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupBrowsingSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupBrowsingInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupBrowsingUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupClusterSituationSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupClusterSituationInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupClusterSituationUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupClusterStatusSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupClusterStatusInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupClusterStatusUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupDeadWoodTypeSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupDeadWoodTypeInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupDeadWoodTypeUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupDecompositionSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupDecompositionInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupDecompositionUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupEdgeStatusSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupEdgeStatusInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupEdgeStatusUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupEdgeTypeSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupEdgeTypeInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupEdgeTypeUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupElevationLevelSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupElevationLevelInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupElevationLevelUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupExplorationInstructionSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupExplorationInstructionInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupExplorationInstructionUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupFfhForestTypeFieldSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupFfhForestTypeFieldInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupFfhForestTypeFieldUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestCommunityFieldSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestCommunityFieldInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestCommunityFieldUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestOfficeSelect struct {
	Abbreviation int16          `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Phone        sql.NullString `json:"phone"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestOfficeInsert struct {
	Abbreviation int16          `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Phone        sql.NullString `json:"phone"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestOfficeUpdate struct {
	Abbreviation sql.NullInt32  `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Phone        sql.NullString `json:"phone"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestStatusSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestStatusInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupForestStatusUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGnssQualitySelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGnssQualityInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGnssQualityUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGridDensitySelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGridDensityInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGridDensityUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGrowthDistrictSelect struct {
	Abbreviation int16          `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGrowthDistrictInsert struct {
	Abbreviation int16          `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupGrowthDistrictUpdate struct {
	Abbreviation sql.NullInt32  `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupHarvestingMethodSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupHarvestingMethodInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupHarvestingMethodUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupLandUseSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupLandUseInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupLandUseUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupManagementTypeSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupManagementTypeInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupManagementTypeUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupMarkerProfileSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupMarkerProfileInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupMarkerProfileUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupMarkerStatusSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupMarkerStatusInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupMarkerStatusUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPropertySizeClassSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPropertySizeClassInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPropertySizeClassUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPropertyTypeSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPropertyTypeInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPropertyTypeUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPruningSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPruningInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupPruningUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupSamplingStratumSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupSamplingStratumInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupSamplingStratumUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandDevPhaseSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandDevPhaseInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandDevPhaseUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandLayerSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandLayerInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandLayerUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandStructureSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandStructureInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStandStructureUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStateSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStateInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStateUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStemBreakageSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStemBreakageInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStemBreakageUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStemFormSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStemFormInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupStemFormUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTerrainFormSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTerrainFormInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTerrainFormUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTerrainSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTerrainInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTerrainUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeSizeClassSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeSizeClassInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeSizeClassUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeSpeciesGroupSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeSpeciesGroupInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeSpeciesGroupUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeSpeciesSelect struct {
	Abbreviation  int16          `json:"abbreviation"`
	Id            string         `json:"id"`
	Interval      []interface{}  `json:"interval"`
	NameDe        sql.NullString `json:"name_de"`
	NameEn        sql.NullString `json:"name_en"`
	Sort          sql.NullInt32  `json:"sort"`
	TaxonomyOrder sql.NullString `json:"taxonomy_order"`
}

type PrivateCi2027001LookupTreeSpeciesInsert struct {
	Abbreviation  int16          `json:"abbreviation"`
	Id            sql.NullString `json:"id"`
	Interval      []interface{}  `json:"interval"`
	NameDe        sql.NullString `json:"name_de"`
	NameEn        sql.NullString `json:"name_en"`
	Sort          sql.NullInt32  `json:"sort"`
	TaxonomyOrder sql.NullString `json:"taxonomy_order"`
}

type PrivateCi2027001LookupTreeSpeciesUpdate struct {
	Abbreviation  sql.NullInt32  `json:"abbreviation"`
	Id            sql.NullString `json:"id"`
	Interval      []interface{}  `json:"interval"`
	NameDe        sql.NullString `json:"name_de"`
	NameEn        sql.NullString `json:"name_en"`
	Sort          sql.NullInt32  `json:"sort"`
	TaxonomyOrder sql.NullString `json:"taxonomy_order"`
}

type PrivateCi2027001LookupTreeStatusSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeStatusInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreeStatusUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterCountFactorSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterCountFactorInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterCountFactorUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterLayerSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterLayerInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterLayerUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterMirroredSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterMirroredInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterMirroredUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterOriginSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterOriginInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupTreesLess4meterOriginUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupUseRestrictionSelect struct {
	Abbreviation string         `json:"abbreviation"`
	Id           string         `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupUseRestrictionInsert struct {
	Abbreviation string         `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001LookupUseRestrictionUpdate struct {
	Abbreviation sql.NullString `json:"abbreviation"`
	Id           sql.NullString `json:"id"`
	Interval     []interface{}  `json:"interval"`
	NameDe       sql.NullString `json:"name_de"`
	NameEn       sql.NullString `json:"name_en"`
	Sort         sql.NullInt32  `json:"sort"`
}

type PrivateCi2027001ClusterSelect struct {
	ClusterName      int32          `json:"cluster_name"`
	ClusterSituation sql.NullString `json:"cluster_situation"`
	ClusterStatus    sql.NullString `json:"cluster_status"`
	CreatedAt        string         `json:"created_at"`
	GridDensity      string         `json:"grid_density"`
	Id               string         `json:"id"`
	Intkey           sql.NullString `json:"intkey"`
	ModifiedAt       sql.NullString `json:"modified_at"`
	ModifiedBy       string         `json:"modified_by"`
	SelectAccessBy   []string       `json:"select_access_by"`
	StateResponsible string         `json:"state_responsible"`
	StatesAffected   []interface{}  `json:"states_affected"`
	TopoMapSheet     sql.NullInt32  `json:"topo_map_sheet"`
	UpdateAccessBy   []string       `json:"update_access_by"`
}

type PrivateCi2027001ClusterInsert struct {
	ClusterName      int32            `json:"cluster_name"`
	ClusterSituation sql.NullString   `json:"cluster_situation"`
	ClusterStatus    sql.NullString   `json:"cluster_status"`
	CreatedAt        sql.NullString   `json:"created_at"`
	GridDensity      string           `json:"grid_density"`
	Id               sql.NullString   `json:"id"`
	Intkey           sql.NullString   `json:"intkey"`
	ModifiedAt       sql.NullString   `json:"modified_at"`
	ModifiedBy       sql.NullString   `json:"modified_by"`
	SelectAccessBy   []sql.NullString `json:"select_access_by"`
	StateResponsible string           `json:"state_responsible"`
	StatesAffected   []interface{}    `json:"states_affected"`
	TopoMapSheet     sql.NullInt32    `json:"topo_map_sheet"`
	UpdateAccessBy   []sql.NullString `json:"update_access_by"`
}

type PrivateCi2027001ClusterUpdate struct {
	ClusterName      sql.NullInt32    `json:"cluster_name"`
	ClusterSituation sql.NullString   `json:"cluster_situation"`
	ClusterStatus    sql.NullString   `json:"cluster_status"`
	CreatedAt        sql.NullString   `json:"created_at"`
	GridDensity      sql.NullString   `json:"grid_density"`
	Id               sql.NullString   `json:"id"`
	Intkey           sql.NullString   `json:"intkey"`
	ModifiedAt       sql.NullString   `json:"modified_at"`
	ModifiedBy       sql.NullString   `json:"modified_by"`
	SelectAccessBy   []sql.NullString `json:"select_access_by"`
	StateResponsible sql.NullString   `json:"state_responsible"`
	StatesAffected   []interface{}    `json:"states_affected"`
	TopoMapSheet     sql.NullInt32    `json:"topo_map_sheet"`
	UpdateAccessBy   []sql.NullString `json:"update_access_by"`
}

type PrivateCi2027001PlotSelect struct {
	Accessibility                     sql.NullInt32   `json:"accessibility"`
	Biotope                           sql.NullInt32   `json:"biotope"`
	CenterLocation                    interface{}     `json:"center_location"`
	ClusterId                         int32           `json:"cluster_id"`
	Coast                             sql.NullBool    `json:"coast"`
	CreatedAt                         string          `json:"created_at"`
	ElevationLevel                    sql.NullString  `json:"elevation_level"`
	FederalState                      string          `json:"federal_state"`
	FenceReg                          sql.NullBool    `json:"fence_reg"`
	FfhForestType                     sql.NullString  `json:"ffh_forest_type"`
	FfhForestTypeField                sql.NullString  `json:"ffh_forest_type_field"`
	ForestCommunity                   sql.NullString  `json:"forest_community"`
	ForestCommunityField              sql.NullString  `json:"forest_community_field"`
	ForestOffice                      sql.NullInt32   `json:"forest_office"`
	ForestStatus                      sql.NullString  `json:"forest_status"`
	GrowthDistrict                    sql.NullInt32   `json:"growth_district"`
	HarvestRestriction                sql.NullInt32   `json:"harvest_restriction"`
	HarvestRestrictionSource          []sql.NullInt32 `json:"harvest_restriction_source"`
	HarvestingMethod                  sql.NullString  `json:"harvesting_method"`
	Histwald                          sql.NullBool    `json:"histwald"`
	Id                                string          `json:"id"`
	IntervalName                      string          `json:"interval_name"`
	Intkey                            sql.NullString  `json:"intkey"`
	LandUseAfter                      sql.NullString  `json:"land_use_after"`
	LandUseBefore                     sql.NullString  `json:"land_use_before"`
	LandmarkAzimuth                   sql.NullInt32   `json:"landmark_azimuth"`
	LandmarkDistance                  sql.NullInt32   `json:"landmark_distance"`
	LandmarkNote                      sql.NullString  `json:"landmark_note"`
	ManagementType                    sql.NullString  `json:"management_type"`
	MarkerAzimuth                     sql.NullInt32   `json:"marker_azimuth"`
	MarkerDistance                    sql.NullInt32   `json:"marker_distance"`
	MarkerProfile                     sql.NullString  `json:"marker_profile"`
	MarkerStatus                      sql.NullString  `json:"marker_status"`
	ModifiedAt                        sql.NullString  `json:"modified_at"`
	ModifiedBy                        string          `json:"modified_by"`
	PlotName                          int16           `json:"plot_name"`
	PropertySizeClass                 sql.NullString  `json:"property_size_class"`
	PropertyType                      sql.NullString  `json:"property_type"`
	ProtectedLandscape                sql.NullBool    `json:"protected_landscape"`
	SamplingStratum                   int32           `json:"sampling_stratum"`
	Sandy                             sql.NullBool    `json:"sandy"`
	StandAge                          sql.NullInt32   `json:"stand_age"`
	StandDevPhase                     sql.NullString  `json:"stand_dev_phase"`
	StandLayerReg                     sql.NullString  `json:"stand_layer_reg"`
	StandStructure                    sql.NullString  `json:"stand_structure"`
	TerrainExposure                   sql.NullInt32   `json:"terrain_exposure"`
	TerrainForm                       sql.NullString  `json:"terrain_form"`
	TerrainSlope                      sql.NullInt32   `json:"terrain_slope"`
	TreesGreater4meterBasalAreaFactor sql.NullString  `json:"trees_greater_4meter_basal_area_factor"`
	TreesGreater4meterMirrored        sql.NullString  `json:"trees_greater_4meter_mirrored"`
	TreesLess4meterCoverage           sql.NullInt32   `json:"trees_less_4meter_coverage"`
	TreesLess4meterLayer              sql.NullString  `json:"trees_less_4meter_layer"`
}

type PrivateCi2027001PlotInsert struct {
	Accessibility                     sql.NullInt32   `json:"accessibility"`
	Biotope                           sql.NullInt32   `json:"biotope"`
	CenterLocation                    interface{}     `json:"center_location"`
	ClusterId                         int32           `json:"cluster_id"`
	Coast                             sql.NullBool    `json:"coast"`
	CreatedAt                         sql.NullString  `json:"created_at"`
	ElevationLevel                    sql.NullString  `json:"elevation_level"`
	FederalState                      string          `json:"federal_state"`
	FenceReg                          sql.NullBool    `json:"fence_reg"`
	FfhForestType                     sql.NullString  `json:"ffh_forest_type"`
	FfhForestTypeField                sql.NullString  `json:"ffh_forest_type_field"`
	ForestCommunity                   sql.NullString  `json:"forest_community"`
	ForestCommunityField              sql.NullString  `json:"forest_community_field"`
	ForestOffice                      sql.NullInt32   `json:"forest_office"`
	ForestStatus                      sql.NullString  `json:"forest_status"`
	GrowthDistrict                    sql.NullInt32   `json:"growth_district"`
	HarvestRestriction                sql.NullInt32   `json:"harvest_restriction"`
	HarvestRestrictionSource          []sql.NullInt32 `json:"harvest_restriction_source"`
	HarvestingMethod                  sql.NullString  `json:"harvesting_method"`
	Histwald                          sql.NullBool    `json:"histwald"`
	Id                                sql.NullString  `json:"id"`
	IntervalName                      sql.NullString  `json:"interval_name"`
	Intkey                            sql.NullString  `json:"intkey"`
	LandUseAfter                      sql.NullString  `json:"land_use_after"`
	LandUseBefore                     sql.NullString  `json:"land_use_before"`
	LandmarkAzimuth                   sql.NullInt32   `json:"landmark_azimuth"`
	LandmarkDistance                  sql.NullInt32   `json:"landmark_distance"`
	LandmarkNote                      sql.NullString  `json:"landmark_note"`
	ManagementType                    sql.NullString  `json:"management_type"`
	MarkerAzimuth                     sql.NullInt32   `json:"marker_azimuth"`
	MarkerDistance                    sql.NullInt32   `json:"marker_distance"`
	MarkerProfile                     sql.NullString  `json:"marker_profile"`
	MarkerStatus                      sql.NullString  `json:"marker_status"`
	ModifiedAt                        sql.NullString  `json:"modified_at"`
	ModifiedBy                        sql.NullString  `json:"modified_by"`
	PlotName                          int16           `json:"plot_name"`
	PropertySizeClass                 sql.NullString  `json:"property_size_class"`
	PropertyType                      sql.NullString  `json:"property_type"`
	ProtectedLandscape                sql.NullBool    `json:"protected_landscape"`
	SamplingStratum                   int32           `json:"sampling_stratum"`
	Sandy                             sql.NullBool    `json:"sandy"`
	StandAge                          sql.NullInt32   `json:"stand_age"`
	StandDevPhase                     sql.NullString  `json:"stand_dev_phase"`
	StandLayerReg                     sql.NullString  `json:"stand_layer_reg"`
	StandStructure                    sql.NullString  `json:"stand_structure"`
	TerrainExposure                   sql.NullInt32   `json:"terrain_exposure"`
	TerrainForm                       sql.NullString  `json:"terrain_form"`
	TerrainSlope                      sql.NullInt32   `json:"terrain_slope"`
	TreesGreater4meterBasalAreaFactor sql.NullString  `json:"trees_greater_4meter_basal_area_factor"`
	TreesGreater4meterMirrored        sql.NullString  `json:"trees_greater_4meter_mirrored"`
	TreesLess4meterCoverage           sql.NullInt32   `json:"trees_less_4meter_coverage"`
	TreesLess4meterLayer              sql.NullString  `json:"trees_less_4meter_layer"`
}

type PrivateCi2027001PlotUpdate struct {
	Accessibility                     sql.NullInt32   `json:"accessibility"`
	Biotope                           sql.NullInt32   `json:"biotope"`
	CenterLocation                    interface{}     `json:"center_location"`
	ClusterId                         sql.NullInt32   `json:"cluster_id"`
	Coast                             sql.NullBool    `json:"coast"`
	CreatedAt                         sql.NullString  `json:"created_at"`
	ElevationLevel                    sql.NullString  `json:"elevation_level"`
	FederalState                      sql.NullString  `json:"federal_state"`
	FenceReg                          sql.NullBool    `json:"fence_reg"`
	FfhForestType                     sql.NullString  `json:"ffh_forest_type"`
	FfhForestTypeField                sql.NullString  `json:"ffh_forest_type_field"`
	ForestCommunity                   sql.NullString  `json:"forest_community"`
	ForestCommunityField              sql.NullString  `json:"forest_community_field"`
	ForestOffice                      sql.NullInt32   `json:"forest_office"`
	ForestStatus                      sql.NullString  `json:"forest_status"`
	GrowthDistrict                    sql.NullInt32   `json:"growth_district"`
	HarvestRestriction                sql.NullInt32   `json:"harvest_restriction"`
	HarvestRestrictionSource          []sql.NullInt32 `json:"harvest_restriction_source"`
	HarvestingMethod                  sql.NullString  `json:"harvesting_method"`
	Histwald                          sql.NullBool    `json:"histwald"`
	Id                                sql.NullString  `json:"id"`
	IntervalName                      sql.NullString  `json:"interval_name"`
	Intkey                            sql.NullString  `json:"intkey"`
	LandUseAfter                      sql.NullString  `json:"land_use_after"`
	LandUseBefore                     sql.NullString  `json:"land_use_before"`
	LandmarkAzimuth                   sql.NullInt32   `json:"landmark_azimuth"`
	LandmarkDistance                  sql.NullInt32   `json:"landmark_distance"`
	LandmarkNote                      sql.NullString  `json:"landmark_note"`
	ManagementType                    sql.NullString  `json:"management_type"`
	MarkerAzimuth                     sql.NullInt32   `json:"marker_azimuth"`
	MarkerDistance                    sql.NullInt32   `json:"marker_distance"`
	MarkerProfile                     sql.NullString  `json:"marker_profile"`
	MarkerStatus                      sql.NullString  `json:"marker_status"`
	ModifiedAt                        sql.NullString  `json:"modified_at"`
	ModifiedBy                        sql.NullString  `json:"modified_by"`
	PlotName                          sql.NullInt32   `json:"plot_name"`
	PropertySizeClass                 sql.NullString  `json:"property_size_class"`
	PropertyType                      sql.NullString  `json:"property_type"`
	ProtectedLandscape                sql.NullBool    `json:"protected_landscape"`
	SamplingStratum                   sql.NullInt32   `json:"sampling_stratum"`
	Sandy                             sql.NullBool    `json:"sandy"`
	StandAge                          sql.NullInt32   `json:"stand_age"`
	StandDevPhase                     sql.NullString  `json:"stand_dev_phase"`
	StandLayerReg                     sql.NullString  `json:"stand_layer_reg"`
	StandStructure                    sql.NullString  `json:"stand_structure"`
	TerrainExposure                   sql.NullInt32   `json:"terrain_exposure"`
	TerrainForm                       sql.NullString  `json:"terrain_form"`
	TerrainSlope                      sql.NullInt32   `json:"terrain_slope"`
	TreesGreater4meterBasalAreaFactor sql.NullString  `json:"trees_greater_4meter_basal_area_factor"`
	TreesGreater4meterMirrored        sql.NullString  `json:"trees_greater_4meter_mirrored"`
	TreesLess4meterCoverage           sql.NullInt32   `json:"trees_less_4meter_coverage"`
	TreesLess4meterLayer              sql.NullString  `json:"trees_less_4meter_layer"`
}

type PrivateCi2027001PlotLocationSelect struct {
	Azimuth     int16          `json:"azimuth"`
	CreatedAt   string         `json:"created_at"`
	Distance    int16          `json:"distance"`
	Geometry    interface{}    `json:"geometry"`
	Id          string         `json:"id"`
	ModifiedAt  sql.NullString `json:"modified_at"`
	ModifiedBy  string         `json:"modified_by"`
	NoEntities  sql.NullBool   `json:"no_entities"`
	ParentTable string         `json:"parent_table"`
	PlotId      string         `json:"plot_id"`
	Radius      int16          `json:"radius"`
}

type PrivateCi2027001PlotLocationInsert struct {
	Azimuth     int16          `json:"azimuth"`
	CreatedAt   sql.NullString `json:"created_at"`
	Distance    sql.NullInt32  `json:"distance"`
	Geometry    interface{}    `json:"geometry"`
	Id          sql.NullString `json:"id"`
	ModifiedAt  sql.NullString `json:"modified_at"`
	ModifiedBy  sql.NullString `json:"modified_by"`
	NoEntities  sql.NullBool   `json:"no_entities"`
	ParentTable string         `json:"parent_table"`
	PlotId      string         `json:"plot_id"`
	Radius      sql.NullInt32  `json:"radius"`
}

type PrivateCi2027001PlotLocationUpdate struct {
	Azimuth     sql.NullInt32  `json:"azimuth"`
	CreatedAt   sql.NullString `json:"created_at"`
	Distance    sql.NullInt32  `json:"distance"`
	Geometry    interface{}    `json:"geometry"`
	Id          sql.NullString `json:"id"`
	ModifiedAt  sql.NullString `json:"modified_at"`
	ModifiedBy  sql.NullString `json:"modified_by"`
	NoEntities  sql.NullBool   `json:"no_entities"`
	ParentTable sql.NullString `json:"parent_table"`
	PlotId      sql.NullString `json:"plot_id"`
	Radius      sql.NullInt32  `json:"radius"`
}

type PrivateCi2027001TreeSelect struct {
	Azimuth            int16          `json:"azimuth"`
	BarkCondition      sql.NullInt32  `json:"bark_condition"`
	BarkPocket         sql.NullBool   `json:"bark_pocket"`
	BiotopeMarked      sql.NullBool   `json:"biotope_marked"`
	CaveTree           sql.NullBool   `json:"cave_tree"`
	CreatedAt          string         `json:"created_at"`
	CrownDeadWood      sql.NullBool   `json:"crown_dead_wood"`
	DamageBeetle       sql.NullBool   `json:"damage_beetle"`
	DamageDead         sql.NullBool   `json:"damage_dead"`
	DamageFungus       sql.NullBool   `json:"damage_fungus"`
	DamageLogging      sql.NullBool   `json:"damage_logging"`
	DamageOther        sql.NullBool   `json:"damage_other"`
	DamagePeelNew      sql.NullBool   `json:"damage_peel_new"`
	DamagePeelOld      sql.NullBool   `json:"damage_peel_old"`
	DamageResin        sql.NullBool   `json:"damage_resin"`
	Dbh                sql.NullInt32  `json:"dbh"`
	DbhHeight          sql.NullInt32  `json:"dbh_height"`
	Distance           int16          `json:"distance"`
	Geometry           interface{}    `json:"geometry"`
	Id                 string         `json:"id"`
	Intkey             sql.NullString `json:"intkey"`
	ModifiedAt         sql.NullString `json:"modified_at"`
	ModifiedBy         string         `json:"modified_by"`
	PlotId             string         `json:"plot_id"`
	Pruning            sql.NullString `json:"pruning"`
	PruningHeight      sql.NullInt32  `json:"pruning_height"`
	StandLayer         sql.NullString `json:"stand_layer"`
	StemBreakage       sql.NullString `json:"stem_breakage"`
	StemForm           sql.NullString `json:"stem_form"`
	StemHeight         sql.NullInt32  `json:"stem_height"`
	TreeAge            sql.NullInt32  `json:"tree_age"`
	TreeHeight         sql.NullInt32  `json:"tree_height"`
	TreeHeightAzimuth  sql.NullInt32  `json:"tree_height_azimuth"`
	TreeHeightDistance sql.NullInt32  `json:"tree_height_distance"`
	TreeMarked         bool           `json:"tree_marked"`
	TreeNumber         int16          `json:"tree_number"`
	TreeSpecies        sql.NullInt32  `json:"tree_species"`
	TreeStatus         sql.NullString `json:"tree_status"`
	TreeTopDrought     sql.NullBool   `json:"tree_top_drought"`
	WithinStand        sql.NullBool   `json:"within_stand"`
}

type PrivateCi2027001TreeInsert struct {
	Azimuth            int16          `json:"azimuth"`
	BarkCondition      sql.NullInt32  `json:"bark_condition"`
	BarkPocket         sql.NullBool   `json:"bark_pocket"`
	BiotopeMarked      sql.NullBool   `json:"biotope_marked"`
	CaveTree           sql.NullBool   `json:"cave_tree"`
	CreatedAt          sql.NullString `json:"created_at"`
	CrownDeadWood      sql.NullBool   `json:"crown_dead_wood"`
	DamageBeetle       sql.NullBool   `json:"damage_beetle"`
	DamageDead         sql.NullBool   `json:"damage_dead"`
	DamageFungus       sql.NullBool   `json:"damage_fungus"`
	DamageLogging      sql.NullBool   `json:"damage_logging"`
	DamageOther        sql.NullBool   `json:"damage_other"`
	DamagePeelNew      sql.NullBool   `json:"damage_peel_new"`
	DamagePeelOld      sql.NullBool   `json:"damage_peel_old"`
	DamageResin        sql.NullBool   `json:"damage_resin"`
	Dbh                sql.NullInt32  `json:"dbh"`
	DbhHeight          sql.NullInt32  `json:"dbh_height"`
	Distance           int16          `json:"distance"`
	Geometry           interface{}    `json:"geometry"`
	Id                 sql.NullString `json:"id"`
	Intkey             sql.NullString `json:"intkey"`
	ModifiedAt         sql.NullString `json:"modified_at"`
	ModifiedBy         sql.NullString `json:"modified_by"`
	PlotId             string         `json:"plot_id"`
	Pruning            sql.NullString `json:"pruning"`
	PruningHeight      sql.NullInt32  `json:"pruning_height"`
	StandLayer         sql.NullString `json:"stand_layer"`
	StemBreakage       sql.NullString `json:"stem_breakage"`
	StemForm           sql.NullString `json:"stem_form"`
	StemHeight         sql.NullInt32  `json:"stem_height"`
	TreeAge            sql.NullInt32  `json:"tree_age"`
	TreeHeight         sql.NullInt32  `json:"tree_height"`
	TreeHeightAzimuth  sql.NullInt32  `json:"tree_height_azimuth"`
	TreeHeightDistance sql.NullInt32  `json:"tree_height_distance"`
	TreeMarked         sql.NullBool   `json:"tree_marked"`
	TreeNumber         int16          `json:"tree_number"`
	TreeSpecies        sql.NullInt32  `json:"tree_species"`
	TreeStatus         sql.NullString `json:"tree_status"`
	TreeTopDrought     sql.NullBool   `json:"tree_top_drought"`
	WithinStand        sql.NullBool   `json:"within_stand"`
}

type PrivateCi2027001TreeUpdate struct {
	Azimuth            sql.NullInt32  `json:"azimuth"`
	BarkCondition      sql.NullInt32  `json:"bark_condition"`
	BarkPocket         sql.NullBool   `json:"bark_pocket"`
	BiotopeMarked      sql.NullBool   `json:"biotope_marked"`
	CaveTree           sql.NullBool   `json:"cave_tree"`
	CreatedAt          sql.NullString `json:"created_at"`
	CrownDeadWood      sql.NullBool   `json:"crown_dead_wood"`
	DamageBeetle       sql.NullBool   `json:"damage_beetle"`
	DamageDead         sql.NullBool   `json:"damage_dead"`
	DamageFungus       sql.NullBool   `json:"damage_fungus"`
	DamageLogging      sql.NullBool   `json:"damage_logging"`
	DamageOther        sql.NullBool   `json:"damage_other"`
	DamagePeelNew      sql.NullBool   `json:"damage_peel_new"`
	DamagePeelOld      sql.NullBool   `json:"damage_peel_old"`
	DamageResin        sql.NullBool   `json:"damage_resin"`
	Dbh                sql.NullInt32  `json:"dbh"`
	DbhHeight          sql.NullInt32  `json:"dbh_height"`
	Distance           sql.NullInt32  `json:"distance"`
	Geometry           interface{}    `json:"geometry"`
	Id                 sql.NullString `json:"id"`
	Intkey             sql.NullString `json:"intkey"`
	ModifiedAt         sql.NullString `json:"modified_at"`
	ModifiedBy         sql.NullString `json:"modified_by"`
	PlotId             sql.NullString `json:"plot_id"`
	Pruning            sql.NullString `json:"pruning"`
	PruningHeight      sql.NullInt32  `json:"pruning_height"`
	StandLayer         sql.NullString `json:"stand_layer"`
	StemBreakage       sql.NullString `json:"stem_breakage"`
	StemForm           sql.NullString `json:"stem_form"`
	StemHeight         sql.NullInt32  `json:"stem_height"`
	TreeAge            sql.NullInt32  `json:"tree_age"`
	TreeHeight         sql.NullInt32  `json:"tree_height"`
	TreeHeightAzimuth  sql.NullInt32  `json:"tree_height_azimuth"`
	TreeHeightDistance sql.NullInt32  `json:"tree_height_distance"`
	TreeMarked         sql.NullBool   `json:"tree_marked"`
	TreeNumber         sql.NullInt32  `json:"tree_number"`
	TreeSpecies        sql.NullInt32  `json:"tree_species"`
	TreeStatus         sql.NullString `json:"tree_status"`
	TreeTopDrought     sql.NullBool   `json:"tree_top_drought"`
	WithinStand        sql.NullBool   `json:"within_stand"`
}

type PrivateCi2027001PositionSelect struct {
	CreatedAt           string          `json:"created_at"`
	DeviceGnss          sql.NullString  `json:"device_gnss"`
	HdopMean            float64         `json:"hdop_mean"`
	Id                  string          `json:"id"`
	Intkey              sql.NullString  `json:"intkey"`
	MeasurementCount    int16           `json:"measurement_count"`
	ModifiedAt          sql.NullString  `json:"modified_at"`
	ModifiedBy          string          `json:"modified_by"`
	PdopMean            float64         `json:"pdop_mean"`
	PlotId              string          `json:"plot_id"`
	PositionMean        interface{}     `json:"position_mean"`
	PositionMedian      interface{}     `json:"position_median"`
	Quality             sql.NullString  `json:"quality"`
	RtcmAge             sql.NullFloat64 `json:"rtcm_age"`
	SatellitesCountMean float64         `json:"satellites_count_mean"`
	StartMeasurement    string          `json:"start_measurement"`
	StopMeasurement     string          `json:"stop_measurement"`
}

type PrivateCi2027001PositionInsert struct {
	CreatedAt           sql.NullString  `json:"created_at"`
	DeviceGnss          sql.NullString  `json:"device_gnss"`
	HdopMean            float64         `json:"hdop_mean"`
	Id                  sql.NullString  `json:"id"`
	Intkey              sql.NullString  `json:"intkey"`
	MeasurementCount    int16           `json:"measurement_count"`
	ModifiedAt          sql.NullString  `json:"modified_at"`
	ModifiedBy          sql.NullString  `json:"modified_by"`
	PdopMean            float64         `json:"pdop_mean"`
	PlotId              string          `json:"plot_id"`
	PositionMean        interface{}     `json:"position_mean"`
	PositionMedian      interface{}     `json:"position_median"`
	Quality             sql.NullString  `json:"quality"`
	RtcmAge             sql.NullFloat64 `json:"rtcm_age"`
	SatellitesCountMean float64         `json:"satellites_count_mean"`
	StartMeasurement    string          `json:"start_measurement"`
	StopMeasurement     string          `json:"stop_measurement"`
}

type PrivateCi2027001PositionUpdate struct {
	CreatedAt           sql.NullString  `json:"created_at"`
	DeviceGnss          sql.NullString  `json:"device_gnss"`
	HdopMean            sql.NullFloat64 `json:"hdop_mean"`
	Id                  sql.NullString  `json:"id"`
	Intkey              sql.NullString  `json:"intkey"`
	MeasurementCount    sql.NullInt32   `json:"measurement_count"`
	ModifiedAt          sql.NullString  `json:"modified_at"`
	ModifiedBy          sql.NullString  `json:"modified_by"`
	PdopMean            sql.NullFloat64 `json:"pdop_mean"`
	PlotId              sql.NullString  `json:"plot_id"`
	PositionMean        interface{}     `json:"position_mean"`
	PositionMedian      interface{}     `json:"position_median"`
	Quality             sql.NullString  `json:"quality"`
	RtcmAge             sql.NullFloat64 `json:"rtcm_age"`
	SatellitesCountMean sql.NullFloat64 `json:"satellites_count_mean"`
	StartMeasurement    sql.NullString  `json:"start_measurement"`
	StopMeasurement     sql.NullString  `json:"stop_measurement"`
}

type PrivateCi2027001EdgesSelect struct {
	CreatedAt     string         `json:"created_at"`
	EdgeNumber    sql.NullInt32  `json:"edge_number"`
	EdgeStatus    sql.NullString `json:"edge_status"`
	EdgeType      sql.NullString `json:"edge_type"`
	Edges         interface{}    `json:"edges"`
	GeometryEdges interface{}    `json:"geometry_edges"`
	Id            string         `json:"id"`
	Intkey        sql.NullString `json:"intkey"`
	ModifiedAt    sql.NullString `json:"modified_at"`
	ModifiedBy    string         `json:"modified_by"`
	PlotId        string         `json:"plot_id"`
	Terrain       sql.NullString `json:"terrain"`
}

type PrivateCi2027001EdgesInsert struct {
	CreatedAt     sql.NullString `json:"created_at"`
	EdgeNumber    sql.NullInt32  `json:"edge_number"`
	EdgeStatus    sql.NullString `json:"edge_status"`
	EdgeType      sql.NullString `json:"edge_type"`
	Edges         interface{}    `json:"edges"`
	GeometryEdges interface{}    `json:"geometry_edges"`
	Id            sql.NullString `json:"id"`
	Intkey        sql.NullString `json:"intkey"`
	ModifiedAt    sql.NullString `json:"modified_at"`
	ModifiedBy    sql.NullString `json:"modified_by"`
	PlotId        string         `json:"plot_id"`
	Terrain       sql.NullString `json:"terrain"`
}

type PrivateCi2027001EdgesUpdate struct {
	CreatedAt     sql.NullString `json:"created_at"`
	EdgeNumber    sql.NullInt32  `json:"edge_number"`
	EdgeStatus    sql.NullString `json:"edge_status"`
	EdgeType      sql.NullString `json:"edge_type"`
	Edges         interface{}    `json:"edges"`
	GeometryEdges interface{}    `json:"geometry_edges"`
	Id            sql.NullString `json:"id"`
	Intkey        sql.NullString `json:"intkey"`
	ModifiedAt    sql.NullString `json:"modified_at"`
	ModifiedBy    sql.NullString `json:"modified_by"`
	PlotId        sql.NullString `json:"plot_id"`
	Terrain       sql.NullString `json:"terrain"`
}

type PrivateCi2027001RegenerationSelect struct {
	Browsing             sql.NullString `json:"browsing"`
	CreatedAt            string         `json:"created_at"`
	DamagePeel           sql.NullInt32  `json:"damage_peel"`
	Id                   string         `json:"id"`
	Intkey               sql.NullString `json:"intkey"`
	ModifiedAt           sql.NullString `json:"modified_at"`
	ModifiedBy           string         `json:"modified_by"`
	PlotId               string         `json:"plot_id"`
	ProtectionIndividual sql.NullBool   `json:"protection_individual"`
	TreeCount            int16          `json:"tree_count"`
	TreeSizeClass        sql.NullString `json:"tree_size_class"`
	TreeSpecies          sql.NullInt32  `json:"tree_species"`
}

type PrivateCi2027001RegenerationInsert struct {
	Browsing             sql.NullString `json:"browsing"`
	CreatedAt            sql.NullString `json:"created_at"`
	DamagePeel           sql.NullInt32  `json:"damage_peel"`
	Id                   sql.NullString `json:"id"`
	Intkey               sql.NullString `json:"intkey"`
	ModifiedAt           sql.NullString `json:"modified_at"`
	ModifiedBy           sql.NullString `json:"modified_by"`
	PlotId               string         `json:"plot_id"`
	ProtectionIndividual sql.NullBool   `json:"protection_individual"`
	TreeCount            int16          `json:"tree_count"`
	TreeSizeClass        sql.NullString `json:"tree_size_class"`
	TreeSpecies          sql.NullInt32  `json:"tree_species"`
}

type PrivateCi2027001RegenerationUpdate struct {
	Browsing             sql.NullString `json:"browsing"`
	CreatedAt            sql.NullString `json:"created_at"`
	DamagePeel           sql.NullInt32  `json:"damage_peel"`
	Id                   sql.NullString `json:"id"`
	Intkey               sql.NullString `json:"intkey"`
	ModifiedAt           sql.NullString `json:"modified_at"`
	ModifiedBy           sql.NullString `json:"modified_by"`
	PlotId               sql.NullString `json:"plot_id"`
	ProtectionIndividual sql.NullBool   `json:"protection_individual"`
	TreeCount            sql.NullInt32  `json:"tree_count"`
	TreeSizeClass        sql.NullString `json:"tree_size_class"`
	TreeSpecies          sql.NullInt32  `json:"tree_species"`
}

type PrivateCi2027001StructureLt4mSelect struct {
	Coverage         int32          `json:"coverage"`
	CreatedAt        string         `json:"created_at"`
	Id               string         `json:"id"`
	Intkey           sql.NullString `json:"intkey"`
	ModifiedAt       sql.NullString `json:"modified_at"`
	ModifiedBy       string         `json:"modified_by"`
	PlotId           string         `json:"plot_id"`
	RegenerationType sql.NullInt32  `json:"regeneration_type"`
	TreeSpecies      sql.NullInt32  `json:"tree_species"`
}

type PrivateCi2027001StructureLt4mInsert struct {
	Coverage         int32          `json:"coverage"`
	CreatedAt        sql.NullString `json:"created_at"`
	Id               sql.NullString `json:"id"`
	Intkey           sql.NullString `json:"intkey"`
	ModifiedAt       sql.NullString `json:"modified_at"`
	ModifiedBy       sql.NullString `json:"modified_by"`
	PlotId           string         `json:"plot_id"`
	RegenerationType sql.NullInt32  `json:"regeneration_type"`
	TreeSpecies      sql.NullInt32  `json:"tree_species"`
}

type PrivateCi2027001StructureLt4mUpdate struct {
	Coverage         sql.NullInt32  `json:"coverage"`
	CreatedAt        sql.NullString `json:"created_at"`
	Id               sql.NullString `json:"id"`
	Intkey           sql.NullString `json:"intkey"`
	ModifiedAt       sql.NullString `json:"modified_at"`
	ModifiedBy       sql.NullString `json:"modified_by"`
	PlotId           sql.NullString `json:"plot_id"`
	RegenerationType sql.NullInt32  `json:"regeneration_type"`
	TreeSpecies      sql.NullInt32  `json:"tree_species"`
}

type PrivateCi2027001DeadwoodSelect struct {
	BarkPocket       sql.NullInt32  `json:"bark_pocket"`
	Count            sql.NullInt32  `json:"count"`
	CreatedAt        string         `json:"created_at"`
	DeadWoodType     sql.NullString `json:"dead_wood_type"`
	Decomposition    sql.NullString `json:"decomposition"`
	DiameterButt     int32          `json:"diameter_butt"`
	DiameterTop      sql.NullInt32  `json:"diameter_top"`
	Id               string         `json:"id"`
	Intkey           sql.NullString `json:"intkey"`
	LengthHeight     sql.NullInt32  `json:"length_height"`
	ModifiedAt       sql.NullString `json:"modified_at"`
	ModifiedBy       string         `json:"modified_by"`
	PlotId           string         `json:"plot_id"`
	TreeSpeciesGroup sql.NullString `json:"tree_species_group"`
}

type PrivateCi2027001DeadwoodInsert struct {
	BarkPocket       sql.NullInt32  `json:"bark_pocket"`
	Count            sql.NullInt32  `json:"count"`
	CreatedAt        sql.NullString `json:"created_at"`
	DeadWoodType     sql.NullString `json:"dead_wood_type"`
	Decomposition    sql.NullString `json:"decomposition"`
	DiameterButt     int32          `json:"diameter_butt"`
	DiameterTop      sql.NullInt32  `json:"diameter_top"`
	Id               sql.NullString `json:"id"`
	Intkey           sql.NullString `json:"intkey"`
	LengthHeight     sql.NullInt32  `json:"length_height"`
	ModifiedAt       sql.NullString `json:"modified_at"`
	ModifiedBy       sql.NullString `json:"modified_by"`
	PlotId           string         `json:"plot_id"`
	TreeSpeciesGroup sql.NullString `json:"tree_species_group"`
}

type PrivateCi2027001DeadwoodUpdate struct {
	BarkPocket       sql.NullInt32  `json:"bark_pocket"`
	Count            sql.NullInt32  `json:"count"`
	CreatedAt        sql.NullString `json:"created_at"`
	DeadWoodType     sql.NullString `json:"dead_wood_type"`
	Decomposition    sql.NullString `json:"decomposition"`
	DiameterButt     sql.NullInt32  `json:"diameter_butt"`
	DiameterTop      sql.NullInt32  `json:"diameter_top"`
	Id               sql.NullString `json:"id"`
	Intkey           sql.NullString `json:"intkey"`
	LengthHeight     sql.NullInt32  `json:"length_height"`
	ModifiedAt       sql.NullString `json:"modified_at"`
	ModifiedBy       sql.NullString `json:"modified_by"`
	PlotId           sql.NullString `json:"plot_id"`
	TreeSpeciesGroup sql.NullString `json:"tree_species_group"`
}
