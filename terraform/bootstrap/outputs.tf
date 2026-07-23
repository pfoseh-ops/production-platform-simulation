output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "lock_table_name" {
  value = aws_dynamodb_table.locks.name
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}
