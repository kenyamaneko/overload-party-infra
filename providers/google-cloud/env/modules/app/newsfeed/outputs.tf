output "job_name" {
  description = "記事取得を行う Cloud Run ジョブ名"
  value       = google_cloud_run_v2_job.newsfeed.name
}
