output cluster_join_script {
  value = format("s3://%s/scripts/w-join-%s.sh", aws_s3_bucket.scripts.id, random_uuid.join.result)
}

output apiserver_address {
  value = aws_alb.control_plane.dns_name
}

output scripts_bucket_arn {
  value = aws_s3_bucket.scripts.arn
}

output control_plane_security_group {
  value = aws_security_group.kubemaster.id
}