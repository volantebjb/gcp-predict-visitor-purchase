resource "google_bigquery_dataset" "bqml_lab" {
  dataset_id                  = "bqml_lab"
}

resource "google_bigquery_table" "training_data_view" {
  dataset_id = google_bigquery_dataset.bqml_lab.dataset_id
  table_id   = "training_data"
  view {
    query          = <<EOT
    SELECT
      IF(totals.transactions IS NULL, 0, 1) AS label,
      IFNULL(device.operatingSystem, "") AS os,
      device.isMobile AS is_mobile,
      IFNULL(geoNetwork.country, "") AS country,
      IFNULL(totals.pageviews, 0) AS pageviews
    FROM
      `bigquery-public-data.google_analytics_sample.ga_sessions_*`
    WHERE
      _TABLE_SUFFIX BETWEEN '20160801' AND '20170631'
    LIMIT 10000;
    EOT
    use_legacy_sql = false
  }
}