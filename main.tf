resource "google_bigquery_dataset" "bqml_lab" {
  dataset_id = "bqml_lab"
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

  depends_on          = [google_bigquery_dataset.bqml_lab]
  deletion_protection = false
}

resource "google_bigquery_job" "create_model" {
  job_id = "create-sample-model"
  
  query {
    query              = <<EOT
    CREATE OR REPLACE MODEL `bqml_lab.sample_model`
    OPTIONS(model_type='logistic_reg') AS
    SELECT * FROM `bqml_lab.training_data`;
    EOT
    use_legacy_sql     = false
    create_disposition = ""
    write_disposition  = ""
  }

  depends_on = [google_bigquery_table.training_data_view]
}

resource "google_bigquery_job" "evaluate_model" {
  job_id = "evaluate-sample-model"

  query {
    query          = <<EOT
    #standardSQL
    SELECT
      *
    FROM
      ml.EVALUATE(MODEL `bqml_lab.sample_model`);
    EOT
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_job.create_model]
}

resource "google_bigquery_table" "july_data_view" {
  dataset_id = google_bigquery_dataset.bqml_lab.dataset_id
  table_id   = "july_data"

  view {
    query          = <<EOT
    #standardSQL
    SELECT
      IF(totals.transactions IS NULL, 0, 1) AS label,
      IFNULL(device.operatingSystem, "") AS os,
      device.isMobile AS is_mobile,
      IFNULL(geoNetwork.country, "") AS country,
      IFNULL(totals.pageviews, 0) AS pageviews,
      fullVisitorId
    FROM
      `bigquery-public-data.google_analytics_sample.ga_sessions_*`
    WHERE
      _TABLE_SUFFIX BETWEEN '20170701' AND '20170801';
    EOT

    use_legacy_sql = false
  }

  deletion_protection = false
}

resource "google_bigquery_job" "predict_purchases_by_country" {
  job_id = "predict-purchases-country"

  query {
    query = <<EOT
    #standardSQL
    SELECT
      country,
      SUM(predicted_label) as total_predicted_purchases
    FROM
      ml.PREDICT(MODEL `bqml_lab.sample_model`, (
    SELECT * FROM `bqml_lab.july_data`))
    GROUP BY country
    ORDER BY total_predicted_purchases DESC
    LIMIT 10;
    EOT

    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.july_data_view]
}

resource "google_bigquery_job" "predict_purchases_by_user" {
  job_id = "predict-purchases-user"

  query {
    query = <<EOT
    #standardSQL
    SELECT
      fullVisitorId,
      SUM(predicted_label) as total_predicted_purchases
    FROM
      ml.PREDICT(MODEL `bqml_lab.sample_model`, (
    SELECT * FROM `bqml_lab.july_data`))
    GROUP BY fullVisitorId
    ORDER BY total_predicted_purchases DESC
    LIMIT 10;
    EOT

    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.july_data_view]
}
