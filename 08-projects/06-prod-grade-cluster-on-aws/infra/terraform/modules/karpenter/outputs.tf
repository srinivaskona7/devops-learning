output "controller_role_arn" {
  description = "IAM role ARN for Karpenter controller (IRSA)"
  value       = aws_iam_role.karpenter_controller.arn
}

output "interruption_queue_url" {
  description = "SQS queue URL for spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.url
}

output "interruption_queue_arn" {
  description = "SQS queue ARN for spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.arn
}

output "node_instance_profile_name" {
  description = "Instance profile name for Karpenter-launched nodes"
  value       = aws_iam_instance_profile.karpenter_node.name
}
